import 'dart:convert';
import 'dart:async';
import 'dart:io' show Platform; // Import Platform
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:iftook/features/calls/controllers/call_controller.dart';
import 'package:iftook/features/calls/presentation/screens/call_screen.dart';
import 'package:iftook/features/calls/presentation/screens/dedicatedScreens/instaTalk/ITVideoCall.dart';
import 'package:iftook/features/calls/presentation/screens/dedicatedScreens/instaTalk/ITVoiceCall.dart';
import 'package:iftook/features/calls/presentation/screens/dedicatedScreens/meetingCalls/normalVideoCall.dart';
import 'package:iftook/features/calls/presentation/screens/dedicatedScreens/meetingCalls/normalVoiceCall.dart';
import 'package:iftook/features/calls/presentation/screens/loading_voice_call_screen.dart';
import 'package:iftook/features/calls/presentation/screens/missed_call_screen.dart';
import 'package:iftook/features/calls/presentation/screens/video_call_screen.dart';
import 'package:iftook/features/calls/services/ringtone_service.dart'; // Import the new service
import 'package:iftook/features/profile/data/models/user.dart';
import 'package:iftook/core/services/api_service.dart';
import 'package:permission_handler/permission_handler.dart';

/// CallNotificationService handles incoming call notifications using CallKit.
///
/// This service manages the full lifecycle of a call notification:
/// 1. Receiving call data from Firebase
/// 2. Displaying CallKit UI to the user
/// 3. Handling user actions (accept, decline, miss)
/// 4. Transitioning to the appropriate call screen
/// 5. Managing call state through CallController
class CallNotificationService {
  static final CallNotificationService _instance =
      CallNotificationService._internal();
  factory CallNotificationService() => _instance;
  CallNotificationService._internal() {
    // Initialize ringtone service
    _ringtoneService = RingtoneService();
    _ringtoneService.initialize();
  }

  // State tracking variables
  bool _isHandlingCall =
      false; // Tracks if service is actively processing a call setup
  String?
      _currentCallId; // Stores the ID of the call currently being managed by CallKit
  StreamSubscription? _callEventSubscription;
  final Set<String> _callsBeingEnded = {}; // To prevent re-entrant call ending

  // Call ringtone control - now using the dedicated service
  late final RingtoneService _ringtoneService;

  // Call Controller reference for state management
  CallController? _callController;

  // Local notifications for fallback
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Get the call controller instance
  CallController get callController {
    if (_callController == null) {
      try {
        _callController = Get.find<CallController>();
      } catch (e) {
        _callController = Get.put(CallController());
      }
    }
    return _callController!;
  }

  /// Handles an incoming call push notification
  ///
  /// Displays the CallKit UI and sets up event handlers
  Future<void> handleIncomingCall(RemoteMessage message) async {
    debugPrint('🔔 Processing incoming call notification');
    debugPrint('🔔 Incoming call data: ${message.data}');
    debugPrint('🔔 Notification title: ${message.notification?.title}');
    debugPrint('🔔 Notification body: ${message.notification?.body}');

    // Check if we're already handling a call
    if (_isHandlingCall) {
      debugPrint('⚠️ Already handling a call, ignoring new call');
      return;
    }

    try {
      // Request permissions first to ensure we can show the CallKit UI
      await _requestPermissions();

      // Check if we are already displaying a CallKit notification for a different call
      if (_isHandlingCall &&
          _currentCallId != null &&
          _currentCallId != message.data['meetingId']) {
        debugPrint(
            '⚠️ CallKit UI is active for $_currentCallId. New call ${message.data['meetingId']} ignored.');
        return;
      }

      _isHandlingCall = true; // Mark that we are starting to handle/show a call

      // Get the meeting ID and validate it
      final newCallId = message.data['meetingId']?.toString();
      if (newCallId == null || newCallId.isEmpty) {
        debugPrint(
            '❌ Error: meetingId is null or empty in incoming call data.');
        _isHandlingCall = false;
        return;
      }
      _currentCallId =
          newCallId; // Set the ID for the call we are about to show

      // Update the CallController's state to incoming
      callController.updateCallState(CallState.incoming);

      // Store the call info in the CallController
      callController.setupIncomingCall(newCallId,
          message.data['channelName'] ?? '', message.data['token'] ?? '');

      debugPrint('📞 Current call ID set to: $_currentCallId');

      // Extract call data
      final String callerName = message.data['callerName'] ??
          message.notification?.title?.split(' ')[0] ??
          "Unknown Caller";
      final String callType = message.data['type'] ?? 'voice';
      final bool isVideo = callType == 'video';
      final String meetingType =
          message.data['meetingType'] ?? 'regularMeeting';
      final bool isInstatalk = message.data['isInstatalk'] == 'true';
      final String callDuration =
          message.data['duration'] ?? message.data['duration'] ?? "30";
      final String callerImage = message.data['callerImage'] ??
          message.data['callerProfilePicture'] ??
          message.data['senderImage'] ??
          "";
      final String callerId =
          message.data['callerId'] ?? message.data['senderId'] ?? "";
      final String channelName = message.data['channelName'] ?? "";
      final String token = message.data['token'] ?? "";

      debugPrint('📞 Call details:');
      debugPrint('- Caller: $callerName');
      debugPrint('- Type: $callType');
      debugPrint('- Channel: $channelName');
      debugPrint('- Token: $token');
      debugPrint('- Duration: $callDuration');

      // Cancel any existing call notifications first
      await FlutterCallkitIncoming.endAllCalls();
      debugPrint('✅ Ended any existing calls');

      // Create call parameters with improved lock screen handling
      final params = CallKitParams(
        id: _currentCallId!,
        nameCaller: callerName,
        appName: 'iftook',
        avatar: callerImage,
        handle: callerId,
        type: isVideo ? 1 : 0,
        // Fix decimal duration parsing by converting to integer milliseconds
        duration: ((double.tryParse(callDuration) ?? 30.0) * 1000).toInt(),
        textAccept: 'Accept',
        textDecline: 'Decline',
        missedCallNotification: NotificationParams(
          showNotification: false,
          isShowCallback: true,
          subtitle: 'Missed call from $callerName',
          callbackText: 'Call back',
        ),
        callingNotification: const NotificationParams(
          showNotification: true,
          isShowCallback: true,
          subtitle: 'Incoming call...',
          callbackText: 'Hang Up',
        ),
        extra: <String, dynamic>{
          'meetingId': _currentCallId,
          'channelName': channelName,
          'token': token,
          'callerId': callerId,
          'duration': callDuration,
          'callRate': message.data['callRate'] ?? "0",
          'callerRating': message.data['callerRating'] ?? "0",
          'isInstatalk': isInstatalk,
          'meetingType': meetingType,
          'isVideo': isVideo,
          'callerName': callerName,
          'callerImage': callerImage,
          'timestamp': DateTime.now().millisecondsSinceEpoch
        },
        headers: <String, dynamic>{
          'apiKey': 'Abc@123!',
          'platform': 'flutter',
        },
        android: const AndroidParams(
          isCustomNotification: true,
          isCustomSmallExNotification: true,
          isShowLogo: true,
          ringtonePath: 'ringtone_default', // Custom ringtone in res/raw folder
          backgroundColor: '#0955fa',
          actionColor: '#4CAF50',
          textColor: '#ffffff',
          incomingCallNotificationChannelName: "Incoming Call",
          missedCallNotificationChannelName: "Missed Call",
          isShowCallID: false,
          isShowFullLockedScreen: true, // Critical for locked screen display
          isImportant: true,
        ),
        ios: const IOSParams(
          iconName: 'CallKitLogo',
          handleType: 'generic',
          supportsVideo: true,
          maximumCallGroups: 2,
          maximumCallsPerCallGroup: 1,
          audioSessionMode: 'default',
          audioSessionActive: true,
          audioSessionPreferredSampleRate: 44100.0,
          audioSessionPreferredIOBufferDuration: 0.005,
          supportsDTMF: true,
          supportsHolding: true,
          supportsGrouping: false,
          supportsUngrouping: false,
          ringtonePath: 'system_ringtone_default',
        ),
      );

      debugPrint('📞 Showing call notification...');
      // Setup call event listeners before showing the call
      _setupCallEventListeners();

      // Play ringtone using the ringtone service
      _ringtoneService.playRingtone(asIncomingCall: true);

      // Show call notification
      await FlutterCallkitIncoming.showCallkitIncoming(params);

      // Add a fallback for locked screens - show a high priority notification
      if (Platform.isAndroid) {
        _showFullScreenNotification(
          callerName: callerName,
          isVideo: isVideo,
          meetingId: newCallId,
          callerId: callerId,
          channelName: channelName,
          token: token,
        );
      }

      debugPrint('✅ Call notification shown for $_currentCallId');
      _isHandlingCall = false; // Mark that handling/showing is complete
    } catch (e, stackTrace) {
      debugPrint('❌ Error handling incoming call: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      _resetCallState(); // Reset if error occurs during setup
    }
  }

  // Simplified method to show a full screen notification as fallback
  Future<void> _showFullScreenNotification({
    required String callerName,
    required bool isVideo,
    required String meetingId,
    required String callerId,
    required String channelName,
    required String token,
  }) async {
    try {
      debugPrint('🔔 Showing fallback notification for locked device');

      // Initialize notifications if needed
      await _initLocalNotifications();

      // Create a high priority notification with full screen intent
      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'call_channel_high_priority',
        'Incoming Call High Priority',
        channelDescription: 'High priority channel for incoming calls',
        importance: Importance.max,
        priority: Priority.max,
        fullScreenIntent: true,
        ongoing: true,
        category: AndroidNotificationCategory.call,
        visibility: NotificationVisibility.public,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      // Create payload with call data
      final String payload = json.encode({
        'meetingId': meetingId,
        'callerName': callerName,
        'isVideo': isVideo,
        'channelName': channelName,
        'token': token,
        'type': isVideo ? 'video' : 'voice',
        'callerId': callerId,
      });

      // Show the notification
      // await _flutterLocalNotificationsPlugin.show(
      //   meetingId.hashCode, // Use meetingId hash as notification ID
      //   'Incoming ${isVideo ? 'Video' : 'Voice'} Call',
      //   callerName,
      //   notificationDetails,
      //   payload: payload,
      // );

      debugPrint('✅ Fallback notification shown');
    } catch (e) {
      debugPrint('❌ Error showing fallback notification: $e');
    }
  }

  // Initialize local notifications
  Future<void> _initLocalNotifications() async {
    // Android initialization settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('notification_icon');

    // iOS initialization settings
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Initialize settings
    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // Initialize plugin
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification response
        try {
          if (response.payload != null) {
            final data = json.decode(response.payload!);
            // Handle the tap action based on payload
            _handleNotificationTap(data);
          }
        } catch (e) {
          debugPrint('Error handling notification tap: $e');
        }
      },
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'call_channel_high_priority',
        'Incoming Call High Priority',
        description: 'High priority channel for incoming calls',
        importance: Importance.max,
      );

      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  // Handle notification tap
  void _handleNotificationTap(Map<String, dynamic> data) {
    try {
      final String meetingId = data['meetingId'] ?? '';
      final String channelName = data['channelName'] ?? '';
      final String token = data['token'] ?? '';
      final bool isVideo = data['isVideo'] == true;
      final String callerId = data['callerId'] ?? '';
      final String duration = data['duration'] ?? '30';
      final String callerName = data['callerName'] ?? 'Unknown Caller';

      // Create a User object for caller
      final caller = User(
        sId: callerId,
        name: callerName,
      );

      // If this is a valid call, navigate to appropriate screen
      if (meetingId.isNotEmpty && channelName.isNotEmpty && token.isNotEmpty) {
        if (data['isInstatalk'] == false && isVideo) {
          Get.to(() => NormalVideoCallScreen(
                initialTimer: 30,
                meetingId: meetingId,
                channel: channelName,
                token: token,
                participant: caller,
                isIncomingCall: true,
              ));
        } else if (data['isInstatalk'] == false && !isVideo) {
          Get.to(() => NormalVoiceCallScreen(
                meetingId: meetingId,
                channel: channelName,
                token: token,
                participant: caller,
                isIncomingCall: true,
                callerName: callerName,
                callerImage: data['callerImage'] ?? '',
                initialTimer: data['duration'] != null
                    ? double.tryParse(data['duration'].toString()) ?? 30
                    : 30,
                // isInstatalk: data['isInstatalk'] == false ? false : true,
              ));
        } else if (data['isInstatalk'] == true && !isVideo) {
          Get.to(() => ITVoiceCallScreen(
                meetingId: meetingId,
                channel: channelName,
                token: token,
                participant: caller,
                isIncomingCall: true,
                callerName: callerName,
                callerImage: data['callerImage'] ?? '',
                // initialTimer: data['duration'] != null
                //     ? int.tryParse(data['duration'].toString()) ?? 30
                //     : 30,
                // isInstatalk: data['isInstatalk'] == false ? false : true,
              ));
        } else {
          Get.to(() => ITVideoCallScreen(
                meetingId: meetingId,
                channel: channelName,
                token: token,
                participant: caller,
                isIncomingCall: true,
                // callerName: callerName,
                // callerImage: data['callerImage'] ?? '',
                // initialTimer: data['duration'] != null
                //     ? int.tryParse(data['duration'].toString()) ?? 30
                //     : 30,
                // isInstatalk: data['isInstatalk'] == false ? false : true,
              ));
        }
      }
    } catch (e) {
      debugPrint('Error navigating to call screen: $e');
    }
  }

  /// Request necessary permissions for call functionality
  Future<void> _requestPermissions() async {
    try {
      // Request notification permissions
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );

      // Request audio permissions for calls
      await Permission.microphone.request();
      await Permission.camera.request();

      if (Platform.isAndroid) {
        // Android notification permissions
        if (await Permission.notification.isDenied) {
          await Permission.notification.request();
        }

        // For keeping device awake during call
        if (await Permission.ignoreBatteryOptimizations.isDenied) {
          await Permission.ignoreBatteryOptimizations.request();
        }

        // Request system alert window permission if needed
        if (!await Permission.systemAlertWindow.isGranted) {
          debugPrint(
              "SystemAlertWindow permission is not granted. Overlay features might not work.");
        }
      }

      debugPrint('✅ Permissions requested successfully');
    } catch (e) {
      debugPrint('❌ Error requesting permissions: $e');
    }
  }

  /// Set up CallKit event listeners
  void _setupCallEventListeners() {
    debugPrint('🎧 Setting up call event listeners');
    // Cancel any existing subscription
    _callEventSubscription?.cancel();

    // Setup new subscription
    _callEventSubscription =
        FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
      // Ensure CallEvent is typed
      if (event == null) {
        debugPrint('⚠️ Received null event from CallKit');
        return;
      }

      final eventCallId = (event.body is Map<String, dynamic>)
          ? (event.body as Map<String, dynamic>)['id']?.toString()
          : null;
      debugPrint(
          '📞 Received CallKit event: ${event.event} for call ID: $eventCallId. Current active call ID: $_currentCallId');
      debugPrint('📞 Event body: ${event.body}');

      // Use the Event enum for comparison
      switch (event.event) {
        case Event.actionCallIncoming:
          debugPrint('📞 Incoming call event received for ID: $eventCallId.');
          // Set state to incoming
          callController.updateCallState(CallState.incoming);
          // Make sure ringtone is playing
          _ringtoneService.playRingtone(asIncomingCall: true);
          break;

        case Event.actionCallStart:
          debugPrint('📞 Outgoing call started for ID: $eventCallId.');
          callController.updateCallState(CallState.outgoing);
          break;

        case Event.actionCallAccept:
          debugPrint('✅ Call accepted for ID: $eventCallId.');
          callController.updateCallState(CallState.connecting);
          // Stop ringtone
          await _ringtoneService.stopRingtone();

          if (eventCallId != _currentCallId && _currentCallId != null) {
            debugPrint(
                '⚠️ Accepted call ID $eventCallId does not match current ID $_currentCallId. Ignoring.');
          } else {
            await _handleCallAccept(event.body as Map<String, dynamic>?);
          }
          break;

        case Event.actionCallDecline:
          debugPrint('❌ Call declined for ID: $eventCallId.');
          callController.updateCallState(CallState.rejected);
          // Stop ringtone
          await _ringtoneService.stopRingtone();

          if (eventCallId != _currentCallId && _currentCallId != null) {
            debugPrint(
                '⚠️ Declined call ID $eventCallId does not match current ID $_currentCallId. Ignoring.');
          } else {
            await _handleCallDecline(event.body as Map<String, dynamic>?);
          }
          break;

        case Event.actionCallEnded:
          debugPrint('📞 Call ended event for ID: $eventCallId.');
          callController.updateCallState(CallState.disconnected);
          // Stop ringtone
          await _ringtoneService.stopRingtone();

          // Handle call ended
          await _handleCallEnded(eventCallId ?? _currentCallId);
          break;

        case Event.actionCallTimeout:
          debugPrint('⏰ Call timeout event for ID: $eventCallId.');
          callController.updateCallState(CallState.missed);
          // Stop ringtone
          await _ringtoneService.stopRingtone();

          // Handle call timeout
          await _handleCallTimeout(event.body as Map<String, dynamic>?);
          break;

        case Event.actionCallCallback:
          debugPrint('📞 Callback action received. Body: ${event.body}');
          // Handle missed call callback action
          await _handleMissedCallCallback(event.body as Map<String, dynamic>?);
          break;

        default:
          debugPrint('⚠️ Unhandled call event: ${event.event}');
          break;
      }
    });
  }

  /// Handle when a user accepts a call through CallKit
  Future<void> _handleCallAccept(Map<String, dynamic>? body) async {
    if (body == null) {
      debugPrint('⚠️ Call accept body is null');
      _resetCallState();
      return;
    }

    final acceptedCallId = body['id']?.toString();
    if (acceptedCallId == null || acceptedCallId.isEmpty) {
      debugPrint('❌ Error: acceptedCallId is null or empty. Body: $body');
      _resetCallState();
      return;
    }

    // Ensure this is the call we are tracking
    if (acceptedCallId != _currentCallId) {
      debugPrint(
          '⚠️ Call accepted for $acceptedCallId but current call is $_currentCallId.');
      return;
    }

    try {
      debugPrint('📞 Processing call accept for $acceptedCallId');

      // Extract data safely
      final meetingId = acceptedCallId;
      final dynamic extraData = body['extra'];
      final Map<String, dynamic> extra = extraData is Map
          ? Map<String, dynamic>.from(
              extraData.map((k, v) => MapEntry(k.toString(), v)))
          : {};

      final bool isVideoCall = extra['isVideo'] as bool? ?? false;
      final String channelName = extra['channelName']?.toString() ?? '';
      final String token = extra['token']?.toString() ?? '';
      final String callerId =
          extra['callerId']?.toString() ?? body['handle']?.toString() ?? '';
      final String callerName =
          body['nameCaller']?.toString() ?? 'Unknown Caller';
      final String callerImage = body['avatar']?.toString() ?? '';
      final bool isInstatalk = extra['isInstatalk'] as bool? ?? false;
      final String callDuration = extra['duration']?.toString() ?? '30';

      if (meetingId.isEmpty ||
          channelName.isEmpty ||
          token.isEmpty ||
          callerId.isEmpty) {
        debugPrint('❌ Error: Missing critical call data');
        await FlutterCallkitIncoming.endCall(meetingId);
        _resetCallState();
        return;
      }

      // Create user object for the caller
      final caller = User(
        sId: callerId,
        name: callerName,
        photos: callerImage.isNotEmpty ? [callerImage] : [],
      );

      // End the call notification before navigating
      await FlutterCallkitIncoming.endCall(acceptedCallId);
      debugPrint('✅ Ended CallKit UI for accepted call $acceptedCallId');

      // Parse duration to int
      double parsedInitialTimer = double.tryParse(callDuration) ?? 30;

      // Navigate to appropriate call screen using offAll instead of to
      // This ensures we use the existing app instance
      debugPrint(
          '📱 Navigating to ${isVideoCall ? "video" : "voice"} call screen...');

      // Check if app is already running
      if (Get.context != null) {
        // App is already running - use existing instance
        if (!isInstatalk && isVideoCall) {
          Get.to(() => NormalVideoCallScreen(
                key: ValueKey(meetingId),
                meetingId: meetingId,
                channel: channelName,
                token: token,
                participant: caller,
                initialTimer: parsedInitialTimer,
                isIncomingCall: true,
              ));
        } else if (!isInstatalk && !isVideoCall) {
          Get.to(() => NormalVoiceCallScreen(
                key: ValueKey(meetingId),
                meetingId: meetingId,
                channel: channelName,
                token: token,
                participant: caller,
                // isInstatalk: isInstatalk,
                initialTimer: parsedInitialTimer,
                isIncomingCall: true,
                callerName: callerName,
                callerImage: callerImage,
              ));
        } else if (isInstatalk && !isVideoCall) {
          await Get.to(() => ITVoiceCallScreen(
                key: ValueKey(meetingId),
                meetingId: meetingId,
                channel: channelName,
                token: token,
                participant: caller,
                isIncomingCall: true,
                callerName: callerName,
                callerImage: callerImage,
              ));
        } else {
          Get.to(() => ITVideoCallScreen(
                key: ValueKey(meetingId),
                meetingId: meetingId,
                channel: channelName,
                token: token,
                participant: caller,
                isIncomingCall: true,
              ));
        }
      } else {
        // App is not running yet - need to set up Get first
        // This typically happens when launched from a terminated state
        await Future.delayed(Duration(
            milliseconds: 500)); // Small delay to ensure GetX is initialized

        if (!isInstatalk && isVideoCall) {
          Get.off(() => NormalVideoCallScreen(
                key: ValueKey(meetingId),
                meetingId: meetingId,
                channel: channelName,
                token: token,
                participant: caller,
                initialTimer: parsedInitialTimer,
                isIncomingCall: true,
              ));
        } else if (!isInstatalk && !isVideoCall) {
          Get.off(() => NormalVoiceCallScreen(
                key: ValueKey(meetingId),
                meetingId: meetingId,
                channel: channelName,
                token: token,
                participant: caller,
                // isInstatalk: isInstatalk,
                initialTimer: parsedInitialTimer,
                isIncomingCall: true,
                callerName: callerName,
                callerImage: callerImage,
              ));
        } else if (isInstatalk && !isVideoCall) {
          await Get.off(() => ITVoiceCallScreen(
                key: ValueKey(meetingId),
                meetingId: meetingId,
                channel: channelName,
                token: token,
                participant: caller,
                isIncomingCall: true,
                callerName: callerName,
                callerImage: callerImage,
              ));
        } else {
          Get.off(() => ITVideoCallScreen(
                key: ValueKey(meetingId),
                meetingId: meetingId,
                channel: channelName,
                token: token,
                participant: caller,
                // isInstatalk: isInstatalk,
                // initialTimer: parsedInitialTimer,
                isIncomingCall: true,
                // callerName: callerName,
                // callerImage: callerImage,
              ));
        }
      }

      debugPrint('✅ Navigation complete');
    } catch (e, s) {
      debugPrint('❌ Error handling call accept: $e');
      debugPrint('❌ Stack trace: $s');
    } finally {
      if (_currentCallId == acceptedCallId) {
        _resetCallState();
      }
    }
  }

  /// Handle when a user declines a call through CallKit
  Future<void> _handleCallDecline(Map<String, dynamic>? body) async {
    if (body == null) {
      debugPrint('⚠️ Call decline body is null');
      _resetCallState();
      return;
    }

    final declinedCallId = body['id']?.toString();
    if (declinedCallId == null || declinedCallId.isEmpty) {
      debugPrint('❌ Error: declinedCallId is null or empty. Body: $body');
      _resetCallState();
      return;
    }

    if (declinedCallId != _currentCallId) {
      debugPrint(
          '⚠️ Call declined for $declinedCallId but current call is $_currentCallId.');
      return;
    }

    try {
      // Stop ringtone using the new service
      await _ringtoneService.stopRingtone();

      // End the call notification first
      await FlutterCallkitIncoming.endCall(declinedCallId);
      debugPrint('✅ Ended CallKit UI for declined call: $declinedCallId');

      // Send rejection to server
      final response = await ApiService.rejectCall(declinedCallId, {
        'meetingId': declinedCallId,
        'status': 'rejected',
        'timestamp': DateTime.now().toIso8601String(),
      });

      if (response.statusCode == 200) {
        debugPrint('✅ Call rejection sent successfully');
      } else {
        debugPrint('⚠️ Error sending call rejection: ${response.statusCode}');
      }

      // Show confirmation
      Get.snackbar(
        'Call Declined',
        'You declined the incoming call',
        backgroundColor: Colors.grey[800],
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      debugPrint('❌ Error handling call decline: $e');
    } finally {
      if (_currentCallId == declinedCallId) {
        _resetCallState();
      }
    }
  }

  /// Handle when a call is ended through CallKit
  Future<void> _handleCallEnded(String? eventCallId) async {
    debugPrint(
        '📞 Handling call ended for call ID: $eventCallId. Current ID: $_currentCallId');

    final callIdToEnd = eventCallId ?? _currentCallId;
    if (callIdToEnd == null) {
      debugPrint('⚠️ No valid call ID to process');
      _resetCallState();
      return;
    }

    // Prevent duplicate handling
    if (_callsBeingEnded.contains(callIdToEnd)) {
      debugPrint(
          '📞 Already processing end for call ID $callIdToEnd. Ignoring.');
      return;
    }
    _callsBeingEnded.add(callIdToEnd);

    try {
      // Reset user's in-call status
      try {
        final response =
            await ApiService.updateMeetingStatus(callIdToEnd, 'ended');
        if (response.statusCode == 200) {
          debugPrint('✅ Call status updated to ended for $callIdToEnd');
        } else {
          debugPrint('⚠️ Failed to update call status: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('❌ Error updating call status: $e');
      }

      // Reset state if this is the current call
      if (_currentCallId == callIdToEnd) {
        _resetCallState();
      }
    } finally {
      _callsBeingEnded.remove(callIdToEnd);
    }
  }

  /// Handle when a call times out through CallKit
  Future<void> _handleCallTimeout(Map<String, dynamic>? body) async {
    final timedOutCallIdFromBody = body?['id']?.toString();
    debugPrint('⏰ Handling call timeout for call ID: $timedOutCallIdFromBody');

    final callIdToProcess = timedOutCallIdFromBody ?? _currentCallId;
    if (callIdToProcess == null) {
      debugPrint('⚠️ No valid call ID to process for timeout');
      _resetCallState();
      return;
    }

    // Prevent duplicate handling
    if (_callsBeingEnded.contains(callIdToProcess)) {
      debugPrint(
          '⏰ Already processing end for call ID $callIdToProcess. Ignoring.');
      return;
    }
    _callsBeingEnded.add(callIdToProcess);

    try {
      // End the call notification in CallKit
      await FlutterCallkitIncoming.endCall(callIdToProcess);
      debugPrint('✅ Ended CallKit UI for timed-out call: $callIdToProcess');

      // Update call status on backend to missed
      try {
        final response =
            await ApiService.updateMeetingStatus(callIdToProcess, 'missed');
        if (response.statusCode == 200) {
          debugPrint('✅ Call status updated to missed');
        } else {
          debugPrint('⚠️ Failed to update call status: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('❌ Error updating call status: $e');
      }

      // Show missed call notification
      Get.snackbar(
        'Missed Call',
        'You missed a call from ${body?['nameCaller'] ?? 'Someone'}',
        backgroundColor: Colors.grey[800],
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );

      // Reset state if needed
      if (_currentCallId == callIdToProcess) {
        _resetCallState();
      }
    } finally {
      _callsBeingEnded.remove(callIdToProcess);
    }
  }

  /// Handle when a user taps on a missed call notification
  Future<void> _handleMissedCallCallback(Map<String, dynamic>? body) async {
    if (body == null) {
      debugPrint('⚠️ Missed call callback body is null');
      return;
    }

    try {
      debugPrint('📞 Processing missed call callback with body: $body');

      // Extract data from the callback
      final callId = body['id']?.toString() ?? '';
      final extraData = body['extra'] as Map<String, dynamic>?;

      if (extraData == null) {
        debugPrint('❌ Error: extra data is null');
        return;
      }

      final callerId = extraData['callerId']?.toString() ?? '';
      final callerName = body['nameCaller']?.toString() ?? 'Unknown Caller';
      final callerImage = body['avatar']?.toString() ?? '';
      final isVideo = extraData['isVideo'] as bool? ?? false;
      final isInstatalk = extraData['isInstatalk'] as bool? ?? false;
      final timestamp = extraData['timestamp'] as int? ??
          DateTime.now().millisecondsSinceEpoch;

      if (callerId.isEmpty) {
        debugPrint('❌ Error: callerId is empty');
        return;
      }

      // Fetch caller info from API
      final response = await ApiService.getUserById(callerId);

      if (response.statusCode != 200) {
        debugPrint('❌ Error fetching caller info: ${response.statusCode}');
        return;
      }

      final userData = User.fromJson(
          (json.decode(response.body) as Map<String, dynamic>)['data']);

      // Navigate to the missed call screen
      Get.to(() => MissedCallScreen(
            caller: userData,
            timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
            isVideo: isVideo,
            isInstatalk: isInstatalk,
          ));
    } catch (e) {
      debugPrint('❌ Error handling missed call callback: $e');
    }
  }

  /// Reset the call state
  void _resetCallState() {
    debugPrint(
        '🔄 Resetting call state. CurrentCallId before reset: $_currentCallId');
    _isHandlingCall = false;
    _currentCallId = null;

    // Stop ringtone using the new service
    _ringtoneService.stopRingtone();

    // Reset the call controller state
    callController.resetCallState();

    debugPrint('✅ Call state reset complete');
  }

  /// End the current call programmatically
  Future<void> endCurrentCall({bool showMissedCallNotification = false}) async {
    if (_currentCallId != null) {
      debugPrint('📞 endCurrentCall called for: $_currentCallId');

      try {
        // If showing missed call notification is requested
        if (showMissedCallNotification) {
          // Fetch call data to include in the missed call notification
          try {
            final callData = await ApiService.getMeetingStatus(_currentCallId!);
            if (callData.statusCode == 200) {
              final data = json.decode(callData.body);
              final callerName = data['callerName'] ?? 'Missed Call';
              final callerImage = data['callerImage'] ?? '';

              // Show a missed call notification with callback option
              await FlutterCallkitIncoming.showMissCallNotification(
                CallKitParams(
                  id: _currentCallId!,
                  nameCaller: callerName,
                  handle: '',
                  type: 1,
                  duration: 0,
                  avatar: callerImage,
                  extra: <String, dynamic>{
                    'callerId': data['callerId'] ?? '',
                    'isVideo': data['type'] == 'video',
                    'isInstatalk': data['isInstatalk'] == true,
                    'timestamp': DateTime.now().millisecondsSinceEpoch,
                  },
                ),
              );

              // Update call status to missed
              await ApiService.updateMeetingStatus(_currentCallId!, 'missed');
            }
          } catch (e) {
            debugPrint('❌ Error showing missed call notification: $e');
          }
        }

        // End the call in CallKit
        await FlutterCallkitIncoming.endCall(_currentCallId!);

        // Stop ringtone
        await _ringtoneService.stopRingtone();

        // Update the call controller state
        callController.updateCallState(CallState.disconnected);
      } catch (e) {
        debugPrint('❌ Error in endCurrentCall: $e');
      } finally {
        _resetCallState();
      }
    } else {
      debugPrint('📞 endCurrentCall called, but no current call ID.');
    }
  }

  /// Clean up resources when service is disposed
  void dispose() {
    debugPrint('CallNotificationService disposing');
    _callEventSubscription?.cancel();
    _callEventSubscription = null;
    _ringtoneService.dispose();
    _resetCallState();
  }
}
