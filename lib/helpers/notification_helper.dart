import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:iftook/features/calls/presentation/screens/laoding_voice_call_screen.dart';
import 'package:iftook/features/calls/presentation/screens/loading_video_call_screen.dart';
import 'package:iftook/features/calls/services/chat_call_service.dart';
import 'package:iftook/features/profile/data/models/user.dart';
import 'package:iftook/helpers/app_colors.dart';

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin
      _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _callChannel =
      AndroidNotificationChannel(
    'call_channel',
    'Call Notifications',
    importance: Importance.max,
    enableVibration: true,
    playSound: true,
    showBadge: true,
  );

  static Future<void> initialize() async {
    const AndroidInitializationSettings androidInitialize =
        AndroidInitializationSettings('app_icon');

    final InitializationSettings initializationSettings =
        const InitializationSettings(
      android: androidInitialize,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final payload = response.payload;
        if (payload != null) {
          final data = jsonDecode(payload);
          _handleNotificationAction(data, response.actionId);
        }
      },
    );

    // Create notification channels
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_callChannel);
  }

  static Future<void> showCallNotification({
    required String title,
    required String body,
    required Map<String, dynamic> payload,
  }) async {
    final meetingId = payload['meetingId'];
    final type = payload['type'];
    final callerName = payload['callerName'] ?? 'Someone';
    final callerId = payload['callerId'];
    final callerProfilePicture = payload['callerProfilePicture'];
    final isVideo = type == 'video';

    // Create a temp User object for the caller
    final caller = User(
      sId: callerId,
      name: callerName,
      photos: callerProfilePicture != null && callerProfilePicture.isNotEmpty
          ? [callerProfilePicture]
          : [],
    );

    // Show a snackbar with call controls instead of full-screen notification
    Get.snackbar(
      'Incoming ${isVideo ? 'Video' : 'Voice'} Call',
      'From $callerName',
      backgroundColor: Colors.black87,
      colorText: Colors.white,
      duration: const Duration(seconds: 30),
      isDismissible: false,
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(8),
      borderRadius: 8,
      icon: CircleAvatar(
        backgroundImage:
            callerProfilePicture != null && callerProfilePicture.isNotEmpty
                ? NetworkImage(callerProfilePicture)
                : null,
        child: callerProfilePicture == null || callerProfilePicture.isEmpty
            ? const Icon(Icons.person, color: Colors.white)
            : null,
      ),
      mainButton: TextButton(
        onPressed: () => Get.back(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Decline button
            ElevatedButton.icon(
              icon: const Icon(Icons.call_end, color: Colors.white),
              label:
                  const Text('Decline', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Get.back(); // Remove snackbar
                _rejectCall(meetingId, callerId);
              },
            ),
            const SizedBox(width: 8),
            // Accept button
            ElevatedButton.icon(
              icon: const Icon(Icons.call, color: Colors.white),
              label:
                  const Text('Accept', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                Get.back(); // Remove snackbar
                _acceptCall(
                  caller: caller,
                  meetingId: meetingId,
                  token: payload['token'],
                  channelName: payload['channelName'],
                  isVideo: isVideo,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static void showCallRejectedNotification(String recipientName) {
    Get.snackbar(
      'Call Declined',
      '$recipientName declined your call',
      backgroundColor: Colors.red.shade900,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(8),
      icon: const Icon(Icons.call_end, color: Colors.white),
    );
  }

  static void _acceptCall({
    required User caller,
    required String meetingId,
    required String token,
    required String channelName,
    required bool isVideo,
  }) {
    if (isVideo) {
      Get.to(() => VideoCallLoadingScreen(
            participant: caller,
            type: "video",
            scheduleTime: DateTime.now(),
            meetingId: meetingId,
            token: token,
            channel: channelName,
          ));
    } else {
      Get.to(() => VoiceCallLoadingScreen(
            participant: caller,
            type: "voice",
            scheduleTime: DateTime.now(),
            meetingId: meetingId,
            token: token,
            channel: channelName,
          ));
    }
  }

  static Future<void> _rejectCall(String meetingId, String callerId) async {
    try {
      // Call the service method to reject the call
      await ChatCallService.rejectCall(meetingId);
    } catch (e) {
      print('Error rejecting call: $e');
    }
  }

  static void _handleNotificationAction(
      Map<String, dynamic> data, String? actionId) {
    if (data['type'] == 'voice' || data['type'] == 'video') {
      if (actionId == 'accept') {
        final caller = User(
          sId: data['callerId'],
          name: data['callerName'],
          photos: data['callerProfilePicture'] != null
              ? [data['callerProfilePicture']]
              : [],
        );

        _acceptCall(
          caller: caller,
          meetingId: data['meetingId'],
          token: data['token'],
          channelName: data['channelName'],
          isVideo: data['type'] == 'video',
        );
      } else if (actionId == 'reject') {
        _rejectCall(data['meetingId'], data['callerId']);
      }
    }
  }
}
