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
import 'package:iftook/features/auth/controllers/auth_controller.dart';
import 'package:iftook/features/friends/presentation/screens/chat_room_screen.dart';
import 'package:iftook/features/profile/data/models/user.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

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
      const channel = MethodChannel('com.yourcompany.iftook/audio');
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
          if (message.data['type'] == 'voice' ||
              message.data['type'] == 'video') {
            await _showCallNotification(message);
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

          if (notificationBody.type == 'voice' ||
              notificationBody.type == 'video') {
            Get.to(() => IncomingCallScreen(
                  callerName: message.notification?.title ?? "Unknown Caller",
                  callerImage: message.data['callerImage'] ?? "",
                  isVideo: notificationBody.type == 'video',
                  meetingId: message.data['meetingId'] ?? "",
                  channelName: message.data['channelName'] ?? "",
                  token: message.data['token'] ?? "",
                ));
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
                payloadData['type'] == 'video')) {
          await _handleCallNotificationTap(payloadData);
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

        Get.to(() => ChatRoomScreen(profile: userData));
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
    final String callerImage = payloadData['callerImage'] ?? '';

    Get.to(() => IncomingCallScreen(
          callerName: callerName,
          callerImage: callerImage,
          isVideo: isVideo,
          meetingId: meetingId,
          channelName: channel,
          token: token,
        ));
  }

  static Future<void> _showCallNotification(RemoteMessage message) async {
    // Extract call data
    final String callerName = message.notification?.title ?? "Unknown Caller";
    final String callerInfo = message.notification?.body ?? "Incoming Call";
    final String callType = message.data['type'] ?? 'voice';
    final bool isVideo = callType == 'video';

    Map<String, dynamic> payloadData = {
      ...message.data,
      'callerName': callerName,
      'callAction': 'RECEIVED',
    };
    String payload = json.encode(payloadData);

    try {
      // Immediately launch the incoming call screen for a more direct experience
      Get.to(
          () => IncomingCallScreen(
                callerName: callerName,
                callerImage: message.data['callerImage'] ?? "",
                isVideo: isVideo,
                meetingId: message.data['meetingId'] ?? "",
                channelName: message.data['channelName'] ?? "",
                token: message.data['token'] ?? "",
              ),
          fullscreenDialog: true,
          transition: Transition.fadeIn,
          duration: const Duration(milliseconds: 300));

      // Start ringtone
      _playCallRingtone();

      // Also show a notification for persistent access and in case direct launch fails
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
        playSound: true,
        styleInformation: androidStyle,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            'ACCEPT',
            'Accept',
            icon: DrawableResourceAndroidBitmap('call_accept'),
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            'DECLINE',
            'Decline',
            icon: DrawableResourceAndroidBitmap('call_decline'),
            showsUserInterface: true,
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
        callerName,
        isVideo ? 'Video Call' : 'Voice Call',
        details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing call notification: $e');
      // Fallback to standard notification if direct launch fails
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
        const platform = MethodChannel('com.yourcompany.iftook/audio');
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
          const platform = MethodChannel('com.yourcompany.iftook/audio');
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
      await _flutterLocalNotificationsPlugin.cancel(_callNotificationId);
      await stopCallNotificationEffects();
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

        final plugin = _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        await plugin?.createNotificationChannel(callChannel);
        await plugin?.createNotificationChannel(messageChannel);
      } catch (e) {
        debugPrint('Error creating notification channels: $e');
      }
    }
  }

  static Future<bool> _checkSoundResources() async {
    try {
      const platform = MethodChannel('com.yourcompany.iftook/resources');
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
      String actionId, Map<String, dynamic> payload) async {
    try {
      final String meetingId = payload['meetingId'] ?? '';
      final String channel = payload['channelName'] ?? '';
      final String token = payload['token'] ?? '';
      final bool isVideo = payload['type'] == 'video';

      if (actionId == 'ACCEPT') {
        await stopCallNotificationEffects();

        if (isVideo) {
          Get.to(() => VideoCallScreen(
                meetingId: meetingId,
                channel: channel,
                token: token,
              ));
        } else {
          Get.to(() => VoiceCallScreen(
                meetingId: meetingId,
                channel: channel,
                token: token,
              ));
        }

        await _flutterLocalNotificationsPlugin.cancel(_callNotificationId);
      } else if (actionId == 'DECLINE') {
        await stopCallNotificationEffects();

        await _flutterLocalNotificationsPlugin.cancel(_callNotificationId);
      }
    } catch (e) {
      debugPrint('Error handling notification action: $e');
    }
  }

  static Future<void> showNotification(RemoteMessage message,
      FlutterLocalNotificationsPlugin fln, bool data) async {
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
}

Future<dynamic> myBackgroundMessageHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print(
        "onBackground: ${message.notification!.title}/${message.notification!.body}/${message.notification!.titleLocKey}");
  }

  try {
    if (message.data['type'] == 'voice' || message.data['type'] == 'video') {
      await NotificationHelper._showCallNotification(message);
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
