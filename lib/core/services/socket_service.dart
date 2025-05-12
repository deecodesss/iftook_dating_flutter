// lib/core/services/socket_service.dart
import 'dart:async';
import 'package:iftook/helpers/app_constants.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'shared_prefs.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  late IO.Socket socket;
  bool _isConnected = false;
  Timer? _heartbeatTimer;
  final Map<String, bool> _userStatusCache = {}; // Cache of user online status
  final Map<String, Map<String, dynamic>> _userCallStatusCache =
      {}; // Cache of user call status
  final StreamController<Map<String, dynamic>> _onlineStatusController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _callRejectionController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _callStatusController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Stream to listen for user status changes
  Stream<Map<String, dynamic>> get onlineStatusStream =>
      _onlineStatusController.stream;

  // Stream to listen for call rejections
  Stream<Map<String, dynamic>> get callRejectionStream =>
      _callRejectionController.stream;

  // Stream to listen for call status changes
  Stream<Map<String, dynamic>> get callStatusStream =>
      _callStatusController.stream;

  SocketService._internal();

  Future<void> initSocket() async {
    final userId = await SharedPrefs.getUserIdSharedPreference();

    if (userId == null) {
      print('❌ Cannot initialize socket: User ID is null');
      return;
    }

    print('🔌 Initializing socket connection for user: $userId');
    print('🔌 Socket URL: ${AppConstants.SOCKET_URL}');

    try {
      socket = IO.io(AppConstants.SOCKET_URL, <String, dynamic>{
        'transports': ['websocket', 'polling'],
        'autoConnect': false,
        'auth': {'userId': userId},
        'forceNew': true,
        'reconnection': true,
        'reconnectionAttempts': 5,
        'reconnectionDelay': 1000,
        'reconnectionDelayMax': 5000,
        'timeout': 20000,
      });

      // Add connection error handler
      socket.onConnectError((error) {
        print('❌ Socket connection error: $error');
      });

      socket.onError((error) {
        print('❌ Socket error: $error');
      });

      print('⏳ Attempting socket connection...');
      socket.connect();

      socket.onConnect((_) {
        print('✅ Socket connected successfully for user: $userId');
        print('✅ Socket ID: ${socket.id}');
        _isConnected = true;
        _startHeartbeat(userId);

        // Initial presence update
        socket.emit('userOnline', {'userId': userId});
        print('🟢 Emitted userOnline event for user: $userId');
      });

      socket.onReconnect((_) {
        print('🔄 Socket reconnected for user: $userId');
        _isConnected = true;
        _startHeartbeat(userId);

        // Update presence on reconnect
        socket.emit('userOnline', {'userId': userId});
      });

      socket.onReconnectAttempt((attemptNumber) {
        print('🔄 Socket reconnection attempt #$attemptNumber');
      });

      socket.onDisconnect((_) {
        print('❌ Socket disconnected for user: $userId');
        _isConnected = false;
        _heartbeatTimer?.cancel();
      });

      // Handle online status updates from server
      socket.on('userStatusChanged', (data) {
        print("👤 User status changed: $data");
        if (data != null && data['userId'] != null) {
          final userId = data['userId'];
          final isOnline = data['isOnline'] ?? false;

          // Update cache
          _userStatusCache[userId] = isOnline;

          // Broadcast to listeners
          _onlineStatusController.add({'userId': userId, 'isOnline': isOnline});
        }
      });

      // Handle bulk status updates
      socket.on('usersStatus', (data) {
        print("👥 Bulk user status update: $data");
        if (data != null && data is Map) {
          data.forEach((userId, isOnline) {
            _userStatusCache[userId] = isOnline;
          });

          // Notify listeners about the batch update
          _onlineStatusController.add({'batchUpdate': true});
        }
      });

      // Handle call status updates from server
      socket.on('userCallStatusChanged', (data) {
        print("📞 User call status changed: $data");
        if (data != null && data['userId'] != null) {
          final userId = data['userId'];
          final inCall = data['inCall'] ?? false;
          final callType = data['callType'];

          // Update cache
          if (inCall) {
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

          // Broadcast to listeners
          _callStatusController.add({
            'userId': userId,
            'inCall': inCall,
            'callType': callType,
          });
        }
      });

      // Handle call rejection event
      socket.on('callRejected', (data) async {
        print("📞 Call rejected: $data");

        // Only notify if we are the caller (not the rejector)
        if (data != null && data['meetingId'] != null) {
          final currentUserId = await SharedPrefs.getUserIdSharedPreference();
          final String callerId = data['callerId'] ?? '';

          // Only emit rejection event if current user is the caller
          if (currentUserId == callerId) {
            print("⚠️ This was YOUR call that was rejected");
            _callRejectionController.add(data);
          } else {
            print("ℹ️ You rejected this call, ignoring notification");
          }
        }
      });
    } catch (e) {
      print('❌ Error initializing socket: $e');
    }
  }

  // Start sending periodic heartbeats to keep the "online" status active
  void _startHeartbeat(String userId) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isConnected) {
        try {
          socket.emit('heartbeat', {'userId': userId});
          print('💓 Heartbeat sent for user $userId');
        } catch (e) {
          print('❌ Error sending heartbeat: $e');
        }
      }
    });
  }

  // Check if a specific user is online (first from cache, then ask server)
  Future<bool> checkUserOnline(String userId) async {
    // First check the cache
    if (_userStatusCache.containsKey(userId)) {
      final isOnline = _userStatusCache[userId] ?? false;
      print(
          '📋 Cache status for user $userId: ${isOnline ? "Online" : "Offline"}');
      return isOnline;
    }

    // Otherwise ask server
    if (!_isConnected) {
      print('❌ Socket not connected, cannot check online status');
      return false;
    }

    try {
      print('📋 Checking online status for user $userId via socket');

      // Create a completer to wait for the response
      Completer<bool> completer = Completer<bool>();

      // Request status from server with timeout
      socket.emitWithAck('checkUserStatus', {'userId': userId},
          ack: (response) {
        bool isOnline = false;

        print('📋 Received status response for user $userId: $response');

        if (response != null && response is Map) {
          isOnline = response['isOnline'] ?? false;
          _userStatusCache[userId] = isOnline; // Update cache
          print(
              '📋 Updated cache with status for user $userId: ${isOnline ? "Online" : "Offline"}');
        }

        if (!completer.isCompleted) {
          completer.complete(isOnline);
        }
      });

      // Add a timeout
      Timer(const Duration(seconds: 3), () {
        if (!completer.isCompleted) {
          print('⏱️ Timeout waiting for status of user $userId');
          completer.complete(false);
        }
      });

      final result = await completer.future;
      print(
          '📋 Final status result for user $userId: ${result ? "Online" : "Offline"}');
      return result;
    } catch (e) {
      print('❌ Error checking online status: $e');
      return false;
    }
  }

  // Check if a user is in a call (first from cache, then ask server)
  Future<Map<String, dynamic>> checkUserInCall(String userId) async {
    // First check the cache
    if (_userCallStatusCache.containsKey(userId)) {
      final callStatus = _userCallStatusCache[userId]!;

      // Check if cache is too old (more than 30 seconds)
      final updatedAt = DateTime.parse(
          callStatus['updatedAt'] ?? DateTime.now().toIso8601String());
      final isRecent = DateTime.now().difference(updatedAt).inSeconds < 30;

      if (isRecent) {
        print(
            '📋 Cache call status for user $userId: ${callStatus['inCall'] ? "In Call" : "Not in Call"}');
        return callStatus;
      }
    }

    // Otherwise ask server
    if (!_isConnected) {
      print('❌ Socket not connected, cannot check call status');
      return {'inCall': false};
    }

    try {
      print('📋 Checking call status for user $userId via socket');

      // Create a completer to wait for the response
      Completer<Map<String, dynamic>> completer =
          Completer<Map<String, dynamic>>();

      // Request status from server with timeout
      socket.emitWithAck('checkUserInCall', {'userId': userId},
          ack: (response) {
        Map<String, dynamic> callStatus = {'inCall': false};

        print('📋 Received call status response for user $userId: $response');

        if (response != null && response is Map) {
          final inCall = response['inCall'] ?? false;
          final callInfo = response['callInfo'];

          callStatus = {
            'inCall': inCall,
            'callType': callInfo != null ? callInfo['callType'] : null,
            'meetingId': callInfo != null ? callInfo['meetingId'] : null,
            'updatedAt': DateTime.now().toIso8601String(),
          };

          _userCallStatusCache[userId] = callStatus; // Update cache
          print(
              '📋 Updated cache with call status for user $userId: ${inCall ? "In Call" : "Not in Call"}');
        }

        if (!completer.isCompleted) {
          completer.complete(callStatus);
        }
      });

      // Add a timeout
      Timer(const Duration(seconds: 3), () {
        if (!completer.isCompleted) {
          print('⏱️ Timeout waiting for call status of user $userId');
          completer.complete({'inCall': false});
        }
      });

      final result = await completer.future;
      print(
          '📋 Final call status result for user $userId: ${result['inCall'] ? "In Call" : "Not in Call"}');
      return result;
    } catch (e) {
      print('❌ Error checking call status: $e');
      return {'inCall': false};
    }
  }

  // Check multiple users' call status
  Future<Map<String, Map<String, dynamic>>> checkMultipleUsersCallStatus(
      List<String> userIds) async {
    if (!_isConnected) {
      print('❌ Socket not connected, cannot check multiple call statuses');
      return {};
    }

    try {
      print('📋 Checking call status for multiple users: $userIds');

      // Create a completer to wait for the response
      Completer<Map<String, Map<String, dynamic>>> completer =
          Completer<Map<String, Map<String, dynamic>>>();

      // Request statuses from server with timeout
      socket.emitWithAck('checkMultipleUsersCallStatus', {'userIds': userIds},
          ack: (response) {
        Map<String, Map<String, dynamic>> statuses = {};

        print('📋 Received multiple call status response: $response');

        if (response != null && response is Map) {
          // Convert response to our format and update cache
          response.forEach((userId, status) {
            final inCall = status['inCall'] ?? false;
            final callInfo = status['callInfo'];

            final userStatus = {
              'inCall': inCall,
              'callType': callInfo != null ? callInfo['callType'] : null,
              'meetingId': callInfo != null ? callInfo['meetingId'] : null,
              'updatedAt': DateTime.now().toIso8601String(),
            };

            statuses[userId] = userStatus;
            _userCallStatusCache[userId] = userStatus; // Update cache
          });
        }

        if (!completer.isCompleted) {
          completer.complete(statuses);
        }
      });

      // Add a timeout
      Timer(const Duration(seconds: 5), () {
        if (!completer.isCompleted) {
          print('⏱️ Timeout waiting for multiple call statuses');
          completer.complete({});
        }
      });

      final result = await completer.future;
      print('📋 Retrieved call status for ${result.length} users');
      return result;
    } catch (e) {
      print('❌ Error checking multiple call statuses: $e');
      return {};
    }
  }

  // Method to emit user joined call event
  void emitUserJoinedCall(String userId, String callType, String meetingId) {
    if (!_isConnected) {
      print('⚠️ Socket not connected, cannot emit user joined call');
      return;
    }

    try {
      socket.emit('userJoinedCall', {
        'userId': userId,
        'callType': callType,
        'meetingId': meetingId,
      });

      print(
          '📤 Emitted userJoinedCall for user $userId in $callType call: $meetingId');
    } catch (e) {
      print('❌ Error emitting user joined call: $e');
    }
  }

  // Method to emit user left call event
  void emitUserLeftCall(String userId, String meetingId) {
    if (!_isConnected) {
      print('⚠️ Socket not connected, cannot emit user left call');
      return;
    }

    try {
      socket.emit('userLeftCall', {
        'userId': userId,
        'meetingId': meetingId,
      });

      print('📤 Emitted userLeftCall for user $userId from call: $meetingId');
    } catch (e) {
      print('❌ Error emitting user left call: $e');
    }
  }

  // Method to emit call rejection event
  void emitCallRejected(String meetingId, String callerId) {
    if (!_isConnected) {
      print('⚠️ Socket not connected, cannot emit call rejection');
      return;
    }

    try {
      socket.emit('callRejected', {
        'meetingId': meetingId,
        'callerId': callerId,
        'timestamp': DateTime.now().toIso8601String(),
      });

      print(
          '📤 Emitted call rejection for meeting $meetingId to caller $callerId');
    } catch (e) {
      print('❌ Error emitting call rejection: $e');
    }
  }

  // Get connected state
  bool get isConnected => _isConnected;

  // Get socket ID if connected
  String? get socketId => _isConnected ? socket.id : null;

  // Method to manually reconnect socket
  Future<void> reconnect() async {
    print('🔄 Attempting manual socket reconnection');
    try {
      socket.disconnect();
      socket.connect();
    } catch (e) {
      print('❌ Error during manual reconnection: $e');
      // Try reinitializing completely
      await initSocket();
    }
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _onlineStatusController.close();
    _callRejectionController.close();
    _callStatusController.close();

    try {
      socket.disconnect();
      socket.dispose();
      print('🛑 Socket disposed successfully');
    } catch (e) {
      print('❌ Error disposing socket: $e');
    }
  }
}
