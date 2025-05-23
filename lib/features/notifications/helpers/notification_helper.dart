import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:iftook/core/services/api_service.dart';
import 'package:iftook/core/services/shared_prefs.dart';
import 'package:iftook/features/auth/controllers/auth_controller.dart';
import 'package:iftook/features/calls/presentation/screens/laoding_voice_call_screen.dart';
import 'package:iftook/features/calls/presentation/screens/loading_video_call_screen.dart';
import 'package:iftook/features/friends/controllers/instaTalkController.dart';
import 'package:iftook/features/friends/presentation/screens/chat_room_screen.dart';
import 'package:iftook/features/home/controllers/home_controller.dart';
import 'package:iftook/features/profile/data/models/user.dart';
import 'package:iftook/helpers/app_colors.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../friends/controllers/chat_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../calls/presentation/screens/video_call_screen.dart';
import '../../calls/presentation/screens/voice_call_screen.dart';
import '../screens/incoming_call_screen.dart';
import 'notification_body.dart';

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin
      _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  static const String CALL_CHANNEL_ID = "call_channel_id";
  static const String CALL_CHANNEL_NAME = "Call Notifications";
  static const String CALL_CHANNEL_DESC = "Notifications for incoming calls";
  static const String MESSAGE_CHANNEL_ID = "message_channel_id";
  static const String MESSAGE_CHANNEL_NAME = "Message Notifications";
  static const String MESSAGE_CHANNEL_DESC = "Notifications for messages";
  static int _callNotificationId = 1000; // Unique ID for call notifications

  // Public method to show call notification that can be called from outside classes
  static Future<void> showCallNotification(RemoteMessage message) async {
    await _showCallNotification(message);
  }

  static Future<void> initialize(
      FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin) async {
    try {
      await _checkDeviceCapabilities();
      await _requestAllPermissions();

      var androidInitialize =
          const AndroidInitializationSettings('notification_icon');
      var iOSInitialize = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        notificationCategories: [
          DarwinNotificationCategory(
            'call_category',
            actions: [
              DarwinNotificationAction.plain('ACCEPT', 'Accept',
                  options: {DarwinNotificationActionOption.foreground}),
              DarwinNotificationAction.plain('DECLINE', 'Decline',
                  options: {DarwinNotificationActionOption.destructive}),
            ],
            options: {
              DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
            },
          ),
        ],
      );

      var initializationsSettings = InitializationSettings(
        android: androidInitialize,
        iOS: iOSInitialize,
      );

      flutterLocalNotificationsPlugin.initialize(
        initializationsSettings,
        onDidReceiveNotificationResponse: _handleNotificationResponse,
      );

      await _setupActionHandlers(flutterLocalNotificationsPlugin);
      await _createNotificationChannels();
      _setupFirebaseListeners(flutterLocalNotificationsPlugin);
    } catch (e) {
      debugPrint('Error initializing notification system: $e');
    }
  }

  static Future<void> _checkDeviceCapabilities() async {
    try {
      if (Platform.isAndroid) {
        final hasRingtone = await _checkRingtoneAccess();
        debugPrint('Device has ringtone access: $hasRingtone');
      }
    } catch (e) {
      debugPrint('Error checking device capabilities: $e');
    }
  }

  static Future<bool> _checkRingtoneAccess() async {
    try {
      const channel = MethodChannel('com.application.iftook/audio');
      return await channel.invokeMethod('checkRingtoneAccess') ?? false;
    } catch (e) {
      debugPrint('Error checking ringtone access: $e');
      return false;
    }
  }

  static Future<void> _requestAllPermissions() async {
    try {
      await _requestFirebaseNotificationPermissions();

      if (Platform.isAndroid) {
        final notificationStatus = await Permission.notification.request();
        debugPrint('Notification permission status: $notificationStatus');

        final phoneStatus = await Permission.phone.request();
        debugPrint('Phone permission status: $phoneStatus');

        if (await Permission.systemAlertWindow.isDenied) {
          final overlayStatus = await Permission.systemAlertWindow.request();
          debugPrint('System alert window permission status: $overlayStatus');
        }

        final audioStatus = await Permission.microphone.request();
        debugPrint('Microphone permission status: $audioStatus');
      }
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
    }
  }

  static Future<void> _requestFirebaseNotificationPermissions() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: true,
        carPlay: true,
        criticalAlert: true,
        provisional: false,
      );

      debugPrint(
          'Firebase Notification permission status: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('Error requesting Firebase permissions: $e');
    }
  }

  static void _setupFirebaseListeners(
      FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin) {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint(
          "onMessage: ${message.notification?.title}/${message.notification?.body}");

      try {
        Get.put(AuthController());
        if (await Get.find<AuthController>().isLoggedIn()) {
          if ((message.data['type'] == 'voice' ||
                  message.data['type'] == 'video') &&
              message.data['action'] != 'renewal') {
            // Only show call UI if it's not a renewal notification
            await _showCallNotification(message);
          } else if (message.data['type'] == 'instaTalk') {
            await handleInstaTalkNotification(message.data);
          } else {
            NotificationHelper.showNotification(
              message,
              flutterLocalNotificationsPlugin,
              false,
            );
          }
        }
      } catch (e) {
        debugPrint('Error handling message: $e');
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage? message) {
      debugPrint("callOnMessageOpenApp");

      try {
        if (message != null && message.data.isNotEmpty) {
          NotificationBody notificationBody = convertNotification(message.data);

          if ((notificationBody.type == 'voice' ||
                  notificationBody.type == 'video') &&
              message.data['action'] != 'renewal') {
            // Only show call UI if it's not a renewal notification
            showCallSnackBar(
              callerName: message.notification?.title ?? "Unknown Caller",
              callerImage: message.data['callerImage'] ?? "",
              isVideo: notificationBody.type == 'video',
              meetingId: message.data['meetingId'] ?? "",
              channelName: message.data['channelName'] ?? "",
              token: message.data['token'] ?? "",
            );
          } else if (message.data['type'] == 'instaTalk') {
            handleInstaTalkNotification(message.data);
          }
        }
      } catch (e) {
        debugPrint("Error processing notification: $e");
      }
    });
  }

  static Future<void> _handleNotificationResponse(
      NotificationResponse payload) async {
    try {
      if (payload.payload != null && payload.payload!.isNotEmpty) {
        debugPrint("Local notification payload: ${payload.payload}");

        Map<String, dynamic> payloadData = json.decode(payload.payload!);

        if (payload.actionId != null) {
          await _handleNotificationAction(payload.actionId!, payloadData);
          return;
        }

        if (payloadData.containsKey('chatRoomId') &&
            payloadData.containsKey('senderId')) {
          await _handleChatNotification(payloadData);
        } else if (payloadData.containsKey('type') &&
            (payloadData['type'] == 'voice' ||
                payloadData['type'] == 'video') &&
            payloadData['action'] != 'renewal') {
          // Only treat as call tap if it's not a renewal
          await _handleCallNotificationTap(payloadData);
        } else if (payloadData['type'] == 'instaTalk') {
          await handleInstaTalkNotification(payloadData);
        }
      }
    } catch (e) {
      debugPrint("Error handling notification click: $e");
    }
  }

  static Future<void> _handleChatNotification(
      Map<String, dynamic> payloadData) async {
    try {
      final senderId = payloadData['senderId'];
      final response = await ApiService.getUserById(senderId);

      if (response.statusCode == 200) {
        final userData = User.fromJson(
            (json.decode(response.body) as Map<String, dynamic>)['data']);

        Get.to(() => ChatRoomScreen(
              profile: userData,
              duration: 60,
            ));
      }
    } catch (e) {
      debugPrint("Error handling chat notification: $e");
    }
  }

  static Future<void> _handleCallNotificationTap(
      Map<String, dynamic> payloadData) async {
    final bool isVideo = payloadData['type'] == 'video';
    final String meetingId = payloadData['meetingId'] ?? '';
    final String channel = payloadData['channelName'] ?? '';
    final String token = payloadData['token'] ?? '';
    final String callerName = payloadData['callerName'] ?? 'Unknown Caller';
    final String callerImage =
        payloadData['callerImage'] ?? payloadData['callerProfilePicture'] ?? '';
    final bool isInstaTalk = payloadData['isInstaTalk'] == 'true';
    final String meetingType = payloadData['meetingType'] ?? 'regularMeeting';
    final String callDuration =
        payloadData['duration'] ?? payloadData['callDuration'] ?? '30';
    final String callerId = payloadData['callerId'] ?? '';

    showCallSnackBar(
      callerName: callerName,
      callerImage: callerImage,
      isVideo: isVideo,
      meetingId: meetingId,
      channelName: channel,
      token: token,
      isInstaTalk: isInstaTalk,
      meetingType: meetingType,
      callDuration: callDuration,
      callerId: callerId,
    );
  }

  static Future<void> _showCallNotification(RemoteMessage message) async {
    // First check if this is a renewal notification rather than an actual call
    if (message.data['action'] == 'renewal') {
      // For renewals, don't show call UI, just a normal notification
      final String callerName = message.data['callerName'] ??
          message.notification?.title?.split(' ')[0] ??
          "Someone";
      final String typeText =
          message.data['type'] == 'video' ? 'Video' : 'Voice';
      final String meetingType = message.data['meetingType'] ?? 'Call';

      final String title = "${meetingType.capitalize} Renewed";
      final String body = message.notification?.body ??
          "$callerName has renewed your $typeText ${message.data['isInstaTalk'] == 'true' ? 'InstaTalk' : 'Call'} session.";

      // Use a regular notification instead of a call notification
      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        MESSAGE_CHANNEL_ID,
        MESSAGE_CHANNEL_NAME,
        channelDescription: MESSAGE_CHANNEL_DESC,
        importance: Importance.high,
        priority: Priority.high,
      );

      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      // Show as regular notification
      await _flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecond, // Use current time for unique ID
        title,
        body,
        details,
        payload: json.encode(message.data),
      );

      // Don't proceed with call notification setup
      return;
    }

    // Extract call data with fallbacks to ensure we always have values
    final String callerName = message.data['callerName'] ??
        message.notification?.title?.split(' ')[0] ??
        message.data['senderName'] ??
        "Unknown Caller";
    final String callerInfo = message.notification?.body ?? "Incoming Call";
    final String callType = message.data['type'] ?? 'voice';
    final bool isVideo = callType == 'video';
    final String meetingType = message.data['meetingType'] ?? 'regularMeeting';
    final bool isInstaTalk = message.data['isInstaTalk'] == 'true';
    final String callDuration =
        message.data['duration'] ?? message.data['callDuration'] ?? "30";
    final String callerImage = message.data['callerImage'] ??
        message.data['callerProfilePicture'] ??
        message.data['senderImage'] ??
        "";
    final String callerId =
        message.data['callerId'] ?? message.data['senderId'] ?? "";

    Map<String, dynamic> payloadData = {
      ...message.data,
      'callerName': callerName,
      'callerImage': callerImage,
      'callAction': 'RECEIVED',
      'isInstaTalk': isInstaTalk,
      'meetingType': meetingType,
      'callerId': callerId,
      'callDuration': callDuration,
    };
    String payload = json.encode(payloadData);

    try {
      // Use our snackbar notification for in-app experience
      showCallSnackBar(
        callerName: callerName,
        callerImage: callerImage,
        isVideo: isVideo,
        meetingId: message.data['meetingId'] ?? "",
        channelName: message.data['channelName'] ?? "",
        token: message.data['token'] ?? "",
        callerId: callerId,
        callDuration: callDuration,
        callRate: message.data['callRate'] ?? "0",
        callerRating: message.data['callerRating'] ?? "0",
        isInstaTalk: isInstaTalk,
        meetingType: meetingType,
      );

      // Play ringtone
      _playCallRingtone();

      // Also show a system notification with action buttons
      final androidStyle = await _createCallNotificationStyle(
        callerName: callerName,
        callInfo: callerInfo,
        isVideo: isVideo,
        callerImage: message.data['callerImage'] ?? '',
      );

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        CALL_CHANNEL_ID,
        CALL_CHANNEL_NAME,
        channelDescription: CALL_CHANNEL_DESC,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.call,
        fullScreenIntent: true,
        showWhen: true,
        ongoing: true,
        autoCancel: false,
        visibility: NotificationVisibility.public,
        playSound:
            false, // Don't play sound from notification since we're using the ringtone player
        styleInformation: androidStyle,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            'ACCEPT',
            'Accept',
            icon: DrawableResourceAndroidBitmap('call_accept'),
            showsUserInterface: true,
            contextual: true,
          ),
          AndroidNotificationAction(
            'DECLINE',
            'Decline',
            icon: DrawableResourceAndroidBitmap('call_decline'),
            showsUserInterface: true,
            contextual: true,
          ),
        ],
      );

      final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default_ringtone.caf',
        interruptionLevel: InterruptionLevel.critical,
        categoryIdentifier: 'call_category',
      );

      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Show notification
      await _flutterLocalNotificationsPlugin.show(
        _callNotificationId,
        "${isVideo ? 'Video' : 'Voice'} Call from $callerName",
        "Tap to respond", // Simple instruction
        details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing call notification: $e');
      // Fallback to standard notification if there's an error
      _showFallbackCallNotification(callerName, isVideo, message, payload);
    }
  }

  static void _playCallRingtone() {
    try {
      FlutterRingtonePlayer().stop();

      FlutterRingtonePlayer().play(
        android: AndroidSounds.ringtone,
        ios: IosSounds.electronic,
        looping: true,
        volume: 1.0,
        asAlarm: true,
      );

      if (Platform.isAndroid) {
        const platform = MethodChannel('com.application.iftook/audio');
        platform.invokeMethod('playRingtoneAsCall');
      }
    } catch (e) {
      debugPrint('Error playing call ringtone: $e');
    }
  }

  static Future<void> _showFallbackCallNotification(String callerName,
      bool isVideo, RemoteMessage message, String payload) async {
    try {
      final AndroidNotificationDetails simpleAndroidDetails =
          AndroidNotificationDetails(
        CALL_CHANNEL_ID,
        CALL_CHANNEL_NAME,
        channelDescription: CALL_CHANNEL_DESC,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.call,
        fullScreenIntent: true,
      );

      final NotificationDetails simpleDetails = NotificationDetails(
        android: simpleAndroidDetails,
        iOS: const DarwinNotificationDetails(
          sound: 'default_ringtone.caf',
          presentAlert: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.critical,
        ),
      );

      await _flutterLocalNotificationsPlugin.show(
        _callNotificationId,
        callerName,
        isVideo ? 'Video Call' : 'Voice Call',
        simpleDetails,
        payload: payload,
      );
    } catch (fallbackError) {
      debugPrint('Error showing fallback notification: $fallbackError');
    }
  }

  static Future<StyleInformation> _createCallNotificationStyle({
    required String callerName,
    required String callInfo,
    required bool isVideo,
    required String callerImage,
  }) async {
    StyleInformation style;

    if (callerImage.isNotEmpty) {
      try {
        final String largeIconPath =
            await _downloadAndSaveFile(callerImage, 'caller_image');
        style = BigPictureStyleInformation(
          FilePathAndroidBitmap(largeIconPath),
          largeIcon: FilePathAndroidBitmap(largeIconPath),
          contentTitle: callerName,
          htmlFormatContentTitle: true,
          summaryText: isVideo ? 'Video Call' : 'Voice Call',
          htmlFormatSummaryText: true,
        );
      } catch (e) {
        debugPrint('Error creating picture style: $e');
        style = BigTextStyleInformation(
          callInfo,
          htmlFormatBigText: true,
          contentTitle: callerName,
          htmlFormatContentTitle: true,
          summaryText: isVideo ? 'Video Call' : 'Voice Call',
          htmlFormatSummaryText: true,
        );
      }
    } else {
      style = BigTextStyleInformation(
        callInfo,
        htmlFormatBigText: true,
        contentTitle: callerName,
        htmlFormatContentTitle: true,
        summaryText: isVideo ? 'Video Call' : 'Voice Call',
        htmlFormatSummaryText: true,
      );
    }

    return style;
  }

  static Future<void> stopCallNotificationEffects() async {
    try {
      try {
        await FlutterRingtonePlayer().stop();

        if (Platform.isAndroid) {
          const platform = MethodChannel('com.application.iftook/audio');
          await platform.invokeMethod('stopRingtone');
        }
      } catch (e) {
        debugPrint('Error stopping audio: $e');
      }
    } catch (e) {
      debugPrint('Error stopping notification effects: $e');
    }
  }

  static Future<bool> rejectCall(String meetingId) async {
    try {
      // Cancel the notification
      await _flutterLocalNotificationsPlugin.cancel(_callNotificationId);

      // Stop audio effects
      await stopCallNotificationEffects();

      // Send call rejection notification to backend
      try {
        // Prepare rejection data
        Map<String, dynamic> rejectionData = {
          'meetingId': meetingId,
          'status': 'rejected',
          'timestamp': DateTime.now().toIso8601String(),
        };

        // Send rejection to API
        final response = await ApiService.rejectCall(meetingId, rejectionData);

        if (response.statusCode == 200) {
          debugPrint('Call rejection successfully sent to server');
        } else {
          debugPrint('Error sending call rejection: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Exception during call rejection API call: $e');
      }

      // Show confirmation snackbar
      Get.snackbar(
        'Call Declined',
        'You declined the incoming call',
        backgroundColor: Colors.grey[800],
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );

      return true;
    } catch (e) {
      debugPrint('Error rejecting call: $e');
      return false;
    }
  }

  static Future<void> _createNotificationChannels() async {
    if (Platform.isAndroid) {
      try {
        final soundResourcesAvailable = await _checkSoundResources();

        final AndroidNotificationChannel callChannel =
            AndroidNotificationChannel(
          CALL_CHANNEL_ID,
          CALL_CHANNEL_NAME,
          description: CALL_CHANNEL_DESC,
          importance: Importance.max,
          playSound: true,
          sound: soundResourcesAvailable
              ? const RawResourceAndroidNotificationSound('ringtone')
              : null,
          enableLights: true,
        );

        const AndroidNotificationChannel messageChannel =
            AndroidNotificationChannel(
          MESSAGE_CHANNEL_ID,
          MESSAGE_CHANNEL_NAME,
          description: MESSAGE_CHANNEL_DESC,
          importance: Importance.high,
        );

        const AndroidNotificationChannel chatChannel =
            AndroidNotificationChannel(
          'chat_channel_id',
          'Chat Notifications',
          description: 'Notifications for chat messages',
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
        );

        final plugin = _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        await plugin?.createNotificationChannel(callChannel);
        await plugin?.createNotificationChannel(messageChannel);
        await plugin?.createNotificationChannel(chatChannel);
      } catch (e) {
        debugPrint('Error creating notification channels: $e');
      }
    }
  }

  static Future<bool> _checkSoundResources() async {
    try {
      const platform = MethodChannel('com.application.iftook/resources');
      final exists = await platform
              .invokeMethod('checkSoundResource', {'name': 'ringtone'}) ??
          false;
      return exists;
    } catch (e) {
      debugPrint('Error checking sound resources: $e');
      return false;
    }
  }

  static Future<void> _setupActionHandlers(
      FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin) async {
    final androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();

      await androidImplementation.createNotificationChannel(
        AndroidNotificationChannel(
          CALL_CHANNEL_ID,
          CALL_CHANNEL_NAME,
          importance: Importance.max,
          description: CALL_CHANNEL_DESC,
        ),
      );
    }
  }

  static Future<void> _handleNotificationAction(
      String action, Map<String, dynamic> payload) async {
    try {
      switch (action) {
        case 'reply':
          final chatRoomId = payload['chatRoomId'];
          final senderId = payload['senderId'];
          final replyText = payload['replyText'];

          if (chatRoomId != null && senderId != null && replyText != null) {
            // Get or create ChatController instance
            ChatController? chatController;
            try {
              if (!Get.isRegistered<ChatController>()) {
                Get.put(ChatController());
              }
              chatController = Get.find<ChatController>();
            } catch (e) {
              print('Error getting ChatController: $e');
              return;
            }

            // Send reply message
            await chatController.sendMessage(senderId, chatRoomId, replyText);

            // Show confirmation
            Get.snackbar(
              'Reply Sent',
              'Your reply has been sent successfully',
              backgroundColor: Colors.green,
              colorText: Colors.white,
            );
          }
          break;

        case 'mark_as_read':
          final chatRoomId = payload['chatRoomId'];
          if (chatRoomId != null) {
            // Get or create ChatController instance
            ChatController? chatController;
            try {
              if (!Get.isRegistered<ChatController>()) {
                Get.put(ChatController());
              }
              chatController = Get.find<ChatController>();
            } catch (e) {
              print('Error getting ChatController: $e');
              return;
            }

            // Fetch messages to update read status
            await chatController.fetchMessages();
          }
          break;

        case 'ACCEPT':
          // Handle accepting a call
          final isVideo = payload['type'] == 'video';
          final meetingId = payload['meetingId'] ?? '';
          final channelName = payload['channelName'] ?? '';
          final token = payload['token'] ?? '';
          final callerName = payload['callerName'] ?? 'Unknown Caller';
          final callerImage = payload['callerImage'] ?? '';

          // Stop any ringtone playing
          await stopCallNotificationEffects();

          // Cancel the notification
          await _flutterLocalNotificationsPlugin.cancel(_callNotificationId);

          // Navigate to the appropriate call screen
          if (isVideo) {
            await Get.to(() => VideoCallScreen(
                  meetingId: meetingId,
                  channel: channelName,
                  token: token,
                  initialTimer: int.parse(payload['callDuration'] ?? '30'),
                ));
          } else {
            await Get.to(() => VoiceCallScreen(
                  meetingId: meetingId,
                  channel: channelName,
                  token: token,
                  initialTimer: int.parse(payload['callDuration'] ?? '30'),
                ));
          }
          break;

        case 'DECLINE':
          // Handle declining a call
          final meetingId = payload['meetingId'] ?? '';

          // Reject the call through the API
          final rejected = await rejectCall(meetingId);

          // Show feedback to user
          if (rejected) {
            Get.snackbar(
              'Call Declined',
              'You declined the incoming call',
              backgroundColor: Colors.grey[800],
              colorText: Colors.white,
              duration: const Duration(seconds: 2),
            );
          }
          break;
      }
    } catch (e) {
      print('Error handling notification action: $e');
    }
  }

  static Future<void> showNotification(
    RemoteMessage message,
    FlutterLocalNotificationsPlugin fln,
    bool data,
  ) async {
    String title = message.notification!.title ?? '';
    String body = message.notification!.body ?? '';

    String payload = json.encode(message.data);

    AndroidNotificationDetails androidPlatformChannelSpecifics =
        const AndroidNotificationDetails(
      MESSAGE_CHANNEL_ID,
      MESSAGE_CHANNEL_NAME,
      channelDescription: MESSAGE_CHANNEL_DESC,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableLights: true,
      enableVibration: true,
      playSound: true,
      icon: 'notification_icon', // Add this line
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics);

    await fln.show(0, title, body, platformChannelSpecifics, payload: payload);
  }

  static Future<void> showChatNotification(
    String title,
    String message,
    Map<String, dynamic> payload,
    FlutterLocalNotificationsPlugin fln,
  ) async {
    try {
      final int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Create reply action for Android
      final AndroidNotificationAction replyAction = AndroidNotificationAction(
        'reply',
        'Reply',
        icon: DrawableResourceAndroidBitmap('reply_icon'),
        showsUserInterface: true,
        allowGeneratedReplies: true,
      );

      // Create mark as read action
      final AndroidNotificationAction markAsReadAction =
          AndroidNotificationAction(
        'mark_as_read',
        'Mark as Read',
        icon: DrawableResourceAndroidBitmap('read_icon'),
      );

      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'chat_channel_id',
        'Chat Notifications',
        channelDescription: 'Notifications for chat messages',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: 'notification_icon',
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.message,
        autoCancel: true,
        actions: [replyAction, markAsReadAction],
        styleInformation: BigTextStyleInformation(
          message,
          htmlFormatBigText: true,
          contentTitle: title,
          htmlFormatContentTitle: true,
        ),
      );

      // For iOS, create a notification category with reply action
      final DarwinNotificationCategory chatCategory =
          DarwinNotificationCategory(
        'chat_category',
        actions: [
          DarwinNotificationAction.text(
            'reply',
            'Reply',
            buttonTitle: 'Send',
            options: {
              DarwinNotificationActionOption.foreground,
              DarwinNotificationActionOption.authenticationRequired,
            },
          ),
          DarwinNotificationAction.plain(
            'mark_as_read',
            'Mark as Read',
            options: {DarwinNotificationActionOption.foreground},
          ),
        ],
      );

      final DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        categoryIdentifier: 'chat_category',
        interruptionLevel: InterruptionLevel.active,
      );

      final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await fln.show(
        notificationId,
        title,
        message,
        platformChannelSpecifics,
        payload: json.encode(payload),
      );
    } catch (e, stackTrace) {
      print('Error showing chat notification: $e');
      print('Stack trace: $stackTrace');
      await _showSimpleChatNotification(title, message, payload, fln);
    }
  }

  static Future<void> _showSimpleChatNotification(
    String title,
    String message,
    Map<String, dynamic> payload,
    FlutterLocalNotificationsPlugin fln,
  ) async {
    try {
      final int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Simple notification details without potentially problematic settings
      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'basic_chat_channel',
        'Basic Chat Notifications',
        channelDescription: 'Basic notifications for chat messages',
        importance: Importance.high,
        priority: Priority.high,
        icon: 'notification_icon', // Add this line
      );

      final NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidDetails);

      await fln.show(
        notificationId,
        title,
        message,
        platformChannelSpecifics,
        payload: json.encode(payload),
      );
    } catch (e) {
      print('Error showing simple chat notification: $e');
    }
  }

  static Future<String> _downloadAndSaveFile(
      String url, String fileName) async {
    try {
      final Directory directory = await getApplicationDocumentsDirectory();
      final String filePath = '${directory.path}/$fileName';
      final http.Response response = await http.get(Uri.parse(url));
      final File file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      return filePath;
    } catch (e) {
      debugPrint('Error downloading and saving file: $e');
      throw e;
    }
  }

  static NotificationBody convertNotification(Map<String, dynamic> data) {
    return NotificationBody.fromJson(data);
  }

  static Future<void> handleInstaTalkNotification(
      Map<String, dynamic> data) async {
    try {
      print('Handling InstaTalk notification: $data');

      final String? meetingId = data['meetingId'];
      final String? type = data['requestType'];
      final String? senderId = data['senderId'];
      final String? callerName = data['callerName'] ?? "Someone";
      final String? callType = data['type'] == 'video' ? 'Video' : 'Voice';

      // For InstaTalk requests, show a simple dismissable snackbar instead of a dialog
      if (meetingId != null && type != null) {
        // Show a simple snackbar
        Get.snackbar(
          'InstaTalk Request',
          '$callerName wants to have a quick ${type.toLowerCase()} chat with you',
          backgroundColor: AppColors.primaryColor.withOpacity(0.9),
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
          isDismissible: true,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(8),
          borderRadius: 8,
        );
      }
    } catch (e) {
      print('Error handling InstaTalk notification: $e');
    }
  }

  static Future<void> showBigTextNotification(
      String title,
      String body,
      String payload,
      FlutterLocalNotificationsPlugin fln,
      bool isInstaTalk) async {
    BigTextStyleInformation bigTextStyleInformation = BigTextStyleInformation(
      body,
      htmlFormatBigText: true,
      contentTitle: title,
      htmlFormatContentTitle: true,
    );
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      isInstaTalk ? "insta_talk_channel" : "regular_channel",
      isInstaTalk ? "InstaTalk Notifications" : "Regular Notifications",
      channelDescription: "description",
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: isInstaTalk, // Wake the screen for InstaTalk
      styleInformation: bigTextStyleInformation,
    );
    NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await fln.show(
        isInstaTalk ? 2 : 0, // Different ID for InstaTalk notifications
        title,
        body,
        platformChannelSpecifics,
        payload: payload);
  }

  static Future<void> showInstaTalkNotification(RemoteMessage message) async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    await NotificationHelper.initialize(flutterLocalNotificationsPlugin);

    String title = message.notification?.title ?? 'InstaTalk Request';
    String body =
        message.notification?.body ?? 'You have a new InstaTalk request';
    String callerName = message.data['callerName'] ?? 'Someone';
    String type = message.data['requestType'] ?? 'chat';

    // If app is in foreground, show a snackbar
    if (Get.context != null) {
      Get.snackbar(
        title,
        '$callerName wants to have a quick ${type.toLowerCase()} chat with you',
        backgroundColor: AppColors.primaryColor.withOpacity(0.9),
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
        isDismissible: true,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(8),
        borderRadius: 8,
      );
      return;
    }

    // Otherwise, show a normal notification
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'insta_talk_channel',
      'InstaTalk Notifications',
      channelDescription: 'Notifications for InstaTalk requests',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'notification_icon',
      color: AppColors.primaryColor,
      category: AndroidNotificationCategory.message,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecond,
      title,
      body,
      notificationDetails,
      payload: json.encode(message.data),
    );
  }

  static Future<void> onMessage(RemoteMessage message) async {
    print("onMessage Handler: ${message.notification?.title}");
    print("onMessage data: ${message.data}");

    try {
      // Get current user ID
      final currentUserId = await SharedPrefs.getUserIdSharedPreference();

      // For chat messages, check if we're the sender
      if (message.data['type'] == 'chat') {
        final senderId = message.data['senderId'];
        // If we're the sender, don't show notification
        if (senderId == currentUserId) {
          print('Skipping notification - we are the sender');
          return;
        }
      }

      // Check if this is an InstaTalk notification
      if (message.data['type'] == 'instaTalk') {
        // Use the simplified snackbar approach for InstaTalk
        String callerName = message.data['callerName'] ??
            message.notification?.title?.split(' ')[0] ??
            "Someone";
        String type = message.data['requestType'] ?? 'chat';

        // Show simple snackbar
        Get.snackbar(
          'InstaTalk Request',
          '$callerName wants to have a quick ${type.toLowerCase()} chat with you',
          backgroundColor: AppColors.primaryColor.withOpacity(0.9),
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
          isDismissible: true,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(8),
          borderRadius: 8,
        );
        return;
      }
      // Handle call notifications (only if not a renewal)
      else if ((message.data['type'] == 'voice' ||
              message.data['type'] == 'video') &&
          message.data['action'] != 'renewal') {
        await _showCallNotification(message);
        return;
      }
      // Handle regular notifications
      else {
        final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
            FlutterLocalNotificationsPlugin();
        await NotificationHelper.initialize(flutterLocalNotificationsPlugin);
        await NotificationHelper.showNotification(
            message, flutterLocalNotificationsPlugin, false);
      }
    } catch (e) {
      print('Error handling foreground message: $e');
    }
  }

  // New method to show call notification as a snackbar
  static void showCallSnackBar({
    required String callerName,
    required String callerImage,
    required bool isVideo,
    required String meetingId,
    required String channelName,
    required String token,
    String callerRating = "0",
    String callRate = "0",
    String callDuration = "30",
    String callerId = "",
    bool isInstaTalk = false,
    String meetingType = "regularMeeting",
  }) {
    // Play ringtone at low volume
    try {
      FlutterRingtonePlayer().play(
        android: AndroidSounds.ringtone,
        ios: IosSounds.glass,
        looping: true,
        volume: 0.3,
      );
    } catch (e) {
      debugPrint('Error playing ringtone: $e');
    }

    // Show a persistent snackbar
    Get.snackbar(
      '', // No title
      '', // No message
      isDismissible: false,
      duration: const Duration(seconds: 30), // Auto-dismiss after 30 seconds
      backgroundColor: Colors.black.withOpacity(0.8),
      margin: const EdgeInsets.all(8),
      borderRadius: 12,
      snackPosition: SnackPosition.TOP,
      padding: EdgeInsets.zero,
      snackStyle: SnackStyle.FLOATING,
      titleText: Container(),
      messageText: GestureDetector(
        onTap: () {
          // Stop ringtone
          FlutterRingtonePlayer().stop();

          // Close the snackbar
          Get.closeCurrentSnackbar();

          // Navigate to incoming call screen
          Get.to(() => IncomingCallScreen(
                callerName: callerName,
                callerImage: callerImage,
                isVideo: isVideo,
                meetingId: meetingId,
                channelName: channelName,
                token: token,
                callerRating: callerRating,
                callRate: callRate,
                callDuration: callDuration,
                callerId: callerId,
                isInstaTalk: isInstaTalk,
                meetingType: meetingType,
              ));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              // Caller image
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade800,
                ),
                child: callerImage.isNotEmpty
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: callerImage,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.person,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 16),
              // Call info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${isVideo ? 'Video' : 'Voice'} ${isInstaTalk ? 'InstaTalk' : 'Call'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      callerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Call button
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green,
                ),
                child: Icon(
                  isVideo ? Icons.videocam : Icons.call,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              // Decline button
              GestureDetector(
                onTap: () async {
                  // Stop ringtone
                  FlutterRingtonePlayer().stop();

                  // Reject the call via the API
                  await rejectCall(meetingId);

                  // Close the snackbar
                  Get.closeCurrentSnackbar();
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red,
                  ),
                  child: const Icon(
                    Icons.call_end,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<dynamic> myBackgroundMessageHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print(
        "onBackground: ${message.notification!.title}/${message.notification!.body}/${message.notification!.titleLocKey}");
  }

  try {
    if (message.data['type'] == 'voice' || message.data['type'] == 'video') {
      await NotificationHelper._showCallNotification(message);
    } else if (message.data['type'] == 'instaTalk') {
      await NotificationHelper.showInstaTalkNotification(message);
    } else {
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();
      await NotificationHelper.initialize(flutterLocalNotificationsPlugin);
      await NotificationHelper.showNotification(
          message, flutterLocalNotificationsPlugin, true);
    }
  } catch (e) {
    if (kDebugMode) {
      print("Error handling background message: $e");
    }
  }
}
