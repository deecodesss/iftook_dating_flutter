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
  final StreamController<Map<String, dynamic>> _onlineStatusController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _callRejectionController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Stream to listen for user status changes
  Stream<Map<String, dynamic>> get onlineStatusStream =>
      _onlineStatusController.stream;

  // Stream to listen for call rejections
  Stream<Map<String, dynamic>> get callRejectionStream =>
      _callRejectionController.stream;

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

    try {
      socket.disconnect();
      socket.dispose();
      print('🛑 Socket disposed successfully');
    } catch (e) {
      print('❌ Error disposing socket: $e');
    }
  }
}
