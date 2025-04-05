import 'dart:convert';
import 'dart:developer';
import 'dart:async';

import 'package:get/get.dart';
import 'package:iftook/features/calls/presentation/screens/video_call_screen.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/services/api_service.dart';
import '../presentation/screens/voice_call_screen.dart';

class CallController extends GetxController {
  RxString token = ''.obs;
  RxString meetingId = ''.obs;
  RxString channel = ''.obs;

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
      final response =
          await ApiService.initiateCall(participantId, type, scheduleTime);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseMap = jsonDecode(response.body)['data'];

        channel.value = responseMap['channelName'];
        meetingId.value = responseMap['meeting']['_id'];
        token.value = responseMap['token'];

        print(
            "Received from API - channel: ${channel.value}, token: ${token.value}");

        Get.off(
          () => type == 'voice'
              ? VoiceCallScreen(
                  channel: channel.value,
                  meetingId: meetingId.value,
                  token: token.value,
                )
              : VideoCallScreen(
                  channel: channel.value,
                  meetingId: meetingId.value,
                  token: token.value,
                ),
        );
      } else {
        log("Call initiation failed: ${response.statusCode} - ${response.body}");
        Get.snackbar('Error', 'Failed to initiate call');
      }
    } catch (e) {
      log("Error initiating call: $e");
      Get.snackbar('Error', 'An error occurred while initiating the call');
    }
  }

  // Helper method to check if call is free
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
      final perMinuteRate =
          baseAmount / 30; // 30-minute rate to per-minute rate
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
    try {
      final response = await ApiService.initiateCall(
        participantId,
        type,
        DateTime.now(),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseMap = jsonDecode(response.body)['data'];
        channel.value = responseMap['channelName'];
        meetingId.value = responseMap['meeting']['_id'];
        token.value = responseMap['token'];
      } else {
        throw Exception('Failed to initiate InstaTalk call');
      }
    } catch (e) {
      print('Error initiating InstaTalk call: $e');
      throw e;
    }
  }

  Future<void> initiateMeetingCall(
      String participantId, String type, DateTime scheduleTime) async {
    try {
      final response = await ApiService.initiateCall(
        participantId,
        type,
        scheduleTime,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseMap = jsonDecode(response.body)['data'];
        channel.value = responseMap['channelName'];
        meetingId.value = responseMap['meeting']['_id'];
        token.value = responseMap['token'];
      } else {
        throw Exception('Failed to initiate meeting call');
      }
    } catch (e) {
      print('Error initiating meeting call: $e');
      throw e;
    }
  }

  @override
  void onClose() {
    stopSessionTimer();
    super.onClose();
  }
}
