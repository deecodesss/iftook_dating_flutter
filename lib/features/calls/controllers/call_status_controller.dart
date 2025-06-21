import 'dart:async';
// import 'package.get/get.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:iftook/core/services/shared_prefs.dart';
import 'package:iftook/core/services/socket_service.dart';
import 'package:iftook/core/services/api_service.dart';

/// A controller for tracking and querying user call status
///
/// This controller provides methods to:
/// - Check if a specific user is in a call
/// - Get notified when a user's call status changes
/// - Fetch multiple users' call statuses at once
/// - Manually track when a user enters or leaves a screen that is considered a "call".
class CallStatusController extends GetxController {
  static CallStatusController get to => Get.find<CallStatusController>();

  final SocketService _socketService = SocketService();

  // Cache of user call status
  final RxMap<String, Map<String, dynamic>> _userCallStatusCache =
      <String, Map<String, dynamic>>{}.obs;

  // Stream subscription for status updates
  StreamSubscription? _callStatusSubscription;

  // --- NEW LOGIC FOR MANUAL SCREEN TRACKING ---

  /// A counter for how many "in-call" screens are currently active.
  int _inCallScreenCount = 0;

  /// Call this method from the initState() of your call-related screens.
  /// It notifies the server only when the first call screen is entered.
  void userEnteredCallScreen() async {
    _inCallScreenCount++;

    // Only send the "joined" event if this is the FIRST call screen being opened.
    if (_inCallScreenCount == 1) {
      print('--> Entered call zone. Sending "inCall: true" status.');

      // IMPORTANT: Replace with your actual user ID and meeting details
      // You should get this from your authentication or user state service.
      // const String currentUserId = 'my_user_id';
      final currentUserId =
          await SharedPrefs.getUserIdSharedPreference() ?? 'default_user_id';
      const String meetingId = 'current_meeting_id';
      const String callType = 'video'; // Or 'audio', etc.

      notifyUserJoinedCall(currentUserId, callType, meetingId);
    } else {
      print(
          'Navigating between call screens. Count is now: $_inCallScreenCount');
    }
  }

  /// Call this method from the dispose() of your call-related screens.
  /// It notifies the server only when the last call screen is closed.
  void userLeftCallScreen() async {
    _inCallScreenCount--;

    // Safety check to prevent the counter from going below zero.
    if (_inCallScreenCount < 0) {
      _inCallScreenCount = 0;
    }

    // Only send the "left" event if this was the LAST call screen being closed.
    if (_inCallScreenCount == 0) {
      print('<-- Left call zone. Sending "inCall: false" status.');

      // IMPORTANT: Replace with your actual user ID and meeting details
      final currentUserId =
          await SharedPrefs.getUserIdSharedPreference() ?? 'default_user_id';
      const String meetingId = 'current_meeting_id';

      notifyUserLeftCall(currentUserId, meetingId);
    } else {
      print(
          'Closing one call screen, but others are still active. Count is now: $_inCallScreenCount');
    }
  }

  // --- END OF NEW LOGIC ---

  @override
  void onInit() {
    super.onInit();
    _initCallStatusListener();
  }

  @override
  void onClose() {
    _callStatusSubscription?.cancel();
    super.onClose();
  }

  /// Initialize the listener for call status changes
  void _initCallStatusListener() {
    _callStatusSubscription = _socketService.callStatusStream.listen((data) {
      if (data.containsKey('batchUpdate')) {
        // The cache was updated in bulk, just refresh the UI
        update();
      } else if (data.containsKey('userId') && data.containsKey('inCall')) {
        final String userId = data['userId'];
        final bool inCall = data['inCall'];
        final String? callType = data['callType'];

        if (inCall && callType != null) {
          _userCallStatusCache[userId] = {
            'inCall': true,
            'callType': callType,
            'updatedAt': DateTime.now().toIso8601String(),
          };
        } else {
          _userCallStatusCache[userId] = {
            'inCall': false,
            'updatedAt': DateTime.now().toIso8601String(),
          };
        }

        update();
      }
    });
  }

  /// Check if a user is in a call
  ///
  /// First checks the local cache, then falls back to socket or API request
  /// Returns a Future with the call status information
  Future<Map<String, dynamic>> isUserInCall(String userId) async {
    // Return from cache if available and not expired
    if (_userCallStatusCache.containsKey(userId)) {
      final callStatus = _userCallStatusCache[userId]!;

      // Check if cache is too old (more than 30 seconds)
      final updatedAt = DateTime.parse(
          callStatus['updatedAt'] ?? DateTime.now().toIso8601String());
      final isRecent = DateTime.now().difference(updatedAt).inSeconds < 30;

      if (isRecent) {
        return callStatus;
      }
    }

    // Try socket first (real-time)
    try {
      final callStatus = await _socketService.checkUserInCall(userId);
      _userCallStatusCache[userId] = callStatus;
      return callStatus;
    } catch (e) {
      // Fall back to API
      try {
        final callStatus = await ApiService.isUserInCall(userId);

        // Add timestamp to cache
        callStatus['updatedAt'] = DateTime.now().toIso8601String();
        _userCallStatusCache[userId] = callStatus;

        return callStatus;
      } catch (apiError) {
        print('Error checking call status via API: $apiError');
        return {'inCall': false, 'updatedAt': DateTime.now().toIso8601String()};
      }
    }
  }

  /// Check call status for multiple users at once
  ///
  /// Returns a map of userId -> call status information
  Future<Map<String, Map<String, dynamic>>> getMultipleUsersCallStatus(
      List<String> userIds) async {
    // Return cached results for all requested users if possible
    final Map<String, Map<String, dynamic>> results = {};

    // Identify which users aren't in the cache or have expired cache
    final List<String> uncachedUserIds = [];
    for (final userId in userIds) {
      if (_userCallStatusCache.containsKey(userId)) {
        final callStatus = _userCallStatusCache[userId]!;

        // Check if cache is too old (more than 30 seconds)
        final updatedAt = DateTime.parse(
            callStatus['updatedAt'] ?? DateTime.now().toIso8601String());
        final isRecent = DateTime.now().difference(updatedAt).inSeconds < 30;

        if (isRecent) {
          results[userId] = _userCallStatusCache[userId]!;
        } else {
          uncachedUserIds.add(userId);
        }
      } else {
        uncachedUserIds.add(userId);
      }
    }

    // If all users were in cache, return immediately
    if (uncachedUserIds.isEmpty) {
      return results;
    }

    // Otherwise, fetch remaining users
    try {
      // Try socket method first for real-time data
      final statusMap =
          await _socketService.checkMultipleUsersCallStatus(uncachedUserIds);

      // Update results and cache
      statusMap.forEach((userId, callStatus) {
        results[userId] = callStatus;
        _userCallStatusCache[userId] = callStatus;
      });

      // For any users that weren't returned, try the API
      final List<String> remainingUserIds = [];
      for (final userId in uncachedUserIds) {
        if (!results.containsKey(userId)) {
          remainingUserIds.add(userId);
        }
      }

      if (remainingUserIds.isNotEmpty) {
        final apiResults =
            await ApiService.checkBatchCallStatus(remainingUserIds);

        // Update results and cache with API results
        apiResults.forEach((userId, callStatus) {
          // Add timestamp
          callStatus['updatedAt'] = DateTime.now().toIso8601String();

          results[userId] = callStatus;
          _userCallStatusCache[userId] = callStatus;
        });
      }
    } catch (e) {
      print('Error fetching multiple user call statuses: $e');

      // For any users that failed, assume they're not in a call
      for (final userId in uncachedUserIds) {
        if (!results.containsKey(userId)) {
          final defaultStatus = {
            'inCall': false,
            'updatedAt': DateTime.now().toIso8601String(),
          };
          results[userId] = defaultStatus;
          _userCallStatusCache[userId] = defaultStatus;
        }
      }
    }

    return results;
  }

  /// Notify the system that a user has joined a call
  void notifyUserJoinedCall(String userId, String callType, String meetingId) {
    _socketService.emitUserJoinedCall(userId, callType, meetingId);

    // Update local cache
    _userCallStatusCache[userId] = {
      'inCall': true,
      'callType': callType,
      'meetingId': meetingId,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    update();
  }

  /// Notify the system that a user has left a call
  void notifyUserLeftCall(String userId, String meetingId) {
    _socketService.emitUserLeftCall(userId, meetingId);

    // Update local cache
    _userCallStatusCache[userId] = {
      'inCall': false,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    update();
  }

  /// Get a stream of call status updates for a specific user
  ///
  /// Returns a stream that emits the call status information when changes occur
  Stream<Map<String, dynamic>> getUserCallStatusStream(String userId) {
    // Create a new stream controller for this specific user
    final StreamController<Map<String, dynamic>> controller =
        StreamController<Map<String, dynamic>>();

    // Initialize with current status
    isUserInCall(userId).then((callStatus) {
      if (!controller.isClosed) {
        controller.add(callStatus);
      }
    });

    // Set up a listener on the main status stream
    final subscription = _socketService.callStatusStream.listen((data) {
      if (!controller.isClosed &&
          data.containsKey('userId') &&
          data['userId'] == userId &&
          data.containsKey('inCall')) {
        final inCall = data['inCall'];
        final callType = data['callType'];

        final Map<String, dynamic> callStatus = {
          'inCall': inCall,
          'callType': inCall ? callType : null,
          'updatedAt': DateTime.now().toIso8601String(),
        };

        controller.add(callStatus);

        // Also update the cache
        _userCallStatusCache[userId] = callStatus;
      }
    });

    // Close the controller and cancel the subscription when the stream is canceled
    controller.onCancel = () {
      subscription.cancel();
      controller.close();
    };

    return controller.stream;
  }

  /// Clear the call status cache for a specific user
  void clearUserCallStatusCache(String userId) {
    _userCallStatusCache.remove(userId);
  }

  /// Clear the entire call status cache
  void clearAllCallStatusCache() {
    _userCallStatusCache.clear();
  }
}
