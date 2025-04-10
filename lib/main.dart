import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:iftook/features/splash/splash_screen.dart';
import 'package:iftook/theme/app_theme.dart';

import 'features/notifications/controllers/notification_controller.dart';
import 'features/notifications/helpers/notification_body.dart';
import 'features/notifications/helpers/notification_helper.dart';
import 'features/profile/data/models/user.dart';
import 'features/friends/presentation/screens/chat_room_screen.dart';
import 'firebase_options.dart';
import 'core/services/api_service.dart';

// Global key to access the scaffold messenger
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
String? fcmToken;
Future<void> updateFCMToken() async {
  FirebaseMessaging.instance.getToken().then((token) {
    fcmToken = token;
    Get.put(NotificationController()).updateFCMToken(fcmToken!);
    print("FCM Token: $token");
  });
}

// Handle notification click when app is in terminated state
Future<void> handleInitialNotification() async {
  final RemoteMessage? remoteMessage =
      await FirebaseMessaging.instance.getInitialMessage();

  if (remoteMessage != null) {
    debugPrint("Initial notification received.");
    await handleNotificationClick(remoteMessage);
  }
}

// Handle notification click when app is in background or foreground
Future<void> setupNotificationClickHandlers() async {
  // Handle notification when app is in background but opened
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint("onMessageOpenedApp: Notification clicked.");
    handleNotificationClick(message);
  });

  // Add specific handler for foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint("onMessage: Notification received in foreground.");
    NotificationHelper.onMessage(message);
  });
}

// Common function to handle notification click
Future<void> handleNotificationClick(RemoteMessage message) async {
  try {
    debugPrint("Handling notification click: ${message.data}");

    // Check for InstaTalk notification first
    if (message.data['type'] == 'instaTalk') {
      await NotificationHelper.handleInstaTalkNotification(message.data);
      return;
    }

    // Handle chat notifications
    if (message.data['type'] == 'chat') {
      final String? chatRoomId = message.data['chatRoomId'];
      final String? senderId = message.data['senderId'];
      final String? senderName = message.data['senderName'];
      final String? senderPhoto = message.data['senderPhoto'];

      if (chatRoomId != null && senderId != null) {
        debugPrint(
            "Navigating to chat from notification. ChatRoom: $chatRoomId");

        // Create a minimal User object from notification data
        final userData = User(
          sId: senderId,
          name: senderName ?? 'User',
          photos: senderPhoto != null ? [senderPhoto] : [],
        );

        // Give app a moment to initialize before navigating
        await Future.delayed(const Duration(milliseconds: 500));

        // Navigate to chat screen with the sender's profile and chatRoomId
        Get.to(
          () => ChatRoomScreen(
            profile: userData,
            existingChatRoomId:
                chatRoomId, // Add this parameter to ChatRoomScreen
          ),
        );
        return;
      }
    }

    // Extract chat related data from notification
    final String? chatRoomId = message.data['chatRoomId'];
    final String? senderId = message.data['senderId'];

    if (chatRoomId != null && senderId != null) {
      debugPrint(
          "Navigating to chat from notification. ChatRoom: $chatRoomId, Sender: $senderId");

      // Fetch user info for the sender to display in chat screen
      final response = await ApiService.getUserById(senderId);
      if (response.statusCode == 200) {
        final userData = User.fromJson(
            (json.decode(response.body) as Map<String, dynamic>)['data']);

        // Give app a moment to initialize before navigating
        await Future.delayed(const Duration(milliseconds: 500));

        // Navigate to chat screen with the sender's profile
        Get.to(() => ChatRoomScreen(profile: userData));
        return;
      }
    }
  } catch (e) {
    debugPrint("Error handling notification click: $e");
  }
}

// Update myBackgroundMessageHandler to handle InstaTalk notifications
@pragma('vm:entry-point')
Future<void> myBackgroundMessageHandler(RemoteMessage message) async {
  print("Background message received");
  print("Notification Message: ${message.notification?.title}");
  print("Data Message: ${message.data}");

  // Handle InstaTalk notification specially in the background
  if (message.data['type'] == 'instaTalk') {
    // Show a special notification for InstaTalk that the user can tap on
    await NotificationHelper.showInstaTalkNotification(message);
    return;
  }

  // Original handling for other notification types
  print("Handling other background notifications.");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  NotificationBody? body;
  try {
    // Removed permission request code
    await handleInitialNotification(); // Handle notification if app opened from terminated state
    await setupNotificationClickHandlers(); // Setup handlers for background/foreground states

    await NotificationHelper.initialize(flutterLocalNotificationsPlugin);
    FirebaseMessaging.onBackgroundMessage(myBackgroundMessageHandler);
    await updateFCMToken();
  } catch (e) {
    debugPrint("Error during initialization: ${e.toString()}");
  }
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: "iftook",
      home: SplashScreen(),
      theme: AppThemes.darkTheme,
      initialRoute: '/',
    );
  }
}
