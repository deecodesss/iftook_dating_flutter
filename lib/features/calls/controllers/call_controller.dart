import 'dart:convert';
import 'dart:developer';
import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:get/get.dart';
import 'package:iftook/features/calls/presentation/screens/video_call_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

import '../../../core/services/api_service.dart';
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

  Future<void> handleCameraAndMic(Permission permisison) async {
    final status = await permisison.request();
    log(status.toString());
  }

  Future<void> initiateCall(
    String participantId,
    String type,
    DateTime scheduleTime,
  ) async {
    try {
      isJoining(true);
      callStatus('Initializing call...');

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
      log("Error initiating call: $e");
      Get.snackbar(
        'Error',
        'Failed to start call. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isJoining(false);
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
  Future<void> initiateInstaTalkCall(String participantId, String type) async {
    callStatus('Starting InstaTalk call...');
    await initiateCall(participantId, type, DateTime.now());
  }

  Future<void> initiateMeetingCall(
      String participantId, String type, DateTime scheduleTime) async {
    try {
      callStatus('Starting scheduled call...');
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
    } catch (e) {
      print('Error joining channel: $e');
      throw Exception('Failed to join call: $e');
    }
  }

  void endCall() {
    try {
      _engine?.leaveChannel();
      _remoteUid.value = 0;
      isCallActive.value = false;
      hasRemoteUserJoined.value = false;
      isCallConnected.value = false;
    } catch (e) {
      print('Error ending call: $e');
    }
  }

  @override
  void onInit() {
    super.onInit();
    // fetchUserWalletBalance();
  }

  @override
  void onClose() {
    stopSessionTimer();
    super.onClose();
  }
}
