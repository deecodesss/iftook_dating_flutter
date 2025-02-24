// import 'dart:developer';
//
// import 'package:agora_rtc_engine/agora_rtc_engine.dart';
// import 'package:agora_uikit/agora_uikit.dart';
// import 'package:flutter/widgets.dart';
// import 'package:get/get.dart';
//
// class AgoraApi {
//   static RxInt agoraStatus = 0.obs;
//   static AgoraClient? client;
//
//   static agoraClintInit({
//     required BuildContext context,
//     required String channelName,
//     required String callType, // "voice" or "video"
//   }) async {
//     log("Agora client initialization for $callType call");
//
//     // Determine permissions dynamically based on the call type
//     List<Permission> permissions = [Permission.microphone];
//     if (callType == "video") {
//       permissions.add(Permission.camera);
//     }
//
//     client = AgoraClient(
//       agoraConnectionData: AgoraConnectionData(
//         appId: "5da40b914dcf4a089e8bbee75a926178",
//         channelName: channelName,
//       ),
//       agoraEventHandlers: agoraEventHandlers(context),
//       enabledPermission: permissions, // Dynamic permissions based on callType
//     );
//
//     await client!.initialize();
//     agoraStatus(1);
//   }
//
//   static AgoraRtcEventHandlers agoraEventHandlers(BuildContext context) {
//     return AgoraRtcEventHandlers(
//       onError: (error, message) {
//         log("agoraEventHandlers Error :: $error || message :: $message");
//       },
//       onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
//         log("agoraEventHandlers local user ${connection.localUid} joined");
//       },
//       onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
//         log("user join :: ${connection.localUid}");
//       },
//       onUserOffline: (RtcConnection connection, int remoteUid,
//           UserOfflineReasonType reason) async {
//         if (reason == UserOfflineReasonType.userOfflineQuit) {
//           log("message message message");
//           await client!.engine.leaveChannel();
//           Navigator.pop(context);
//           agoraStatus(0);
//         }
//       },
//       onUserStateChanged: (connection, remoteUid, state) {},
//       onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {},
//     );
//   }
// }
