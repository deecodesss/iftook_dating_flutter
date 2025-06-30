import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:get/get.dart';
import 'package:iftook/core/services/shared_prefs.dart';
import 'package:iftook/features/profile/controllers/profile_controller.dart';
import 'package:iftook/helpers/app_colors.dart';

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

class AgoraLiveChatWidget extends StatefulWidget {
  final String liveStreamId;
  final String channelName;
  final RtcEngine? engine; // Use the existing RTC engine if available

  const AgoraLiveChatWidget({
    Key? key,
    required this.liveStreamId,
    required this.channelName,
    this.engine,
  }) : super(key: key);

  @override
  State<AgoraLiveChatWidget> createState() => _AgoraLiveChatWidgetState();
}

class _AgoraLiveChatWidgetState extends State<AgoraLiveChatWidget> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<LiveChatMessage> _messages = [];

  RtcEngine? _engine;
  String? _userId;
  String? _userName;
  bool _isConnected = false;
  bool _isConnecting = true;
  int? _dataStreamId; // Store the data stream ID

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      setState(() => _isConnecting = true);

      // Get user details
      final userId = await SharedPrefs.getUserIdSharedPreference();
      final userName = Get.find<ProfileController>().user.value.name ?? 'User';

      setState(() {
        _userId = userId;
        _userName = userName;
      });

      // Use the provided engine if available
      _engine = widget.engine;
      if (_engine != null) {
        // Create a data stream for chat messages
        try {
          final result = await _engine!.createDataStream(const DataStreamConfig(
            ordered: true,
            syncWithAudio: false,
          ));

          // Store the data stream ID
          _dataStreamId = result;
          print('Successfully created data stream ID: $_dataStreamId');

          // Setup event handlers
          _setupEventHandlers();

          setState(() {
            _isConnected = true;
            _isConnecting = false;
            _messages.add(LiveChatMessage(
              userId: 'system',
              userName: 'System',
              message: 'Connected to chat service.',
              timestamp: DateTime.now(),
            ));
          });
        } catch (e) {
          print('Error creating data stream: $e');
          setState(() {
            _isConnected = false;
            _isConnecting = false;
            _messages.add(LiveChatMessage(
              userId: 'system',
              userName: 'System',
              message: 'Failed to initialize chat: $e',
              timestamp: DateTime.now(),
            ));
          });
        }
      } else {
        setState(() {
          _isConnecting = false;
          _messages.add(LiveChatMessage(
            userId: 'system',
            userName: 'System',
            message: 'Chat service not available. Using video only.',
            timestamp: DateTime.now(),
          ));
        });
      }
    } catch (e) {
      print('Error initializing Agora chat: $e');
      setState(() {
        _isConnecting = false;
        _isConnected = false;
        _messages.add(LiveChatMessage(
          userId: 'system',
          userName: 'System',
          message: 'Failed to connect to chat: $e',
          timestamp: DateTime.now(),
        ));
      });
    }
  }

  void _setupEventHandlers() {
    if (_engine == null) return;

    // Set up data stream event handler
    _engine!.registerEventHandler(RtcEngineEventHandler(
      onStreamMessage: (connection, remoteUid, streamId, data, length, sentTs) {
        try {
          print('Received message on stream $streamId with length $length');
          final String rawMessage = String.fromCharCodes(data);
          print('Raw message received: $rawMessage');

          final Map<String, dynamic> parsedMessage = jsonDecode(rawMessage);

          setState(() {
            _messages.add(LiveChatMessage(
              userId: parsedMessage['userId'] ?? 'unknown',
              userName: parsedMessage['userName'] ?? 'User',
              message: parsedMessage['message'] ?? '',
              timestamp: DateTime.now(),
            ));
          });

          _scrollToBottom();
        } catch (e) {
          print('Error processing message: $e');
        }
      },
      onUserJoined: (connection, uid, elapsed) {
        setState(() {
          _messages.add(LiveChatMessage(
            userId: uid.toString(),
            userName: 'User $uid',
            message: 'joined the live stream',
            timestamp: DateTime.now(),
          ));
        });
        _scrollToBottom();
      },
      onUserOffline: (connection, uid, reason) {
        setState(() {
          _messages.add(LiveChatMessage(
            userId: uid.toString(),
            userName: 'User $uid',
            message: 'left the live stream',
            timestamp: DateTime.now(),
          ));
        });
        _scrollToBottom();
      },
    ));
  }

  void _scrollToBottom() {
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

  void _sendMessage() async {
    if (_messageController.text.isEmpty ||
        !_isConnected ||
        _engine == null ||
        _dataStreamId == null) {
      // Show error message if data stream is not ready
      if (_isConnected && _engine != null && _dataStreamId == null) {
        Get.snackbar(
          'Chat Error',
          'Chat service not fully initialized. Please try again later.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
      return;
    }

    final message = _messageController.text.trim();
    _messageController.clear();

    try {
      // Format the message as JSON
      final messageData = {
        'userId': _userId,
        'userName': _userName,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final jsonMessage = jsonEncode(messageData);
      final messageBytes = Uint8List.fromList(jsonMessage.codeUnits);

      print('Sending message on stream $_dataStreamId: $jsonMessage');
      print('Message length: ${messageBytes.length}');

      // Send via data stream using the stored stream ID
      await _engine!.sendStreamMessage(
        streamId: _dataStreamId!,
        data: messageBytes,
        length: messageBytes.length, // Use actual length
      );

      print('Message sent successfully');

      // Add message locally to show immediately
      setState(() {
        _messages.add(LiveChatMessage(
          userId: _userId ?? '',
          userName: 'You',
          message: message,
          timestamp: DateTime.now(),
        ));
      });

      _scrollToBottom();
    } catch (e) {
      print('Error sending message: $e');
      Get.snackbar(
        'Error',
        'Failed to send message: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Connection status indicator
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
              final isSystemMessage = message.userId == 'system' ||
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
