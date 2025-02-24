import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/features/friends/data/chatroom.dart';

import '../../../core/services/api_service.dart';
import '../data/message.dart';

class ChatController extends GetxController {
  final ApiService _apiService = ApiService();

  var chatRoom = Rxn<Chatroom>();
  var messages = <Message>[].obs;
  var isLoading = false.obs;
  Timer? _pollingTimer;

  final ScrollController scrollController = ScrollController();

  // Open the chat room and start polling for messages
  Future<void> openChatRoom(String userId, String participantId) async {
    isLoading(true);
    try {
      // Call the API to get or create the chat room
      final chatRoomResponse =
          await _apiService.createOrGetChatRoom(userId, participantId);
      // chatRoom(chatRoomResponse);
      chatRoom.value = chatRoomResponse;

      // Fetch initial messages
      await _fetchMessages(chatRoomResponse.sId.toString());

      // Start polling for new messages every 2 seconds
      _startPolling(chatRoomResponse.sId.toString());

      isLoading(false);
    } catch (e) {
      isLoading(false);
      // Get.snackbar('Error', 'Failed to open chat room: $e');
    }
  }

  scrollToBottom() {
    // if (scrollController.hasClients) {
    scrollController.animateTo(
      scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
    );
    // }
  }

  // Fetch messages from the API
  Future<void> _fetchMessages(String chatRoomId) async {
    try {
      final messagesResponse =
          await _apiService.getAllMsgsOfChatRoom(chatRoomId);

      messages.assignAll(messagesResponse);
      messages.listen((_) => scrollToBottom());
    } catch (e) {
      // Get.snackbar('Error', 'Failed to fetch messages: $e');
    }
  }

  // Start polling for new messages
  void _startPolling(String chatRoomId) {
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      await _fetchMessages(chatRoomId);
    });
  }

  // Stop polling when the chat room is closed
  void stopPolling() {
    _pollingTimer?.cancel();
  }

  // Send a message
  Future<void> sendMessage(
      String senderId, String chatRoomId, String text) async {
    try {
      // Create a local message immediately for a seamless experience
      final localMessage = Message(
        sId: 'local-${DateTime.now().millisecondsSinceEpoch}',
        chatRoomId: chatRoomId,
        senderId: SenderId(),
        text: text,
        createdAt: DateTime.now().toIso8601String(),
      );
      localMessage.senderId?.sId = senderId;
      messages.insert(messages.length, localMessage);

      // Call the API to send the message
      await _apiService.sendMessage(senderId, chatRoomId, text);
      // await _fetchMessages(chatRoomId);

      // Optionally, you can refresh the messages from the server
      scrollToBottom();
    } catch (e) {
      Get.snackbar('Error', 'Failed to send message: $e');
    }
  }

  @override
  void onClose() {
    stopPolling(); // Stop polling when the controller is closed
    scrollController.dispose();
    super.onClose();
  }
}
