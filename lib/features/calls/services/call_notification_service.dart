import 'dart:convert';
import 'dart:async';
import 'dart:io' show Platform; // Import Platform
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:get/get.dart';
import 'package:iftook/features/calls/presentation/screens/call_screen.dart';
import 'package:iftook/features/calls/presentation/screens/laoding_voice_call_screen.dart';
import 'package:iftook/features/calls/presentation/screens/video_call_screen.dart'; // Import VideoCallScreen
import 'package:iftook/features/profile/data/models/user.dart';
import 'package:iftook/core/services/api_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart'; // Import ringer_mode_statuses

// import 'package:iftook/features/calls/presentation/screens/voice_call_loading_screen.dart';

class CallNotificationService {
  static final CallNotificationService _instance =
      CallNotificationService._internal();
  factory CallNotificationService() => _instance;
  CallNotificationService._internal();

  bool _isHandlingCall =
      false; // Tracks if the service is actively processing a new incoming call setup
  String?
      _currentCallId; // Stores the ID of the call currently being managed by CallKit UI
  StreamSubscription? _callEventSubscription;
  final Set<String> _callsBeingEnded = {}; // To prevent re-entrant call ending

  // Timer? _callTimer; // Removed manual timer, will rely on CallKit's duration/timeout

  Future<void> handleIncomingCall(RemoteMessage message) async {
    debugPrint('🔔 Incoming call data: ${message.data}');
    debugPrint('🔔 Notification title: ${message.notification?.title}');
    debugPrint('🔔 Notification body: ${message.notification?.body}');

    if (_isHandlingCall) {
      debugPrint('⚠️ Already handling a call, ignoring new call');
      return;
    }

    try {
      // Request permissions first
      await _requestPermissions();

      // Check if we are already displaying a CallKit notification for a different call
      // If _currentCallId is not null, it means a CallKit UI is active.
      // We might want to end it or decide how to handle overlapping calls.
      // For now, if _isHandlingCall is true (meaning we are in the process of showing one), we ignore.
      // If _currentCallId is set, it means a call is already displayed.
      if (_isHandlingCall &&
          _currentCallId != null &&
          _currentCallId != message.data['meetingId']) {
        debugPrint(
            '⚠️ CallKit UI is active for $_currentCallId. New call ${message.data['meetingId']} ignored or previous ended.');
        // Optionally, end the previous call before showing a new one
        // await FlutterCallkitIncoming.endCall(_currentCallId!);
        // _resetCallState(); // Reset if ending previous call
      }

      _isHandlingCall = true; // Mark that we are starting to handle/show a call
      final newCallId = message.data['meetingId']?.toString();
      if (newCallId == null || newCallId.isEmpty) {
        debugPrint(
            '❌ Error: meetingId is null or empty in incoming call data.');
        _isHandlingCall = false;
        return;
      }
      _currentCallId =
          newCallId; // Set the ID for the call we are about to show

      debugPrint('📞 Current call ID set to: $_currentCallId');

      // Extract call data
      final String callerName = message.data['callerName'] ??
          message.notification?.title?.split(' ')[0] ??
          "Unknown Caller";
      final String callType = message.data['type'] ?? 'voice';
      final bool isVideo = callType == 'video';
      final String meetingType =
          message.data['meetingType'] ?? 'regularMeeting';
      final bool isInstaTalk = message.data['isInstaTalk'] == 'true';
      final String callDuration =
          message.data['duration'] ?? message.data['callDuration'] ?? "30";
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

      // Determine sound and vibration settings based on device mode
      String? androidRingtonePath = 'system_ringtone_default';
      String? iosRingtonePath = 'system_ringtone_default';
      // bool enableVibration = true; // Default behavior

      try {
        RingerModeStatus ringerStatus = await SoundMode.ringerModeStatus;
        debugPrint('🔊 Device Ringer Status: $ringerStatus');

        if (ringerStatus == RingerModeStatus.silent) {
          debugPrint('🔊 Silent mode detected. Disabling ringtone.');
          androidRingtonePath =
              null; // Or specific silent audio file if CallKit needs one
          iosRingtonePath = null; // Or specific silent audio file
          // enableVibration = false; // Also disable vibration in silent mode
        } else if (ringerStatus == RingerModeStatus.vibrate) {
          debugPrint(
              '🔊 Vibrate mode detected. Disabling ringtone, ensuring vibration.');
          androidRingtonePath =
              null; // Sound off, vibration should be handled by system/CallKit
          iosRingtonePath = null;
          // enableVibration = true; // Ensure vibration is on
        }
        // For normal mode, defaults are fine.
      } catch (e) {
        debugPrint(
            '⚠️ Error getting ringer status: $e. Using default ringtone.');
      }

      // Create user object for the caller
      final caller = User(
        sId: callerId,
        name: callerName,
        photos: callerImage.isNotEmpty ? [callerImage] : [],
      );

      // Cancel any existing call notifications first
      await FlutterCallkitIncoming.endAllCalls();
      debugPrint('✅ Ended any existing calls');

      // Create call parameters
      final params = CallKitParams(
        id: _currentCallId!,
        nameCaller: callerName,
        appName: 'iftook',
        avatar: callerImage,
        handle: callerId, // Typically the phone number or user ID
        type: isVideo ? 1 : 0, // 0 for voice, 1 for video
        duration: int.parse(callDuration) *
            1000, // Duration in milliseconds for CallKit
        textAccept: 'Accept',
        textDecline: 'Decline',
        missedCallNotification: NotificationParams(
          showNotification: true,
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
          'callDuration': callDuration,
          'callRate': message.data['callRate'] ?? "0",
          'callerRating': message.data['callerRating'] ?? "0",
          'isInstaTalk': isInstaTalk,
          'meetingType': meetingType,
          'isVideo': isVideo, // Add isVideo to extra
        },
        headers: <String, dynamic>{
          'apiKey': 'Abc@123!',
          'platform': 'flutter',
        },
        android: AndroidParams(
          isCustomNotification: true,
          isShowLogo: true,
          ringtonePath: androidRingtonePath, // Use determined ringtone path
          backgroundColor: '#0955fa',
          actionColor: '#4CAF50',
          textColor: '#ffffff',
          incomingCallNotificationChannelName: "Incoming Call",
          missedCallNotificationChannelName: "Missed Call",
          isShowCallID: false,
          // vibrationPattern: enableVibration ? null : [], // Example: control vibration pattern
        ),
        ios: IOSParams(
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
          ringtonePath: iosRingtonePath, // Use determined ringtone path
          // configureAudioSession: true, // Ensure this is set if managing audio session properties
        ),
      );

      debugPrint('📞 Showing call notification...');
      // Setup call event listeners before showing the call
      _setupCallEventListeners();

      // Show call notification
      await FlutterCallkitIncoming.showCallkitIncoming(params);
      debugPrint('✅ Call notification shown for $_currentCallId');
      _isHandlingCall = false; // Mark that handling/showing is complete

      // Removed _startCallTimer, relying on CallKit's duration and Event.actionCallTimeout
      // _startCallTimer({'duration': callDuration, 'id': _currentCallId});
    } catch (e) {
      debugPrint('❌ Error handling incoming call: $e');
      _resetCallState(); // Reset if error occurs during setup
    }
  }

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

      // Request MANAGE_OWN_CALLS permission for Android 12+ (API 31+)
      // This is crucial for foreground services of type "phoneCall".
      // IMPORTANT: If you see an error like "The getter 'manageOwnCalls' isn't defined",
      // you MUST update the 'permission_handler' package in your pubspec.yaml
      // to version 8.0.0 or newer. After updating, run 'flutter pub get'.
      if (Platform.isAndroid) {
        // Android 13+ requires POST_NOTIFICATIONS
        if (await Permission.notification.isDenied) {
          await Permission.notification.request();
        }

        // Request MANAGE_OWN_CALLS
        // Ensure permission_handler is at least v8.0.0
        // if (Platform.isAndroid) { // This check is redundant, already inside Platform.isAndroid
        // Android 13+ (API 33) requires notification permission
        if (await Permission.notification.isDenied) {
          await Permission.notification.request();
        }

        // For keeping device awake during call
        if (await Permission.ignoreBatteryOptimizations.isDenied) {
          await Permission.ignoreBatteryOptimizations.request();
        }

        // If you show a floating call UI or overlay
        if (!await Permission.systemAlertWindow.isGranted) {
          // Be cautious with this permission. Only request if absolutely necessary
          // as it requires users to go to a special settings screen.
          // await Permission.systemAlertWindow.request();
          debugPrint(
              "SystemAlertWindow permission is not granted. Overlay features might not work.");
        }

        // The following were duplicated or misplaced, already handled above or not needed here.
        // if (await Permission.notification.isDenied) {…}
        // if (await Permission.ignoreBatteryOptimizations.isDenied) {…}
        // if (!await Permission.systemAlertWindow.isGranted) {…}
      }

      debugPrint('✅ Permissions requested successfully');
    } catch (e) {
      debugPrint('❌ Error requesting permissions: $e');
      // If the error is specifically about 'manageOwnCalls' not being defined,
      // it confirms the permission_handler version needs an update.
      if (e.toString().contains("NoSuchMethodError") &&
          e.toString().contains("manageOwnCalls")) {
        debugPrint(
            "🔴 CRITICAL: 'Permission.manageOwnCalls' is not available. Please update 'permission_handler' in pubspec.yaml to version 8.0.0 or newer.");
      }
    }
  }

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
          debugPrint(
              '📞 Incoming call event received by CallNotificationService for ID: $eventCallId.');
          // This event confirms CallKit has received the call.
          break;

        case Event.actionCallAccept:
          debugPrint(
              '✅ Call accepted by CallNotificationService for ID: $eventCallId.');
          if (eventCallId != _currentCallId && _currentCallId != null) {
            debugPrint(
                '⚠️ Accepted call ID $eventCallId does not match current active call ID $_currentCallId. Ignoring.');
            // return; // Removed return to ensure break is hit
          } else {
            await _handleCallAccept(event.body as Map<String, dynamic>?);
          }
          break;

        case Event.actionCallDecline:
          debugPrint(
              '❌ Call declined by CallNotificationService for ID: $eventCallId.');
          if (eventCallId != _currentCallId && _currentCallId != null) {
            debugPrint(
                '⚠️ Declined call ID $eventCallId does not match current active call ID $_currentCallId. Ignoring.');
            // return; // Removed return to ensure break is hit
          } else {
            await _handleCallDecline(event.body as Map<String, dynamic>?);
          }
          break;

        case Event.actionCallEnded:
          debugPrint('📞 Call ended event by CallKit for ID: $eventCallId.');
          // If eventCallId is null (e.g. empty body), _handleCallEnded will use _currentCallId.
          // We should call _handleCallEnded if there's a _currentCallId or if eventCallId is present.
          if (eventCallId == _currentCallId ||
              eventCallId == null && _currentCallId != null) {
            await _handleCallEnded(eventCallId ?? _currentCallId);
          } else if (eventCallId != null && _currentCallId == null) {
            // Event for a call that might not be tracked by _currentCallId, but CallKit ended it.
            await _handleCallEnded(eventCallId);
          } else if (eventCallId != _currentCallId) {
            debugPrint(
                '⚠️ Event.actionCallEnded for $eventCallId ignored, current call is $_currentCallId.');
          } else {
            // This case implies eventCallId is null and _currentCallId is also null.
            // Or eventCallId matches _currentCallId (which is covered by the first if)
            // Call _handleCallEnded to allow it to decide based on its internal logic (e.g. _currentCallId)
            await _handleCallEnded(eventCallId);
          }
          break;

        case Event.actionCallTimeout:
          debugPrint('⏰ Call timeout event by CallKit for ID: $eventCallId.');
          // If eventCallId is null, _handleCallTimeout will use _currentCallId.
          // We should call _handleCallTimeout if there's a _currentCallId or if eventCallId is present.
          if (eventCallId != _currentCallId &&
              _currentCallId != null &&
              eventCallId != null) {
            debugPrint(
                '⚠️ Timeout for call ID $eventCallId does not match current active call ID $_currentCallId. Ignoring.');
          } else {
            await _handleCallTimeout(event.body as Map<String, dynamic>?);
          }
          break;

        case Event.actionCallCallback:
          debugPrint(
              '📞 Callback action received by CallNotificationService. Body: ${event.body}');
          // Implement callback logic if necessary
          break;

        default:
          debugPrint(
              '⚠️ Unhandled call event in CallNotificationService: ${event.event}');
          break;
      }
    });
  }

  Future<void> _showIncomingCallUI(Map<String, dynamic>? body) async {
    if (body == null) return;

    try {
      final meetingId = body['id'];
      final callerName = body['nameCaller'];
      final callerId = body['number'];
      final callerImage = body['avatar'];
      final isVideo = body['type'] == 1;
      final duration = int.tryParse(body['duration']?.toString() ?? '30') ?? 30;

      debugPrint('📱 Showing incoming call UI for: $callerName');

      // Create user object for the caller
      final caller = User(
        sId: callerId,
        name: callerName,
        photos:
            callerImage != null && callerImage.isNotEmpty ? [callerImage] : [],
      );

      // Navigate to loading screen
      await Get.to(() => VoiceCallLoadingScreen(
            participant: caller,
            type: isVideo ? 'video' : 'voice',
            scheduleTime: DateTime.now(),
            meetingId: meetingId,
            token: body['extra']['token'],
            channel: body['extra']['channelName'],
            isInstaTalk: body['extra']['isInstaTalk'] == true,
            instaTalkDuration: duration,
          ));
    } catch (e) {
      debugPrint('❌ Error showing incoming call UI: $e');
    }
  }

  // Removed _startCallTimer method as we rely on CallKit's duration and timeout event.
  // Timer? _callTimer;

  // void _startCallTimer(Map<String, dynamic>? body) {
  //   if (body == null) return;
  //   _callTimer?.cancel();
  //   final duration = int.tryParse(body['duration']?.toString() ?? '30') ?? 30;
  //   debugPrint('⏱️ Starting manual call timer for $duration seconds (ID: ${body['id']})');
  //   _callTimer = Timer(Duration(seconds: duration), () {
  //     debugPrint('⏰ Manual call timer expired for ID: ${body['id']}');
  //     // Check if this call is still the _currentCallId before acting
  //     if (body['id'] == _currentCallId) {
  //       _handleCallTimeout(body); // Pass the original body which includes the ID
  //     } else {
  //       debugPrint('⏰ Manual timer for ${body['id']} expired, but current call is $_currentCallId. Ignoring timeout action.');
  //     }
  //   });
  // }

  Future<void> _handleCallAccept(Map<String, dynamic>? body) async {
    if (body == null) {
      debugPrint('⚠️ Call accept body is null in CallNotificationService');
      _resetCallState(); // Reset state if body is null
      return;
    }
    final acceptedCallId = body['id']?.toString();
    if (acceptedCallId == null || acceptedCallId.isEmpty) {
      debugPrint(
          '❌ Error in _handleCallAccept: acceptedCallId is null or empty. Body: $body');
      _resetCallState();
      return;
    }
    // Ensure this is the call we are tracking
    if (acceptedCallId != _currentCallId) {
      debugPrint(
          '⚠️ Call accepted for $acceptedCallId, but current call is $_currentCallId. This might be an old event.');
      // Do not reset _currentCallId here, as it pertains to the active call.
      // We just don't proceed with navigating for this old/mismatched event.
      return;
    }

    // Stop ringtone if it's playing for an incoming call
    await FlutterRingtonePlayer().stop(); // Instance method
    // await FlutterRingtonePlayer.stop(); // Consider stopping ringtone here if CallScreen doesn't handle it early enough

    try {
      debugPrint(
          '📞 Processing call accept for $acceptedCallId with body: $body');
      // Extract data safely, providing defaults or handling nulls
      // final isVideo = (body['type'] as int? ?? 0) == 1; // 'type' from body is CallKit's type (0 for voice, 1 for video)
      final meetingId = body['id']?.toString() ??
          _currentCallId ??
          ''; // Use 'id' from CallKit body, fallback to _currentCallId

      final dynamic extraData = body['extra'];
      final Map<String, dynamic> extra = extraData is Map
          ? Map<String, dynamic>.from(
              extraData.map((k, v) => MapEntry(k.toString(), v)))
          : {};

      final bool isVideoCall =
          extra['isVideo'] as bool? ?? false; // Get isVideo from extra

      final channelName = extra['channelName']?.toString() ?? '';
      final token = extra['token']?.toString() ?? '';
      final callerId = extra['callerId']?.toString() ??
          body['handle']
              ?.toString() ?? // 'handle' is often the number/ID from CallKit body
          '';
      final callerName = body['nameCaller']?.toString() ?? 'Unknown Caller';
      final callerImage = body['avatar']?.toString() ?? '';
      final isInstaTalk = extra['isInstaTalk'] as bool? ?? false;
      final callDuration = extra['callDuration']?.toString() ??
          '30'; // Default to 30 if not found

      if (meetingId.isEmpty) {
        debugPrint(
            '❌ Error in _handleCallAccept: meetingId is empty. Body: $body, Extra: $extra');
        _resetCallState();
        return;
      }
      if (channelName.isEmpty || token.isEmpty || callerId.isEmpty) {
        debugPrint(
            '❌ Error in _handleCallAccept: Missing critical call data. Channel: "$channelName", Token: "$token", CallerID: "$callerId". Body: $body, Extra: $extra');
        // Optionally, still try to end the callkit UI
        await FlutterCallkitIncoming.endCall(meetingId);
        _resetCallState();
        return;
      }

      debugPrint('📞 Call accept details:');
      debugPrint('- Meeting ID: $meetingId');
      debugPrint('- Channel: $channelName');
      debugPrint('- Token: $token');
      debugPrint('- Caller ID: $callerId');
      debugPrint('- Caller Name: $callerName');
      debugPrint('- Is Video: $isVideoCall'); // Use isVideoCall from extra
      debugPrint('- Is InstaTalk: $isInstaTalk');

      // Create user object for the caller
      final caller = User(
        sId: callerId,
        name: callerName,
        photos: callerImage.isNotEmpty
            ? [callerImage]
            : [], // Ensure photos is List<String>
      );

      // End the call notification before navigating
      // This is important, CallKit UI should be dismissed once app takes over.
      // This is where the crash was happening. Ensure permissions are granted before this.
      await FlutterCallkitIncoming.endCall(acceptedCallId);
      debugPrint('✅ Ended CallKit UI for accepted call $acceptedCallId');

      // Navigate to call screen
      debugPrint('📱 Navigating to call screen (isVideo: $isVideoCall)...');
      // Ensure all parameters passed to CallScreen are of the correct type and non-null where required.
      // For example, initialTimer expects an int.
      int parsedInitialTimer;
      try {
        parsedInitialTimer = int.parse(callDuration);
      } catch (e) {
        debugPrint(
            "Error parsing callDuration '$callDuration' to int. Defaulting to 30. Error: $e");
        parsedInitialTimer = 30;
      }

      if (isVideoCall) {
        await Get.to(() => VideoCallScreen(
              key: ValueKey(meetingId),
              meetingId: meetingId,
              channel: channelName,
              token: token,
              participant: caller,
              isInstaTalk: isInstaTalk,
              initialTimer: parsedInitialTimer,
              isIncomingCall: true,
              // Ensure all required fields for VideoCallScreen are passed
              isTrial: extra['isTrial'] as bool? ?? false,
              instaTalkDuration: parsedInitialTimer,
            ));
      } else {
        await Get.to(() => CallScreen(
              key: ValueKey(meetingId),
              meetingId: meetingId,
              channel: channelName,
              token: token,
              participant: caller,
              isInstaTalk: isInstaTalk,
              initialTimer: parsedInitialTimer,
              isIncomingCall: true,
              callerName: callerName,
              callerImage: callerImage,
            ));
      }
      debugPrint('✅ Navigation complete');
    } catch (e, s) {
      // Added stack trace for better debugging
      debugPrint('❌ Error handling call accept for $acceptedCallId: $e');
      debugPrint('❌ Stacktrace: $s'); // Print stack trace
    } finally {
      // This call (identified by acceptedCallId) is now handled (accepted and navigated to).
      // Reset _currentCallId if it matches the one we just processed.
      if (_currentCallId == acceptedCallId) {
        _resetCallState();
      }
    }
  }

  Future<void> _handleCallDecline(Map<String, dynamic>? body) async {
    if (body == null) {
      debugPrint('⚠️ Call decline body is null in CallNotificationService');
      _resetCallState();
      return;
    }
    final declinedCallId = body['id']?.toString();
    if (declinedCallId == null || declinedCallId.isEmpty) {
      debugPrint(
          '❌ Error in _handleCallDecline: declinedCallId is null or empty. Body: $body');
      _resetCallState();
      return;
    }
    // Ensure this is the call we are tracking
    if (declinedCallId != _currentCallId) {
      debugPrint(
          '⚠️ Call declined for $declinedCallId, but current call is $_currentCallId. This might be an old event.');
      return; // Don't process, don't reset state for the _currentCallId
    }

    try {
      final meetingId =
          declinedCallId; // Already confirmed it's the _currentCallId implicitly

      // End the call notification first. This might trigger an Event.actionCallEnded.
      await FlutterCallkitIncoming.endCall(meetingId);
      debugPrint('✅ Ended CallKit UI for declined call: $meetingId');

      // Send rejection to server
      final response = await ApiService.rejectCall(meetingId, {
        'meetingId': meetingId,
        'status': 'rejected',
        'timestamp': DateTime.now().toIso8601String(),
      });

      if (response.statusCode == 200) {
        debugPrint('Call rejection sent successfully');
      } else {
        debugPrint('Error sending call rejection: ${response.statusCode}');
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
      debugPrint('Error handling call decline for $declinedCallId: $e');
    } finally {
      // This call (identified by declinedCallId) is now handled (declined).
      // Reset _currentCallId if it matches the one we just processed.
      if (_currentCallId == declinedCallId) {
        _resetCallState();
      }
    }
  }

  Future<void> _handleCallEnded(String? eventCallId) async {
    debugPrint(
        '📞 Handling call ended by CallKit for call ID: $eventCallId. Current active call ID: $_currentCallId');

    // Use a local variable for the ID to process, preferring eventCallId, then _currentCallId.
    final callIdToEnd = eventCallId ?? _currentCallId;

    if (callIdToEnd == null) {
      debugPrint(
          '⚠️ _handleCallEnded: No valid call ID to process (eventCallId and _currentCallId are null). Resetting general state.');
      _resetCallState(); // Reset general state if no specific call ID.
      return;
    }

    if (_callsBeingEnded.contains(callIdToEnd)) {
      debugPrint(
          '📞 _handleCallEnded: Already processing end for call ID $callIdToEnd. Ignoring duplicate event.');
      return;
    }
    _callsBeingEnded.add(callIdToEnd);

    try {
      // Check if this event is for a call different from the current one,
      // and if _currentCallId is not null (meaning a call is actively being tracked).
      if (eventCallId != null &&
          _currentCallId != null &&
          eventCallId != _currentCallId) {
        debugPrint(
            '⚠️ _handleCallEnded: eventCallId ($eventCallId) does not match _currentCallId ($_currentCallId). This might be an old event. Ending CallKit UI for $eventCallId if active.');
        await FlutterCallkitIncoming.endCall(
            eventCallId); // End specific old call if CallKit is still showing it.
        // Do not reset _currentCallId here as it pertains to a different, potentially still active call.
        return; // Return after adding to _callsBeingEnded and handling this specific case
      }

      // Avoid re-processing if _currentCallId was already cleared by accept/decline/timeout,
      // but an event for this callIdToEnd (which might be an old _currentCallId) comes in.
      if (_currentCallId == null &&
          eventCallId != null &&
          eventCallId == callIdToEnd) {
        debugPrint(
            '📞 _handleCallEnded: _currentCallId is already null. Call $callIdToEnd likely handled by accept/decline/timeout. Ensuring CallKit UI is dismissed.');
        await FlutterCallkitIncoming.endCall(
            callIdToEnd); // Ensure UI is dismissed
        // Do not call _resetCallState here again if it was already called.
        return; // Return after adding to _callsBeingEnded and handling this specific case
      }

      // Reset user's in-call status
      try {
        final response =
            await ApiService.updateMeetingStatus(callIdToEnd, 'ended');
        if (response.statusCode == 200) {
          debugPrint('✅ Call status updated to ended for $callIdToEnd');
        } else {
          debugPrint(
              '⚠️ Failed to update call status for $callIdToEnd: ${response.statusCode} ${response.body}');
        }
      } catch (e) {
        debugPrint('❌ Error updating call status for $callIdToEnd: $e');
      }

      // This call (identified by callIdToEnd) is now considered ended.
      // Reset _currentCallId if it matches the one we just processed.
      if (_currentCallId == callIdToEnd) {
        _resetCallState();
      }
    } finally {
      _callsBeingEnded.remove(callIdToEnd);
    }
  }

  Future<void> _handleCallTimeout(Map<String, dynamic>? body) async {
    final timedOutCallIdFromBody = body?['id']?.toString();
    debugPrint(
        '⏰ Handling call timeout by CallKit for call from body: $timedOutCallIdFromBody. Current active call ID: $_currentCallId');

    // Use the specific ID from the event body, or fallback to _currentCallId if event ID is missing but a call is active.
    final callIdToProcess = timedOutCallIdFromBody ?? _currentCallId;

    if (callIdToProcess == null) {
      debugPrint(
          '⚠️ _handleCallTimeout: No valid call ID to process for timeout (event body ID and _currentCallId are null). Resetting general state.');
      _resetCallState();
      return;
    }

    if (_callsBeingEnded.contains(callIdToProcess)) {
      debugPrint(
          '⏰ _handleCallTimeout: Already processing end for call ID $callIdToProcess (due to timeout). Ignoring duplicate event.');
      return;
    }
    // Although _callsBeingEnded is primarily for actionCallEnded, a timeout also leads to ending the call.
    // So, we can use the same guard here if FlutterCallkitIncoming.endCall in timeout also triggers actionCallEnded.
    _callsBeingEnded.add(callIdToProcess);

    try {
      // Ensure this is the call we are tracking or were tracking
      if (timedOutCallIdFromBody != null &&
          _currentCallId != null &&
          timedOutCallIdFromBody != _currentCallId) {
        debugPrint(
            '⚠️ Timeout for call ID $timedOutCallIdFromBody (from event body) does not match current active call ID $_currentCallId. This might be an old event. Ending CallKit UI for $timedOutCallIdFromBody.');
        await FlutterCallkitIncoming.endCall(
            timedOutCallIdFromBody); // End specific old call
        return; // Don't process further for _currentCallId
      }

      // End the call notification in CallKit. This might trigger an Event.actionCallEnded.
      // It's important to do this for the specific timedOutCallId.
      await FlutterCallkitIncoming.endCall(callIdToProcess);
      debugPrint('✅ Ended CallKit UI for timed-out call: $callIdToProcess');

      // Reset user's in-call status on the backend
      try {
        final response = await ApiService.updateMeetingStatus(
            callIdToProcess, 'missed'); // Or 'ended', 'timed_out'
        if (response.statusCode == 200) {
          debugPrint(
              '✅ Call status updated to missed/ended for timed-out call $callIdToProcess');
        } else {
          debugPrint(
              '⚠️ Failed to update call status for timed-out call $callIdToProcess: ${response.statusCode} ${response.body}');
        }
      } catch (e) {
        debugPrint(
            '❌ Error updating call status for timed-out call $callIdToProcess: $e');
      }

      // Show a simple notification for missed call
      // This is a local Get.snackbar, not a system notification.
      // CallKit itself handles showing a "Missed Call" system notification if configured in CallKitParams.
      Get.snackbar(
        'Missed Call',
        'You missed a call from ${body?['nameCaller'] ?? 'Someone'}',
        backgroundColor: Colors.grey[800],
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );

      // This call (identified by callIdToProcess) is now handled (timed out).
      // Reset _currentCallId if it matches the one we just processed.
      if (_currentCallId == callIdToProcess) {
        _resetCallState();
      }
    } finally {
      _callsBeingEnded.remove(callIdToProcess);
    }
  }

  void _resetCallState() {
    debugPrint(
        '🔄 Resetting call state in CallNotificationService. CurrentCallId before reset: $_currentCallId');
    _isHandlingCall = false; // Ready to handle a new call setup
    _currentCallId = null; // No CallKit UI is considered active by this service
    // _callEventSubscription?.cancel(); // Do not cancel the global listener here. It should always be active.
    // _callEventSubscription = null;
    // _callTimer?.cancel(); // Manual timer removed
    // _callTimer = null;
    debugPrint(
        '✅ Call state reset complete. CurrentCallId after reset: $_currentCallId');
  }

  Future<void> endCurrentCall() async {
    // This might be called externally to end the active call
    if (_currentCallId != null) {
      debugPrint('📞 endCurrentCall called for: $_currentCallId');
      await FlutterCallkitIncoming.endCall(
          _currentCallId!); // This will trigger Event.actionCallEnded
      // The _handleCallEnded listener will then call _resetCallState.
      // So, no need to call _resetCallState() directly here.
    } else {
      debugPrint('📞 endCurrentCall called, but no _currentCallId to end.');
    }
  }

  void dispose() {
    debugPrint(
        'CallNotificationService disposing. Cancelling event subscription.');
    _callEventSubscription?.cancel();
    _callEventSubscription = null;
    // _callTimer?.cancel(); // Manual timer removed
    _resetCallState(); // Ensure state is clean on dispose
  }
}
