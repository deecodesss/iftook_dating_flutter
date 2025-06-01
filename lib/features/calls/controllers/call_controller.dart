import 'dart:convert';
import 'dart:developer';
import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:get/get.dart';
import 'package:iftook/core/services/api_service.dart';
import 'package:iftook/core/services/socket_service.dart';
import 'package:iftook/features/calls/controllers/call_status_controller.dart';
import 'package:iftook/features/calls/services/chat_call_service.dart';
import 'package:iftook/features/calls/presentation/screens/video_call_screen.dart';
import 'package:iftook/helpers/notification_helper.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

import '../presentation/screens/voice_call_screen.dart';
import 'package:iftook/core/services/shared_prefs.dart';

// Define call states for better state management
enum CallState {
  idle, // No active call
  initializing, // Setting up call
  outgoing, // Outgoing call, waiting for remote user
  incoming, // Incoming call
  connecting, // Connecting to call server
  connected, // Call connected
  disconnected, // Call ended normally
  rejected, // Call rejected by callee
  missed, // Call missed/timed out
  failed, // Call failed to connect
  busy // Remote user is busy
}

class CallController extends GetxController {
  final ApiService _apiService = ApiService();
  RxBool isTransferring = false.obs;
  RxDouble userWalletBalance = 0.0.obs;
  RxString token = ''.obs;
  RxString meetingId = ''.obs;
  RxString channel = ''.obs;
  RxBool isJoining = false.obs;
  RxString callStatus = ''.obs;
  late RtcEngine _engine;

  // Add these observable values
  final _remoteUid = 0.obs;
  final isCallConnected = false.obs;
  final hasRemoteUserJoined = false.obs;
  final isCallActive = false.obs;
  final wasCallRejected = false.obs;
  final wasCallBusy = false.obs; // Add flag for busy state
  final wasCallFailed = false.obs; // Add flag for failure
  final rejectedBy = ''.obs;

  // Call state management
  final Rx<CallState> currentCallState = Rx<CallState>(CallState.idle);
  final RxString callStatusMessage = RxString('');

  // For call rejection handling
  Timer? _callRejectionCheckTimer;
  final SocketService _socketService = SocketService();
  // Controller for call status tracking
  late final CallStatusController _callStatusController;

  // Get current call type
  RxString callType = ''.obs;

  // Track if call is incoming vs outgoing for UI differences
  RxBool isIncomingCall = false.obs;

  // Method to update call state and status message
  void updateCallState(CallState newState, {String? message}) {
    currentCallState.value = newState;

    // Set default message based on state if none provided
    if (message == null) {
      switch (newState) {
        case CallState.idle:
          callStatusMessage.value = '';
          break;
        case CallState.initializing:
          callStatusMessage.value = 'Initializing call...';
          break;
        case CallState.outgoing:
          callStatusMessage.value = 'Calling...';
          break;
        case CallState.incoming:
          callStatusMessage.value = 'Incoming call...';
          break;
        case CallState.connecting:
          callStatusMessage.value = 'Connecting...';
          break;
        case CallState.connected:
          callStatusMessage.value = 'Connected';
          break;
        case CallState.disconnected:
          callStatusMessage.value = 'Call ended';
          break;
        case CallState.rejected:
          callStatusMessage.value = 'Call rejected';
          wasCallRejected.value = true;
          break;
        case CallState.missed:
          callStatusMessage.value = 'Call missed';
          break;
        case CallState.failed:
          callStatusMessage.value = 'Call failed';
          wasCallFailed.value = true;
          break;
        case CallState.busy:
          callStatusMessage.value = 'User is busy';
          wasCallBusy.value = true;
          break;
      }
    } else {
      callStatusMessage.value = message;
    }

    // Update call status for UI components that use this
    callStatus.value = callStatusMessage.value;

    // Set rejection flags based on state
    if (newState == CallState.rejected) {
      wasCallRejected.value = true;
    }
    if (newState == CallState.busy) {
      wasCallBusy.value = true;
    }

    debugPrint(
        '📞 Call state changed to: $newState with message: ${callStatusMessage.value}');
  }

  Future<void> handleCameraAndMic(Permission permisison) async {
    final status = await permisison.request();
    log(status.toString());
  }

  // Method to listen for call rejection with both socket and API polling
  void startCallRejectionListener(String callMeetingId) {
    // Update meetingId and reset rejection state
    meetingId.value = callMeetingId;
    wasCallRejected.value = false;
    wasCallBusy.value = false;
    wasCallFailed.value = false;
    isCallActive.value = true;

    // Listen for call rejection via stream instead of direct socket event
    _socketService.callRejectionStream.listen((data) {
      print('📱 Call rejection event received from stream: $data');
      if (data != null && data['meetingId'] == meetingId.value) {
        final rejectorId = data['rejectedBy'] ?? '';
        final status = data['status'] ?? 'rejected';

        if (status == 'busy') {
          _handleCallBusy(rejectorId);
        } else {
          _handleCallRejection(rejectorId);
        }
      }
    });

    // Also poll the API every few seconds as a fallback
    _callRejectionCheckTimer = Timer.periodic(
      const Duration(seconds: 3),
      (timer) => _checkCallStatus(callMeetingId),
    );
  }

  // Method to check call status via API
  Future<void> _checkCallStatus(String callMeetingId) async {
    if (wasCallRejected.value ||
        wasCallBusy.value ||
        currentCallState.value == CallState.connected) {
      return;
    }

    try {
      final response = await ApiService.getCallStatus(callMeetingId);

      if (response.statusCode == 200) {
        final statusData = json.decode(response.body);
        final status = statusData['status'];

        if (status == 'rejected') {
          final rejectorId = statusData['rejectedBy'] ?? '';
          _handleCallRejection(rejectorId);
        } else if (status == 'busy') {
          final rejectorId = statusData['rejectedBy'] ?? '';
          _handleCallBusy(rejectorId);
        } else if (status == 'ended' &&
            currentCallState.value != CallState.connected &&
            !hasRemoteUserJoined.value) {
          // Call was ended before connecting - likely cancelled by caller
          updateCallState(CallState.disconnected, message: 'Call cancelled');
          stopCallRejectionListener();
        }
      }
    } catch (e) {
      print('Error checking call status: $e');
    }
  }

  // Unified method to handle call rejection
  void _handleCallRejection(String rejectorId) {
    if (wasCallRejected.value) return; // Prevent duplicate handling

    rejectedBy.value = rejectorId;
    updateCallState(CallState.rejected);
    _callRejectionCheckTimer?.cancel();
  }

  // New method to handle busy state
  void _handleCallBusy(String busyUserId) {
    if (wasCallBusy.value) return; // Prevent duplicate handling

    rejectedBy.value = busyUserId;
    updateCallState(CallState.busy);
    _callRejectionCheckTimer?.cancel();
  }

  // Clean up call rejection listeners
  void stopCallRejectionListener() {
    _callRejectionCheckTimer?.cancel();
    isCallActive.value = false;
  }

  Future<void> initiateCall(
      String participantId, String type, DateTime scheduleTime,
      {bool isInstaTalk = false, bool isTrial = false}) async {
    try {
      isJoining(true);
      updateCallState(CallState.initializing);

      // Set call type and mark as outgoing
      callType.value = type;
      isIncomingCall.value = false;

      final response = await ApiService.initiateCall(
          participantId, type, scheduleTime, isInstaTalk);

      print('Call Initiation Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseMap = jsonDecode(response.body)['data'];

        if (responseMap == null) {
          updateCallState(CallState.failed, message: 'Invalid response data');
          throw Exception('Invalid response data');
        }

        channel.value = responseMap['channelName'] ?? '';
        meetingId.value = responseMap['meeting']?['_id'] ?? '';
        token.value = responseMap['token'] ?? '';

        print('Call Details:'
            '\nChannel: ${channel.value}'
            '\nMeeting ID: ${meetingId.value}'
            '\nToken: ${token.value}'
            '\nisInstaTalk: $isInstaTalk'
            '\nisTrial: $isTrial');

        if (channel.value.isEmpty || token.value.isEmpty) {
          updateCallState(CallState.failed,
              message: 'Missing channel or token');
          throw Exception('Missing channel or token');
        }

        updateCallState(CallState.outgoing);

        // Start listening for call rejection
        startCallRejectionListener(meetingId.value);

        // Add delay to ensure other user has time to initialize
        await Future.delayed(const Duration(seconds: 2));

        if (type == 'voice') {
          Get.off(
            () => VoiceCallScreen(
              channel: channel.value,
              meetingId: meetingId.value,
              token: token.value,
              onSessionEnd: onSessionEnd,
              isInstaTalk: isInstaTalk,
              isTrial: isTrial,
            ),
            preventDuplicates: true,
          );
        } else {
          Get.off(
            () => VideoCallScreen(
              channel: channel.value,
              meetingId: meetingId.value,
              token: token.value,
              onSessionEnd: onSessionEnd,
              initialTimer: 30,
              isInstaTalk: isInstaTalk,
              isTrial: isTrial,
            ),
            preventDuplicates: true,
          );
        }
      } else {
        updateCallState(CallState.failed,
            message: 'Call initiation failed: ${response.statusCode}');
        throw Exception('Call initiation failed: ${response.statusCode}');
      }
    } catch (e) {
      isJoining(false);
      updateCallState(CallState.failed, message: 'Error: ${e.toString()}');
      rethrow;
    }
  }

  // Call this when user explicitly ends/cancels a call
  Future<void> rejectCall() async {
    try {
      if (meetingId.value.isNotEmpty) {
        final userId = await SharedPrefs.getUserIdSharedPreference();

        // Send rejection to backend
        await ApiService.rejectCall(meetingId.value, {
          'meetingId': meetingId.value,
          'status': 'rejected',
          'rejectedBy': userId,
          'timestamp': DateTime.now().toIso8601String(),
        });

        updateCallState(CallState.disconnected, message: 'Call ended');
      }
    } catch (e) {
      print('Error rejecting call: $e');
    } finally {
      stopCallRejectionListener();
    }
  }

  bool isFreeCall(double? callRate) {
    return callRate == null || callRate == 0;
  }

  // Call session timer variables
  Timer? _sessionTimer;
  var sessionTimeRemaining = 0.obs;
  Function? onSessionEnd;

  // Update timer start logic to check friendship
  Future<void> startCallTimerIfNeeded({
    required String userId1,
    required String userId2,
    required int durationInMinutes,
    required bool isTrial,
    required bool isInstaTalk,
    Function? onEnd,
  }) async {
    // Don't start timer for trial calls
    if (isTrial) {
      return;
    }

    // Check if users are friends
    final areFriends = await ApiService.checkIsFriend(userId2);
    if (areFriends) {
      print('Users are friends - no timer needed');
      return;
    }

    // Start timer for non-friends
    sessionTimeRemaining.value = durationInMinutes * 60;
    onSessionEnd = onEnd;
    _startSessionTimer();
  }

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (sessionTimeRemaining.value > 0) {
        sessionTimeRemaining.value--;
      } else {
        _sessionTimer?.cancel();
        if (onSessionEnd != null) {
          onSessionEnd!();
        }
      }
    });
  }

  void stopSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
  }

  // Purchase call session
  Future<bool> purchaseCallSession(
      String participantId, double baseAmount, String type,
      {int minutes = 1}) async {
    try {
      final perMinuteRate = baseAmount; // Live rate is already per minute
      final finalAmount = perMinuteRate * minutes;

      // Deduct money from wallet
      final deductResponse = await ApiService.deductMoneyToWallet(finalAmount);
      if (deductResponse.statusCode != 200) {
        return false;
      }

      // Start new timer for purchased minutes
      // startSessionTimer(minutes);

      return true;
    } catch (e) {
      print('Error purchasing call session: $e');
      return false;
    }
  }

  // Different initiate methods for InstaTalk and regular meetings
  Future<void> initiateInstaTalkCall(String participantId, String type,
      {bool isTrial = false}) async {
    updateCallState(CallState.initializing,
        message: 'Starting InstaTalk call...');
    await initiateCall(participantId, type, DateTime.now(),
        isInstaTalk: true, isTrial: isTrial);
  }

  Future<void> initiateMeetingCall(
      String participantId, String type, DateTime scheduleTime,
      {bool isInstatalk = false}) async {
    try {
      updateCallState(CallState.initializing,
          message: 'Starting scheduled call...');
      callType.value = type;
      isIncomingCall.value = false;

      print('Initiating meeting call for existing meeting');
      print('Participant: $participantId');
      print('Type: $type');
      print('Schedule Time: $scheduleTime');

      final response = await ApiService.initiateCall(
        participantId,
        type,
        scheduleTime,
        isInstatalk,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseMap = jsonDecode(response.body)['data'];

        // Log the received data
        print('Meeting response: ${response.body}');

        channel.value = responseMap['channelName'] ?? '';
        meetingId.value = responseMap['meeting']?['_id'] ?? '';
        token.value = responseMap['token'] ?? '';

        if (channel.value.isEmpty || token.value.isEmpty) {
          updateCallState(CallState.failed,
              message: 'Invalid meeting credentials received');
          throw Exception('Invalid meeting credentials received');
        }

        updateCallState(CallState.outgoing);

        print('Successfully initialized meeting:'
            '\nChannel: ${channel.value}'
            '\nMeeting ID: ${meetingId.value}'
            '\nToken: ${token.value}');
      } else {
        updateCallState(CallState.failed,
            message: 'Failed to initialize meeting: ${response.statusCode}');
        throw Exception('Failed to initialize meeting: ${response.statusCode}');
      }
    } catch (e) {
      print('Error initiating meeting call: $e');
      updateCallState(CallState.failed, message: 'Error: $e');
      throw e;
    }
  }

  // Prepare for incoming call
  void setupIncomingCall(String callId, String callChannel, String callToken) {
    meetingId.value = callId;
    channel.value = callChannel;
    token.value = callToken;
    isIncomingCall.value = true;
    updateCallState(CallState.incoming);
  }

  void initializeEventHandlers() {
    _engine?.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          print('Local user joined channel: ${connection.channelId}');
          isCallActive.value = true;
          isCallConnected.value = true;
          updateCallState(CallState.connecting,
              message: 'Waiting for other participant...');

          // Notify call status system that user has joined a call
          _notifyUserJoinedCall();
        },
        onUserJoined: (RtcConnection connection, int uid, int elapsed) {
          print('Remote user joined: $uid');
          _remoteUid.value = uid;
          hasRemoteUserJoined.value = true;
          updateCallState(CallState.connected);

          // If we're in loading screen, navigate to main call screen
          if (Get.currentRoute.contains('loading')) {
            Get.off(() => VideoCallScreen(
                  meetingId: meetingId.value,
                  channel: channel.value,
                  token: token.value,
                  initialTimer: 30,
                ));
          }
        },
        onUserOffline:
            (RtcConnection connection, int uid, UserOfflineReasonType reason) {
          print('Remote user left: $uid');
          _remoteUid.value = 0;
          hasRemoteUserJoined.value = false;
          updateCallState(CallState.disconnected,
              message: reason == UserOfflineReasonType.userOfflineQuit
                  ? 'User ended call'
                  : 'User disconnected');

          // Auto end call and go back when remote user leaves
          endCall();
          Get.back();
        },
        onConnectionStateChanged: (RtcConnection connection,
            ConnectionStateType state, ConnectionChangedReasonType reason) {
          print('Connection state changed: $state reason: $reason');

          if (state == ConnectionStateType.connectionStateConnecting) {
            updateCallState(CallState.connecting);
          } else if (state == ConnectionStateType.connectionStateConnected) {
            isCallConnected.value = true;
            if (hasRemoteUserJoined.value) {
              updateCallState(CallState.connected);
            } else {
              updateCallState(CallState.connecting,
                  message: 'Waiting for other participant...');
            }
          } else if (state == ConnectionStateType.connectionStateFailed) {
            updateCallState(CallState.failed,
                message: 'Connection failed: $reason');
          } else if (state == ConnectionStateType.connectionStateDisconnected) {
            updateCallState(CallState.disconnected);
          }
        },
      ),
    );
  }

  Future<void> joinChannel(String channelName, String token) async {
    if (_engine == null) throw Exception('Engine not initialized');

    try {
      await _engine!.joinChannel(
        token: token,
        channelId: channelName,
        uid: 0,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      // Notify call status system that user has joined a call
      _notifyUserJoinedCall();
    } catch (e) {
      print('Error joining channel: $e');
      throw Exception('Failed to join call: $e');
    }
  }

  // Notify that user has joined a call
  Future<void> _notifyUserJoinedCall() async {
    try {
      final userId = await SharedPrefs.getUserIdSharedPreference();
      if (userId != null && meetingId.value.isNotEmpty) {
        // Check if CallStatusController is initialized
        if (!Get.isRegistered<CallStatusController>()) {
          Get.put(CallStatusController());
        }

        // Get the controller and notify about joining call
        final controller = Get.find<CallStatusController>();
        controller.notifyUserJoinedCall(
            userId, callType.value, meetingId.value);

        print(
            '🔔 Notified system that user $userId joined ${callType.value} call ${meetingId.value}');
      }
    } catch (e) {
      print('❌ Error notifying user joined call: $e');
    }
  }

  // Notify that user has left a call
  Future<void> _notifyUserLeftCall() async {
    try {
      final userId = await SharedPrefs.getUserIdSharedPreference();
      if (userId != null && meetingId.value.isNotEmpty) {
        // Check if CallStatusController is initialized
        if (!Get.isRegistered<CallStatusController>()) {
          Get.put(CallStatusController());
        }

        // Get the controller and notify about leaving call
        final controller = Get.find<CallStatusController>();
        controller.notifyUserLeftCall(userId, meetingId.value);

        print(
            '🔔 Notified system that user $userId left call ${meetingId.value}');
      }
    } catch (e) {
      print('❌ Error notifying user left call: $e');
    }
  }

  void endCall() {
    try {
      _engine?.leaveChannel();
      _remoteUid.value = 0;
      isCallActive.value = false;
      hasRemoteUserJoined.value = false;
      isCallConnected.value = false;

      updateCallState(CallState.disconnected);

      // Notify call status system that user has left a call
      _notifyUserLeftCall();
    } catch (e) {
      print('Error ending call: $e');
    }
  }

  @override
  void onInit() {
    super.onInit();

    // Initialize call status controller
    if (!Get.isRegistered<CallStatusController>()) {
      Get.put(CallStatusController());
    }
    _callStatusController = Get.find<CallStatusController>();

    // Set initial call state
    updateCallState(CallState.idle);
  }

  @override
  void onClose() {
    stopSessionTimer();
    stopCallRejectionListener();

    // Reset all call state
    updateCallState(CallState.idle);
    wasCallRejected.value = false;
    wasCallBusy.value = false;
    wasCallFailed.value = false;

    super.onClose();
  }

  // Reset call state - used when returning to idle
  void resetCallState() {
    wasCallRejected.value = false;
    wasCallBusy.value = false;
    wasCallFailed.value = false;
    hasRemoteUserJoined.value = false;
    isCallConnected.value = false;
    isCallActive.value = false;
    isIncomingCall.value = false;
    updateCallState(CallState.idle);
    meetingId.value = '';
    channel.value = '';
    token.value = '';
    stopCallRejectionListener();
  }
}
