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

    if (userId == null) return;

    socket = IO.io(AppConstants.BASE_URL, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'auth': {'userId': userId},
    });

    socket.connect();

    socket.onConnect((_) {
      print('✅ Socket connected');
      _isConnected = true;
      _startHeartbeat(userId);

      // Initial presence update
      socket.emit('userOnline', {'userId': userId});
    });

    socket.onDisconnect((_) {
      print('❌ Socket disconnected');
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
  }

  // Start sending periodic heartbeats to keep the "online" status active
  void _startHeartbeat(String userId) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isConnected) {
        socket.emit('heartbeat', {'userId': userId});
        print('💓 Heartbeat sent for user $userId');
      }
    });
  }

  // Check if a specific user is online (first from cache, then ask server)
  Future<bool> checkUserOnline(String userId) async {
    // First check the cache
    if (_userStatusCache.containsKey(userId)) {
      return _userStatusCache[userId] ?? false;
    }

    // Otherwise ask server
    if (!_isConnected) {
      print('Socket not connected, cannot check online status');
      return false;
    }

    try {
      // Create a completer to wait for the response
      Completer<bool> completer = Completer<bool>();

      // Request status from server with timeout
      socket.emitWithAck('checkUserStatus', {'userId': userId},
          ack: (response) {
        bool isOnline = false;

        if (response != null && response is Map) {
          isOnline = response['isOnline'] ?? false;
          _userStatusCache[userId] = isOnline; // Update cache
        }

        if (!completer.isCompleted) {
          completer.complete(isOnline);
        }
      });

      // Add a timeout
      Timer(const Duration(seconds: 3), () {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      });

      return await completer.future;
    } catch (e) {
      print('Error checking online status: $e');
      return false;
    }
  }

  // Method to emit call rejection event
  void emitCallRejected(String meetingId, String callerId) {
    if (!_isConnected) {
      print('⚠️ Socket not connected, cannot emit call rejection');
      return;
    }

    socket.emit('callRejected', {
      'meetingId': meetingId,
      'callerId': callerId,
      'timestamp': DateTime.now().toIso8601String(),
    });

    print(
        '📤 Emitted call rejection for meeting $meetingId to caller $callerId');
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _onlineStatusController.close();
    _callRejectionController.close();
    socket.disconnect();
    socket.dispose();
  }
}
