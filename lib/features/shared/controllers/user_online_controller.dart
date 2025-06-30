import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:iftook/core/services/socket_service.dart';
import 'package:iftook/core/services/api_service.dart';
import 'package:iftook/helpers/app_constants.dart';
import 'package:http/http.dart' as http;

/// A controller for tracking and querying user online status
///
/// This controller provides methods to:
/// - Check if a specific user is online
/// - Get notified when a user's status changes
/// - Fetch multiple users' statuses at once
class UserOnlineController extends GetxController {
  static UserOnlineController get to => Get.find<UserOnlineController>();

  final SocketService _socketService = SocketService();

  // Cache of user online status
  final RxMap<String, bool> _userStatusCache = <String, bool>{}.obs;

  // Stream subscription for status updates
  StreamSubscription? _statusSubscription;

  @override
  void onInit() {
    super.onInit();
    _initStatusListener();
  }

  @override
  void onClose() {
    _statusSubscription?.cancel();
    super.onClose();
  }

  /// Initialize the listener for online status changes
  void _initStatusListener() {
    _statusSubscription = _socketService.onlineStatusStream.listen((data) {
      if (data.containsKey('batchUpdate')) {
        // The cache was updated in bulk, just refresh the UI
        update();
      } else if (data.containsKey('userId') && data.containsKey('isOnline')) {
        final String userId = data['userId'];
        final bool isOnline = data['isOnline'];

        _userStatusCache[userId] = isOnline;
        update();
      }
    });
  }

  /// Check if a user is online
  ///
  /// First checks the local cache, then falls back to socket or API request
  /// Returns a Future with the online status
  Future<bool> isUserOnline(String userId) async {
    // Return from cache if available
    if (_userStatusCache.containsKey(userId)) {
      return _userStatusCache[userId] ?? false;
    }

    // Try socket first (real-time)
    try {
      final bool isOnline = await _socketService.checkUserOnline(userId);
      _userStatusCache[userId] = isOnline;
      return isOnline;
    } catch (e) {
      // Fall back to API
      try {
        final response = await ApiService.authenticatedRequest(() => http.get(
              Uri.parse('${AppConstants.BASE_URL}/online-status/$userId'),
              headers: {'Content-Type': 'application/json'},
            ));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final bool isOnline = data['online'] ?? false;
          _userStatusCache[userId] = isOnline;
          return isOnline;
        }
        return false;
      } catch (apiError) {
        print('Error checking online status via API: $apiError');
        return false;
      }
    }
  }

  /// Check online status for multiple users at once
  ///
  /// Returns a map of userId -> online status
  Future<Map<String, bool>> getMultipleUsersStatus(List<String> userIds) async {
    // Return cached results for all requested users if possible
    final Map<String, bool> results = {};

    // Identify which users aren't in the cache
    final List<String> uncachedUserIds = [];
    for (final userId in userIds) {
      if (_userStatusCache.containsKey(userId)) {
        results[userId] = _userStatusCache[userId] ?? false;
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
      final completer = Completer<Map<String, bool>>();

      _socketService.socket
          .emitWithAck('checkMultipleUsersStatus', {'userIds': uncachedUserIds},
              ack: (response) {
        if (response != null &&
            response is Map &&
            response['statuses'] is Map) {
          final Map<String, dynamic> statuses = response['statuses'];

          statuses.forEach((userId, isOnline) {
            results[userId] = isOnline;
            _userStatusCache[userId] = isOnline;
          });

          if (!completer.isCompleted) {
            completer.complete(results);
          }
        } else {
          if (!completer.isCompleted) {
            completer.completeError('Invalid response format');
          }
        }
      });

      // Add timeout
      Timer(const Duration(seconds: 3), () {
        if (!completer.isCompleted) {
          completer.completeError('Socket request timed out');
        }
      });

      try {
        return await completer.future;
      } catch (socketError) {
        // Fall back to API
        final response = await ApiService.authenticatedRequest(() => http.post(
              Uri.parse('${AppConstants.BASE_URL}/online-status/batch'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'userIds': uncachedUserIds}),
            ));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['statuses'] is Map) {
            final Map<String, dynamic> statuses = data['statuses'];

            statuses.forEach((userId, isOnline) {
              results[userId] = isOnline;
              _userStatusCache[userId] = isOnline;
            });
          }
        }
      }
    } catch (e) {
      print('Error fetching multiple user statuses: $e');
      // For any users that failed, assume they're offline
      for (final userId in uncachedUserIds) {
        if (!results.containsKey(userId)) {
          results[userId] = false;
        }
      }
    }

    return results;
  }

  /// Get a stream of status updates for a specific user
  ///
  /// Returns a stream that emits true when the user comes online
  /// and false when they go offline
  Stream<bool> getUserStatusStream(String userId) {
    // Create a new stream controller for this specific user
    final StreamController<bool> controller = StreamController<bool>();

    // Initialize with current status
    isUserOnline(userId).then((isOnline) {
      if (!controller.isClosed) {
        controller.add(isOnline);
      }
    });

    // Set up a listener on the main status stream
    final subscription = _socketService.onlineStatusStream.listen((data) {
      if (!controller.isClosed &&
          data.containsKey('userId') &&
          data['userId'] == userId &&
          data.containsKey('isOnline')) {
        controller.add(data['isOnline']);
      }
    });

    // Close the controller and cancel the subscription when the stream is canceled
    controller.onCancel = () {
      subscription.cancel();
      controller.close();
    };

    return controller.stream;
  }

  /// Clear the status cache for a specific user
  void clearUserStatusCache(String userId) {
    _userStatusCache.remove(userId);
  }

  /// Clear the entire status cache
  void clearAllStatusCache() {
    _userStatusCache.clear();
  }
}
