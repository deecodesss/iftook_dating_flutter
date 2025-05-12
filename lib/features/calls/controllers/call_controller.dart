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
  final rejectedBy = ''.obs;

  // For call rejection handling
  Timer? _callRejectionCheckTimer;
  final SocketService _socketService = SocketService();
  // Controller for call status tracking
  late final CallStatusController _callStatusController;

  // Get current call type
  RxString callType = ''.obs;

  Future<void> handleCameraAndMic(Permission permisison) async {
    final status = await permisison.request();
    log(status.toString());
  }

  // Method to listen for call rejection with both socket and API polling
  void startCallRejectionListener(String callMeetingId) {
    // Update meetingId and reset rejection state
    meetingId.value = callMeetingId;
    wasCallRejected.value = false;
    isCallActive.value = true;

    // Listen for call rejection via stream instead of direct socket event
    _socketService.callRejectionStream.listen((data) {
      print('📱 Call rejection event received from stream: $data');
      if (data != null && data['meetingId'] == meetingId.value) {
        final rejectorId = data['rejectedBy'] ?? '';
        _handleCallRejection(rejectorId);
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
    if (wasCallRejected.value) return;

    try {
      final statusData = await ChatCallService.getCallStatus(callMeetingId);
      if (statusData != null && statusData['status'] == 'rejected') {
        final rejectorId = statusData['rejectedBy'] ?? '';
        _handleCallRejection(rejectorId);
      }
    } catch (e) {
      print('Error checking call status: $e');
    }
  }

  // Unified method to handle call rejection
  void _handleCallRejection(String rejectorId) {
    wasCallRejected.value = true;
    rejectedBy.value = rejectorId;
    callStatus.value = "Call declined";
    isCallActive.value = false;
    _callRejectionCheckTimer?.cancel();

    // We'll handle the UI directly in the loading screens
    // by observing the wasCallRejected value
  }

  // Clean up call rejection listeners
  void stopCallRejectionListener() {
    _callRejectionCheckTimer?.cancel();
    isCallActive.value = false;
  }

  Future<void> initiateCall(
    String participantId,
    String type,
    DateTime scheduleTime,
  ) async {
    try {
      isJoining(true);
      callStatus('Initializing call...');
      // Set call type
      callType.value = type;

      final response =
          await ApiService.initiateCall(participantId, type, scheduleTime);

      print('Call Initiation Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseMap = jsonDecode(response.body)['data'];

        if (responseMap == null) {
          throw Exception('Invalid response data');
        }

        channel.value = responseMap['channelName'] ?? '';
        meetingId.value = responseMap['meeting']?['_id'] ?? '';
        token.value = responseMap['token'] ?? '';

        print('Call Details:'
            '\nChannel: ${channel.value}'
            '\nMeeting ID: ${meetingId.value}'
            '\nToken: ${token.value}');

        if (channel.value.isEmpty || token.value.isEmpty) {
          throw Exception('Missing channel or token');
        }

        callStatus('Joining call...');

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
            ),
            preventDuplicates: true,
          );
        }
      } else {
        throw Exception('Call initiation failed: ${response.statusCode}');
      }
    } catch (e) {
      isJoining(false);
      callStatus('Error: ${e.toString()}');
      rethrow;
    }
  }

  // Call this when user explicitly ends/cancels a call
  Future<void> rejectCall() async {
    if (meetingId.value.isNotEmpty) {
      await ChatCallService.rejectCall(meetingId.value);
    }
    stopCallRejectionListener();
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
  Future<void> initiateInstaTalkCall(String participantId, String type) async {
    callStatus('Starting InstaTalk call...');
    await initiateCall(participantId, type, DateTime.now());
  }

  Future<void> initiateMeetingCall(
      String participantId, String type, DateTime scheduleTime) async {
    try {
      callStatus('Starting scheduled call...');
      callType.value = type;
      print('Initiating meeting call for existing meeting');
      print('Participant: $participantId');
      print('Type: $type');
      print('Schedule Time: $scheduleTime');

      final response = await ApiService.initiateCall(
        participantId,
        type,
        scheduleTime,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseMap = jsonDecode(response.body)['data'];

        // Log the received data
        print('Meeting response: ${response.body}');

        channel.value = responseMap['channelName'] ?? '';
        meetingId.value = responseMap['meeting']?['_id'] ?? '';
        token.value = responseMap['token'] ?? '';

        if (channel.value.isEmpty || token.value.isEmpty) {
          throw Exception('Invalid meeting credentials received');
        }

        print('Successfully initialized meeting:'
            '\nChannel: ${channel.value}'
            '\nMeeting ID: ${meetingId.value}'
            '\nToken: ${token.value}');
      } else {
        throw Exception('Failed to initialize meeting: ${response.statusCode}');
      }
    } catch (e) {
      print('Error initiating meeting call: $e');
      throw e;
    }
  }

  void initializeEventHandlers() {
    _engine?.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          print('Local user joined channel: ${connection.channelId}');
          isCallActive.value = true;
          isCallConnected.value = true;

          // Notify call status system that user has joined a call
          _notifyUserJoinedCall();
        },
        onUserJoined: (RtcConnection connection, int uid, int elapsed) {
          print('Remote user joined: $uid');
          _remoteUid.value = uid;
          hasRemoteUserJoined.value = true;

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
          // Auto end call and go back when remote user leaves
          endCall();
          Get.back();
        },
        onConnectionStateChanged: (RtcConnection connection,
            ConnectionStateType state, ConnectionChangedReasonType reason) {
          print('Connection state changed: $state reason: $reason');
          isCallConnected.value =
              (state == ConnectionStateType.connectionStateConnected);
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
  }

  @override
  void onClose() {
    stopSessionTimer();
    stopCallRejectionListener();
    super.onClose();
  }
}
