import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/features/calls/presentation/screens/laoding_voice_call_screen.dart';
import 'package:iftook/features/calls/presentation/screens/loading_video_call_screen.dart';
import 'package:iftook/features/friends/presentation/screens/chat_room_screen.dart';
import 'package:iftook/features/profile/data/models/user.dart';

class ScreenNavigator {
  // Navigate to Voice Call
  static Future<void> navigateToVoiceCall({
    required User participant,
    required DateTime scheduleTime,
    bool isInstatalk = false,
    int instaTalkDuration = 30,
    Function? onSessionEnd,
  }) async {
    await Get.to(() => VoiceCallLoadingScreen(
          participant: participant,
          scheduleTime: scheduleTime,
          type: "voice",
          isInstatalk: isInstatalk,
          instaTalkDuration: instaTalkDuration,
          onSessionEnd: onSessionEnd,
        ));
  }

  // Navigate to Video Call
  static Future<void> navigateToVideoCall({
    required User participant,
    required DateTime scheduleTime,
    bool isInstatalk = false,
    int instaTalkDuration = 30,
    Function? onSessionEnd,
  }) async {
    await Get.to(() => VideoCallLoadingScreen(
          participant: participant,
          scheduleTime: scheduleTime,
          type: "video",
          isInstatalk: isInstatalk,
          instaTalkDuration: instaTalkDuration,
          onSessionEnd: onSessionEnd,
        ));
  }

  // Navigate to Chat Room
  static Future<void> navigateToChatRoom({
    required User profile,
    bool isInstatalk = false,
    int duration = 30,
    bool isFriend = false,
    bool isInstatalkSender = false,
    DateTime? scheduledTime,
    Function? onSessionEnd,
  }) async {
    await Get.to(() => ChatRoomScreen(
          profile: profile,
          isInstatalk: isInstatalk,
          duration: duration,
          isFriend: isFriend,
          isInstatalkSender: isInstatalkSender,
          scheduledTime: scheduledTime,
          onSessionEnd: onSessionEnd,
        ));
  }

  // Handle meeting join based on type
  static Future<void> handleMeetingJoin({
    required User participant,
    required String type,
    required DateTime scheduleTime,
    bool isInstatalk = false,
    int instaTalkDuration = 30,
    Function? onSessionEnd,
  }) async {
    switch (type.toLowerCase()) {
      case 'voice':
        await navigateToVoiceCall(
          participant: participant,
          scheduleTime: scheduleTime,
          isInstatalk: isInstatalk,
          instaTalkDuration: instaTalkDuration,
          onSessionEnd: onSessionEnd,
        );
        break;

      case 'video':
        await navigateToVideoCall(
          participant: participant,
          scheduleTime: scheduleTime,
          isInstatalk: isInstatalk,
          instaTalkDuration: instaTalkDuration,
          onSessionEnd: onSessionEnd,
        );
        break;

      case 'chat':
        await navigateToChatRoom(
          profile: participant,
          isInstatalk: isInstatalk,
          duration: instaTalkDuration,
          isInstatalkSender: false,
          scheduledTime: scheduleTime,
          onSessionEnd: onSessionEnd,
        );
        break;

      default:
        Get.snackbar(
          'Error',
          'Unknown meeting type',
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
        );
    }
  }
}
