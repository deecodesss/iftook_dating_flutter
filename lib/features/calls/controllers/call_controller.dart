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
    final response =
        await ApiService.initiateCall(participantId, type, scheduleTime);
    final responseMap = jsonDecode(response.body)['data'];
    if (response.statusCode == 200 || response.statusCode == 201) {
      channel.value = responseMap['channelName'];
      meetingId.value = responseMap['meeting']['_id'];
      token.value = responseMap['token'];
      print("channel: ${channel.value}, token: ${token.value}");
      Get.off(
        () => type == 'voice'
            ? VoiceCallScreen(
                channel: "1953648cfe27a07",
                meetingId: meetingId.value,
                token:
                    "007eJxTYFjUWW9TIrwibovbvDuRsh0fbxxPm9pwznnNpskK7L42WW8UGExTEk0MkiwNTVKS00wSDSwsUy2SklJTzU0TLY3MDM0tmg+eS598/ly6eCs/KyMDIwMLAyMDCDCBSWYwyQIm+RkMLU2NzUwsktNSjcwTDcwlGMzMk4yMUgyMTA1Nk8xMzUwMU4xMjI1NjAHOBCiQ",
              )
            : VideoCallScreen(
                channel: "1953648cfe27a07",
                meetingId: meetingId.value,
                token:
                    "007eJxTYFjUWW9TIrwibovbvDuRsh0fbxxPm9pwznnNpskK7L42WW8UGExTEk0MkiwNTVKS00wSDSwsUy2SklJTzU0TLY3MDM0tmg+eS598/ly6eCs/KyMDIwMLAyMDCDCBSWYwyQIm+RkMLU2NzUwsktNSjcwTDcwlGMzMk4yMUgyMTA1Nk8xMzUwMU4xMjI1NjAHOBCiQ",
              ),
      );
    }
    // Get.off(() => VideoCallScreen(
    //       channel: "1953648cfe27a07",
    //       meetingId: meetingId.value,
    //       token:
    //           "007eJxTYAjuiYtVmnAhZ1vhjKkTrz9yDtiaknYppvTF5c9/DTt9TRIVGExTEk0MkiwNTVKS00wSDSwsUy2SklJTzU0TLY3MDM0tmI32pDcEMjKsXHOSkZEBAkF8fgZDS1NjMxOL5LRUI/NEA3MGBgBFwyNe",
    //     ));
  }
}
