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
                payloadData['type'] == 'video')) {
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
                initialTimer: 30, //change thsi as well initialTimer
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
      // Create unique notification ID for chat messages
      final int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'chat_channel_id', // unique channel ID for chat notifications
        'Chat Notifications',
        channelDescription: 'Notifications for chat messages',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: 'notification_icon', // Add this line
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.message,
        autoCancel: true,
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
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

      // Fallback to simpler notification if complex one fails
      await _showSimpleChatNotification(
        title,
        message,
        payload,
        fln,
      );
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

      if (meetingId != null && type != null) {
        // For now, show a dialog to accept/reject the request
        if (Get.context != null) {
          // App is in foreground
          _showInstaTalkRequestDialog(meetingId, type, senderId);
        }
      }
    } catch (e) {
      print('Error handling InstaTalk notification: $e');
    }
  }

  static void _showInstaTalkRequestDialog(
      String meetingId, String type, String? senderId) {
    // Get username if available
    String username = 'Someone';
    if (senderId != null) {
      // Try to get user info (don't await to keep dialog showing quickly)
      ApiService.getUserById(senderId).then((response) {
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          username = data['data']['name'] ?? 'Someone';

          // Update dialog title if it's still showing
          if (Get.isDialogOpen == true) {
            Get.back();
            _showInstaTalkAcceptDialog(meetingId, type, username);
          }
        }
      }).catchError((e) {
        print('Error fetching user details: $e');
      });
    }

    // Show dialog immediately with default name, will update later
    _showInstaTalkAcceptDialog(meetingId, type, username);
  }

  static void _showInstaTalkAcceptDialog(
      String meetingId, String type, String username) {
    // Format the type for display
    String typeDisplay = type.capitalize ?? type;

    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          'InstaTalk $typeDisplay Request',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$username wants to have a quick $type conversation with you!',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              'This InstaTalk will last for 30 seconds.',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
            },
            child: const Text('Decline', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
            ),
            onPressed: () {
              Get.back();
              _acceptInstaTalkRequest(meetingId);
            },
            child: const Text('Accept'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  static Future<void> _acceptInstaTalkRequest(String meetingId) async {
    try {
      final _instaTalkController = Get.find<InstaTalkController>();
      final userId = await SharedPrefs.getUserIdSharedPreference();

      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      final result = await _instaTalkController.acceptInstaTalk(meetingId);
      print('InstaTalk accept result: $result'); // Added for debugging

      Get.back(); // Close loading dialog

      if (result != null &&
          result.containsKey('meeting') &&
          result.containsKey('participant')) {
        // Navigate to appropriate screen based on meeting type
        final meetingType = result['meeting']['type'];

        try {
          // Convert participant data to User object
          final Map<String, dynamic> participantData =
              Map<String, dynamic>.from(result['participant']);
          final User participant = User.fromJson(participantData);

          // Get the duration value, default to 30 seconds if not found
          final int duration = result['meeting']['duration'] ?? 30;

          // Get token and channel name
          final String token = result['token'] as String;
          final String channelName = result['channelName'] as String;

          print('Navigating to $meetingType screen with duration: $duration');
          print('Token: $token, Channel: $channelName');

          switch (meetingType) {
            case 'chat':
              Get.to(() => ChatRoomScreen(
                    profile: participant,
                    isInstaTalk: true,
                    duration: duration,
                  ));
              break;
            case 'voice':
              Get.to(() => VoiceCallLoadingScreen(
                    participant: participant,
                    scheduleTime: DateTime.now(),
                    type: "voice",
                    isInstaTalk: true,
                    instaTalkDuration: duration,
                    // token: token,
                    // channel: channelName,
                    // meetingId: meetingId,
                  ));
              break;
            case 'video':
              Get.to(() => VideoCallLoadingScreen(
                    participant: participant,
                    scheduleTime: DateTime.now(),
                    type: "video",
                    isInstaTalk: true,
                    instaTalkDuration: duration,
                    // token: token,
                    // channel: channelName,
                    // meetingId: meetingId,
                  ));
              break;
          }
        } catch (e) {
          print('Error processing participant data: $e');
          throw Exception('Error processing meeting data: $e');
        }
      } else {
        throw Exception('No data returned from AcceptInstaTalk call');
      }
    } catch (e) {
      print('Error accepting InstaTalk request: $e');
      Get.snackbar(
        'Error',
        'Failed to accept InstaTalk request',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
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

    await NotificationHelper.showBigTextNotification(
        title,
        body,
        json.encode(message.data),
        flutterLocalNotificationsPlugin,
        true // is InstaTalk notification
        );
  }

  static Future<void> onMessage(RemoteMessage message) async {
    print("onMessage Handler: ${message.notification?.title}");
    print("onMessage data: ${message.data}");

    try {
      // Check if this is an InstaTalk notification
      if (message.data['type'] == 'instaTalk') {
        // Handle InstaTalk notification
        await handleInstaTalkNotification(message.data);
        return;
      }
      // Handle call notifications
      else if (message.data['type'] == 'voice' ||
          message.data['type'] == 'video') {
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
      await NotificationHelper.handleInstaTalkNotification(message.data);
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
