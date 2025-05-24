import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:iftook/features/shared/controllers/user_online_controller.dart';
import 'package:iftook/features/splash/splash_screen.dart';
import 'package:iftook/theme/app_theme.dart';
import 'package:iftook/helpers/permissions_handler.dart';

import 'features/notifications/controllers/notification_controller.dart';
import 'features/notifications/helpers/notification_body.dart';
import 'features/notifications/helpers/notification_helper.dart';
import 'features/profile/data/models/user.dart';
import 'features/friends/presentation/screens/chat_room_screen.dart';
import 'firebase_options.dart';
import 'core/services/api_service.dart';
import 'core/services/socket_service.dart';
import 'package:iftook/helpers/permissions_controller.dart';
import 'package:iftook/core/services/shared_prefs.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:iftook/features/calls/services/call_notification_service.dart';
import 'package:flutter/services.dart';

// Global instances
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
String? fcmToken;

// Setup notification action listeners
Future<void> setupNotificationActionListeners() async {
  // For Android
  final androidImplementation =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  if (androidImplementation != null) {
    await androidImplementation.requestNotificationsPermission();

    // Setup action handlers
    await androidImplementation.createNotificationChannel(
      const AndroidNotificationChannel(
        'call_channel_id',
        'Call Notifications',
        description: 'Notifications for incoming calls',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        showBadge: true,
        sound: RawResourceAndroidNotificationSound('ringtone'),
      ),
    );
  }
}

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
    if (message.data['type']?.toString() == 'instaTalk') {
      await NotificationHelper.handleInstaTalkNotification(message.data);
      return;
    }

    // Handle chat notifications
    if (message.data['type']?.toString() == 'chat') {
      final String? chatRoomId = message.data['chatRoomId']?.toString();
      final String? senderId = message.data['senderId']?.toString();
      final String? senderName = message.data['senderName']?.toString();
      final String? senderPhoto = message.data['senderPhoto']?.toString();

      if (chatRoomId != null && senderId != null) {
        debugPrint(
            "Navigating to chat from notification. ChatRoom: $chatRoomId");

        // Create a minimal User object from notification data
        final userData = User(
          sId: senderId,
          name: senderName ?? 'User',
          photos: senderPhoto != null ? [senderPhoto] : [],
        );

        // Use post frame callback for safer navigation
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Get.to(
            () => ChatRoomScreen(
              profile: userData,
              duration: 60,
              existingChatRoomId: chatRoomId,
            ),
          );
        });
        return;
      }
    }

    // Extract chat related data from notification
    final String? chatRoomId = message.data['chatRoomId']?.toString();
    final String? senderId = message.data['senderId']?.toString();

    if (chatRoomId != null && senderId != null) {
      debugPrint(
          "Navigating to chat from notification. ChatRoom: $chatRoomId, Sender: $senderId");

      // Fetch user info for the sender to display in chat screen
      final response = await ApiService.getUserById(senderId);
      if (response.statusCode == 200) {
        final userData = User.fromJson(
            (json.decode(response.body) as Map<String, dynamic>)['data']);

        // Use post frame callback for safer navigation
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Get.to(() => ChatRoomScreen(
                profile: userData,
                duration: 60,
              ));
        });
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
  debugPrint("🔔 Background message received");
  debugPrint("📝 Notification Message: ${message.notification?.title}");
  debugPrint("📝 Data Message: ${message.data}");

  try {
    // Get current user ID
    final currentUserId = await SharedPrefs.getUserIdSharedPreference();
    debugPrint("👤 Current user ID: $currentUserId");

    // For chat messages, check if we're the sender
    if (message.data['type']?.toString() == 'chat') {
      final senderId = message.data['senderId'];
      // If we're the sender, don't show notification
      if (senderId == currentUserId) {
        debugPrint('⚠️ Skipping background notification - we are the sender');
        return;
      }
    }

    // Handle call notifications in the background, but only if it's a real call (not a renewal)
    if ((message.data['type']?.toString() == 'voice' ||
            message.data['type']?.toString() == 'video') &&
        message.data['action']?.toString() != 'renewal') {
      debugPrint('📞 Handling incoming call notification');
      debugPrint('📞 Call type: ${message.data['type']}');
      debugPrint('📞 Call action: ${message.data['action']}');
      debugPrint('📞 Meeting ID: ${message.data['meetingId']}');
      debugPrint('📞 Channel: ${message.data['channelName']}');
      debugPrint('📞 Token: ${message.data['token']}');

      await NotificationHelper.initialize(flutterLocalNotificationsPlugin);
      await CallNotificationService().handleIncomingCall(message);
      return;
    }

    // Handle InstaTalk notification specially in the background
    if (message.data['type']?.toString() == 'instaTalk') {
      debugPrint('📱 Handling InstaTalk notification');
      await NotificationHelper.showInstaTalkNotification(message);
      return;
    }

    // Original handling for other notification types
    debugPrint("📝 Handling other background notifications.");
    await NotificationHelper.initialize(flutterLocalNotificationsPlugin);
    await NotificationHelper.showNotification(
        message, flutterLocalNotificationsPlugin, true);
  } catch (e) {
    debugPrint("❌ Error handling background message: $e");
  }
}

// Initialize socket and online status services
Future<void> initializeOnlineStatusService() async {
  try {
    print('📱 Starting online status service initialization...');

    // Initialize socket service
    final socketService = SocketService();
    await socketService.initSocket();

    // Add a check to ensure connection was successful
    if (!socketService.isConnected) {
      print(
          '⚠️ Socket not connected after initialization, waiting 3 seconds and retrying...');
      // Wait and retry once
      await Future.delayed(const Duration(seconds: 3));
      await socketService.reconnect();

      // Check again after retry
      if (!socketService.isConnected) {
        print('⚠️ Socket still not connected after retry');
      } else {
        print('✅ Socket connected successfully after retry');
      }
    }

    // Get the socket ID if available
    final socketId = socketService.socketId;
    print('🔌 Socket ID: $socketId');

    // Initialize and register the user online controller
    final controller = Get.put(UserOnlineController(), permanent: true);

    // Add periodic check to ensure socket stays connected
    Timer.periodic(const Duration(minutes: 5), (timer) async {
      if (!socketService.isConnected) {
        print(
            '🔄 Periodic check: Socket disconnected, attempting to reconnect...');
        await socketService.reconnect();
      } else {
        print('✅ Periodic check: Socket connection is healthy');
      }
    });

    print('✅ Online status service initialized successfully');
  } catch (e) {
    print('❌ Error initializing online status service: $e');
    print('⚠️ Retrying initialization in 5 seconds...');

    // Retry after a delay
    await Future.delayed(const Duration(seconds: 5));
    try {
      // Initialize socket service again
      final socketService = SocketService();
      await socketService.initSocket();

      // Initialize and register the user online controller
      Get.put(UserOnlineController(), permanent: true);

      print('✅ Online status service initialized successfully on retry');
    } catch (retryError) {
      print('❌ Error on retry: $retryError');
      print('⚠️ Online status features may not work correctly');
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  NotificationBody? body;
  try {
    // Request notification permissions
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    await handleInitialNotification();
    await setupNotificationClickHandlers();
    await setupNotificationActionListeners();

    await NotificationHelper.initialize(flutterLocalNotificationsPlugin);
    FirebaseMessaging.onBackgroundMessage(myBackgroundMessageHandler);
    await updateFCMToken();

    // Initialize online status service
    await initializeOnlineStatusService();

    // Reset permissions explanation state on app launch
    PermissionsHandler().resetPermissionsState();

    // Initialize permissions controller
    Get.put(PermissionsController(), permanent: true);
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

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Register handler for new intents (Android)
    if (Platform.isAndroid) {
      const channel = MethodChannel('com.iftook.app/intent');
      channel.setMethodCallHandler((call) async {
        if (call.method == 'onNewIntent') {
          // Handle the intent here - the app was already running
          debugPrint('🚀 App received new intent while running');

          // You might need to extract call data and handle navigation
          final args = call.arguments as Map<dynamic, dynamic>?;
          if (args != null && args.containsKey('call_id')) {
            // Handle call intent
            debugPrint('📱 Call intent received: ${args['call_id']}');
          }
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes
    debugPrint('App lifecycle state changed to: $state');

    if (state == AppLifecycleState.resumed) {
      // App came to foreground
      debugPrint('App resumed - checking for pending calls');
    }
  }

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
