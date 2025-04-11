import 'dart:convert';
import 'dart:developer';
import 'dart:async';

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

  void startSessionTimer(int durationInMinutes, {Function? onEnd}) {
    sessionTimeRemaining.value = durationInMinutes * 60;
    onSessionEnd = onEnd;

    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (sessionTimeRemaining.value > 0) {
        sessionTimeRemaining.value--;
      } else {
        timer.cancel();
        onSessionEnd?.call();
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
      startSessionTimer(minutes);

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

  // Initiate a meeting call
  // Future<Map<String, dynamic>?> initiateMeetingCall(
  //   String recipientId,
  //   String callType,
  //   DateTime scheduleTime,
  // ) async {
  //   try {
  //     final userId = await SharedPrefs.getUserIdSharedPreference();
  //     if (userId == null) {
  //       throw Exception("User not logged in");
  //     }

  //     final response = await _apiService.post('/calls/initiate-meeting', {
  //       'callerId': userId,
  //       'recipientId': recipientId,
  //       'callType': callType,
  //       'scheduleTime': scheduleTime.toIso8601String(),
  //     });

  //     if (response.statusCode == 200) {
  //       return response.data;
  //     }
  //     return null;
  //   } catch (e) {
  //     print("Error initiating meeting call: $e");
  //     return null;
  //   }
  // }

  // Initiate an InstaTalk call
  Future<Map<String, dynamic>?> initiateInstaTalkCall(
    String recipientId,
    String callType,
  ) async {
    try {
      final userId = await SharedPrefs.getUserIdSharedPreference();
      if (userId == null) {
        throw Exception("User not logged in");
      }

      final response = await _apiService.post('/calls/initiate-instatalk', {
        'callerId': userId,
        'recipientId': recipientId,
        'callType': callType,
      });

      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      print("Error initiating InstaTalk call: $e");
      return null;
    }
  }

  // End an ongoing call
  Future<bool> endCall(String callId) async {
    try {
      final userId = await SharedPrefs.getUserIdSharedPreference();
      if (userId == null) {
        throw Exception("User not logged in");
      }

      final response = await _apiService.post('/calls/end', {
        'callId': callId,
        'userId': userId,
      });

      return response.statusCode == 200;
    } catch (e) {
      print("Error ending call: $e");
      return false;
    }
  }

  // Fetch user's current wallet balance
  Future<void> fetchUserWalletBalance() async {
    try {
      final userId = await SharedPrefs.getUserIdSharedPreference();
      if (userId == null) return;

      final response = await _apiService.get('/wallet/$userId');
      if (response.statusCode == 200 && response.data != null) {
        userWalletBalance.value =
            double.tryParse(response.data['balance'].toString()) ?? 0.0;
      }
    } catch (e) {
      print("Error fetching wallet balance: $e");
    }
  }

  @override
  void onInit() {
    super.onInit();
    fetchUserWalletBalance();
  }

  @override
  void onClose() {
    stopSessionTimer();
    super.onClose();
  }
}
