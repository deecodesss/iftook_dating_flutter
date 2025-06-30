import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:iftook/core/services/shared_prefs.dart';
import 'package:iftook/features/profile/controllers/profile_controller.dart';
import 'package:iftook/helpers/app_colors.dart';
import 'package:iftook/helpers/constant.dart';

class LiveChatMessage {
  final String userId;
  final String userName;
  final String message;
  final DateTime timestamp;

  LiveChatMessage({
    required this.userId,
    required this.userName,
    required this.message,
    required this.timestamp,
  });
}

class LiveChatWidget extends StatefulWidget {
  final String liveStreamId;

  const LiveChatWidget({
    Key? key,
    required this.liveStreamId,
  }) : super(key: key);

  @override
  State<LiveChatWidget> createState() => _LiveChatWidgetState();
}

class _LiveChatWidgetState extends State<LiveChatWidget> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<LiveChatMessage> _messages = [];
  late IO.Socket _socket;
  String? _userId;
  String? _userName;
  bool _isConnected = false;
  bool _isInitialized = false;
  bool _isConnecting = true; // Add this to track connection attempts

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      final userId = await SharedPrefs.getUserIdSharedPreference();
      final userName = Get.find<ProfileController>().user.value.name ?? 'User';

      setState(() {
        _userId = userId;
        _userName = userName;
        _isConnecting = true;
      });

      print('Connecting to Socket.io server at: ${Constants.socketUrl}');

      // Initialize socket connection with proper configuration and reconnection
      _socket = IO.io(
        Constants.socketUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .setAuth({'userId': userId})
            .enableForceNew()
            .setTimeout(10000) // 10 second timeout
            .setReconnectionAttempts(5)
            .setReconnectionDelay(3000)
            .build(),
      );

      // Set up event handlers
      _setupSocketEventHandlers();

      // Connect to socket server
      _socket.connect();

      // Add timeout for connection
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted && !_isConnected) {
          setState(() {
            _isConnecting = false;
            // Add a system message about connection failure
            _messages.add(LiveChatMessage(
              userId: 'system',
              userName: 'System',
              message:
                  'Could not connect to chat service. Check your connection.',
              timestamp: DateTime.now(),
            ));
          });
        }
      });

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('Error initializing chat: $e');
      setState(() {
        _isConnecting = false;
      });
    }
  }

  void _setupSocketEventHandlers() {
    // Connection events
    _socket.onConnect((_) {
      print('Connected to socket.io server');
      setState(() {
        _isConnected = true;
        _isConnecting = false;

        // Add connection success system message
        _messages.add(LiveChatMessage(
          userId: 'system',
          userName: 'System',
          message: 'Connected to chat service.',
          timestamp: DateTime.now(),
        ));
      });

      // Join the live stream room
      _socket.emit('joinLiveStream', {
        'liveStreamId': widget.liveStreamId,
        'userName': _userName,
      });
    });

    _socket.onDisconnect((_) {
      print('Disconnected from socket.io server');
      setState(() => _isConnected = false);
    });

    _socket.onConnectError((error) {
      print('Socket connection error: $error');
      setState(() => _isConnected = false);
    });

    _socket.onError((error) {
      print('Socket error: $error');
    });

    // Add reconnect events
    _socket.onReconnect((_) {
      print('Reconnected to socket.io server');
      setState(() {
        _isConnected = true;
        _isConnecting = false;

        // Add reconnection message
        _messages.add(LiveChatMessage(
          userId: 'system',
          userName: 'System',
          message: 'Reconnected to chat service.',
          timestamp: DateTime.now(),
        ));
      });

      // Rejoin room after reconnection
      _socket.emit('joinLiveStream', {
        'liveStreamId': widget.liveStreamId,
        'userName': _userName,
      });
    });

    _socket.onReconnectAttempt((data) {
      print('Attempting to reconnect: $data');
      setState(() {
        _isConnecting = true;
      });
    });

    // Message events
    _socket.on('newLiveStreamMessage', (data) {
      print('Received message: $data');
      if (mounted) {
        setState(() {
          _messages.add(LiveChatMessage(
            userId: data['userId'] ?? '',
            userName: data['userName'] ?? 'User',
            message: data['message'] ?? '',
            timestamp: DateTime.now(),
          ));
        });

        // Scroll to bottom
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });

    // User activity events
    _socket.on('viewerJoined', (data) {
      print('Viewer joined: $data');
      if (mounted) {
        setState(() {
          _messages.add(LiveChatMessage(
            userId: data['userId'] ?? '',
            userName: data['userName'] ?? 'User',
            message: 'joined the live stream',
            timestamp: DateTime.now(),
          ));
        });
      }
    });

    _socket.on('viewerLeft', (data) {
      print('Viewer left: $data');
      if (mounted) {
        setState(() {
          _messages.add(LiveChatMessage(
            userId: data['userId'] ?? '',
            userName: data['userName'] ?? 'User',
            message: 'left the live stream',
            timestamp: DateTime.now(),
          ));
        });
      }
    });
  }

  void _sendMessage() {
    if (_messageController.text.isEmpty || !_isConnected) return;

    final message = _messageController.text.trim();
    _messageController.clear();

    // Send message through socket
    _socket.emit('liveStreamMessage', {
      'liveStreamId': widget.liveStreamId,
      'message': message,
      'userName': _userName,
    });

    // Add message locally to show immediately
    setState(() {
      _messages.add(LiveChatMessage(
        userId: _userId ?? '',
        userName: 'You',
        message: message,
        timestamp: DateTime.now(),
      ));
    });

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();

    if (_isInitialized) {
      // Leave live stream room
      _socket.emit('leaveLiveStream', {
        'liveStreamId': widget.liveStreamId,
      });

      // Disconnect socket
      _socket.disconnect();
      _socket.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Connection status indicator - improved version
        if (_isConnecting)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Connecting to chat service...',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          )
        else if (!_isConnected && _isInitialized)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                const Text(
                  'Chat disconnected.',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isConnecting = true;
                    });
                    _socket.connect();
                  },
                  child: const Text(
                    'Reconnect',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Chat messages
        Container(
          height: 200,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.bottomLeft,
          child: ListView.builder(
            controller: _scrollController,
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              final isCurrentUser = message.userId == _userId;
              final isSystemMessage =
                  message.message == 'joined the live stream' ||
                      message.message == 'left the live stream';

              if (isSystemMessage) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${message.userName} ${message.message}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.8,
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isCurrentUser
                            ? AppColors.primaryColor.withOpacity(0.2)
                            : Colors.black54,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isCurrentUser ? 'You' : message.userName,
                            style: TextStyle(
                              color: isCurrentUser
                                  ? AppColors.primaryColor
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message.message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Chat input
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(24),
          ),
          margin: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Send a message...',
                    hintStyle: TextStyle(color: Colors.white54),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  cursorColor: AppColors.primaryColor,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(),
                  enabled: _isConnected,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.send,
                  color: AppColors.primaryColor,
                ),
                onPressed: _isConnected ? _sendMessage : null,
                disabledColor: Colors.grey,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
