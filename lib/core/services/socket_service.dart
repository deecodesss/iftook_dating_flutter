// lib/core/services/socket_service.dart
import 'package:iftook/helpers/app_constants.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'shared_prefs.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  late IO.Socket socket;

  SocketService._internal();

  Future<void> initSocket() async {
    final userId = await SharedPrefs
        .getUserIdSharedPreference(); // or however you store it

    if (userId == null) return;

    socket = IO.io(AppConstants.BASE_URL, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'auth': {'userId': userId},
    });

    socket.connect();

    socket.onConnect((_) {
      print('✅ Socket connected');
    });

    socket.onDisconnect((_) {
      print('❌ Socket disconnected');
    });

    // Optional: Handle online status update from server
    socket.on('userStatusChanged', (data) {
      print("👤 User status changed: $data");
    });
  }

  bool isUserOnline(String userId) {
    print('Checking online status for user: $userId');
    socket.emitWithAck('isUserOnline', {'userId': userId}, ack: (response) {
      print('User $userId online: $response');
    });
    return false;
  }

  void dispose() {
    socket.dispose();
  }
}
