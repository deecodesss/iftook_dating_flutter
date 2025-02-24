import 'dart:developer';

import 'package:get/get.dart';
import 'package:iftook/features/calls/presentation/screens/video_call_screen.dart';
import 'package:permission_handler/permission_handler.dart';

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
    // final response =
    //     await ApiService.initiateCall(participantId, type, scheduleTime);
    // final responseMap = jsonDecode(response.body)['data'];
    // if (response.statusCode == 200 || response.statusCode == 201) {
    //   channel.value = responseMap['channelName'];
    //   meetingId.value = responseMap['meeting']['_id'];
    //   token.value = responseMap['token'];
    //   print("channel: ${channel.value}, token: ${token.value}");
    //   Get.off(
    //     () => type == 'voice'
    //         ? VoiceCallScreen(
    //             channel: channel.value,
    //             meetingId: meetingId.value,
    //             token: token.value,
    //           )
    //         : VideoCallScreen(
    //             channel: channel.value,
    //             meetingId: meetingId.value,
    //             token: token.value,
    //           ),
    //   );
    // }
    Get.off(() => VideoCallScreen(
          channel: "1953648cfe27a07",
          meetingId: meetingId.value,
          token:
              "007eJxTYNCslq01zTrteivv7+TjJ2vnp8/VZCnRPfDfxODJjhWnt/YqMJimJJoYJFkamqQkp5kkGlhYplokJaWmmpsmWhqZGZpbvPq/O/0X7550iZ1/GRgZGBlYGBgZQIAJTDKDSRYwyc9gaGlqbGZikZyWamSeaGDOxGBmDgAL0CVW/u9Nvcu9JV3DZyMrIwMjAwsDIAAJMYJIZTLKASX4GQ0tTYzMTi+S0VCPzRANzCQYz8yQjoxQDI1ND0yQzUzMTwxQjE2NjE2MA2c0spg==/AyGlqbGZiYWyWmpRuaJBubMDIZGxgAe9h92",
        ));
  }
}
