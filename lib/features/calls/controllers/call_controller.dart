import 'dart:convert';
import 'dart:developer';

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
}
