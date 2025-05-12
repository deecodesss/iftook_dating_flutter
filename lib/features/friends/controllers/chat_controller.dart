import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/core/services/api_service.dart';
import 'package:iftook/features/friends/data/chatroom.dart';
import 'package:iftook/features/friends/data/message.dart';

class ChatController extends GetxController {
  var chatRoom = Rx<Chatroom?>(null);
  var messages = <Message>[].obs;
  var isLoading = false.obs;
  var errorMessage = ''.obs;
  var userWalletBalance = 0.0.obs;
  var isTransferring = false.obs;
  var isSessionRenewed = false.obs; // Add new observable
  Timer? _pollingTimer;
  final apiService = ApiService();
  final ScrollController scrollController = ScrollController();

  // Session timer for paid chats
  Timer? _sessionTimer;
  var sessionTimeRemaining = 0.obs;
  Function? onSessionEnd;

  void startSessionTimer(int durationInMinutes, {Function? onEnd}) {
    sessionTimeRemaining.value = durationInMinutes * 60;
    onSessionEnd = onEnd;

    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (sessionTimeRemaining.value > 0) {
        sessionTimeRemaining.value--;
      } else {
        timer.cancel();
        onSessionEnd?.call();
      }
    });
  }

  void stopSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
  }

  @override
  void onClose() {
    stopSessionTimer();
    stopPolling();
    scrollController.dispose();
    super.onClose();
  }

  Future<void> openChatRoom(String userId, String participantId) async {
    try {
      isLoading(true);
      errorMessage.value = '';

      // First try to fetch existing chatroom
      chatRoom.value =
          await apiService.createOrGetChatRoom(userId, participantId);

      if (chatRoom.value == null || chatRoom.value?.sId == null) {
        // If no existing chatroom, explicitly try to create one
        chatRoom.value =
            await apiService.createOrGetChatRoom(userId, participantId);

        if (chatRoom.value == null || chatRoom.value?.sId == null) {
          throw Exception('Failed to create or get chat room');
        }
      }

      // Only proceed with fetching messages and starting polling if we have a valid chatroom
      if (chatRoom.value != null && chatRoom.value?.sId != null) {
        await fetchMessages();
        startPolling();
        await fetchWalletBalance();
      } else {
        throw Exception('Invalid chat room state');
      }
    } catch (e) {
      errorMessage.value = 'Failed to open chat room: ${e.toString()}';
      print('Error opening chat room: $e');
    } finally {
      isLoading(false);
    }
  }

  Future<void> fetchMessages() async {
    try {
      if (chatRoom.value != null) {
        final fetchedMessages =
            await apiService.getAllMsgsOfChatRoom(chatRoom.value!.sId!);
        messages.assignAll(fetchedMessages);
        // Scroll to bottom after fetching
        WidgetsBinding.instance.addPostFrameCallback((_) => scrollToBottom());
      }
    } catch (e) {
      errorMessage.value = e.toString();
    }
  }

  Future<void> sendMessage(
      String senderId, String chatRoomId, String text) async {
    if (text.trim().isEmpty) return;
    if (chatRoom.value == null || chatRoom.value?.sId == null) {
      errorMessage.value = 'No active chat room';
      return;
    }

    try {
      await apiService.sendMessage(senderId, chatRoomId, text);
      await fetchMessages();
    } catch (e) {
      errorMessage.value = 'Failed to send message: ${e.toString()}';
      print('Error sending message: $e');
    }
  }

  void startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      await fetchMessages();
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void scrollToBottom() {
    if (scrollController.hasClients && messages.isNotEmpty) {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // Add wallet functions
  Future<void> fetchWalletBalance() async {
    try {
      final response = await ApiService.fetchUSerWallet();
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        userWalletBalance.value = data['data']['balance'] != null
            ? (data['data']['balance'] as num).toDouble()
            : 0.0;
        print('Updated wallet balance: ${userWalletBalance.value}');
      }
    } catch (e) {
      print('Error fetching wallet balance: $e');
    }
  }

  Future<bool> sendMoney(String receiverId, double amount) async {
    try {
      isTransferring(true);

      // Refresh wallet balance first
      await fetchWalletBalance();

      // Check if user has enough balance
      if (userWalletBalance.value < amount) {
        Get.snackbar(
          'Insufficient Balance',
          'Please top up your wallet to send money',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
          mainButton: TextButton(
            onPressed: () => Get.toNamed('/wallet/topup'),
            child: Text('Top Up', style: TextStyle(color: Colors.white)),
          ),
        );
        return false;
      }

      // Deduct money from sender's wallet
      final deductResponse = await ApiService.deductMoneyToWallet(amount);
      if (deductResponse.statusCode != 200) {
        throw Exception('Failed to deduct money from wallet');
      }

      // Add money to receiver's wallet
      final addResponse =
          await ApiService.addMoneyToReceiverWallet(amount, receiverId);
      if (addResponse.statusCode != 200) {
        // If adding fails, we should try to revert the deduction (in a real app)
        throw Exception('Failed to transfer money to recipient');
      }

      // Update wallet balance after transaction
      await fetchWalletBalance();

      Get.snackbar(
        'Success',
        'Money sent successfully!',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      return true;
    } catch (e) {
      print('Error sending money: $e');
      Get.snackbar(
        'Error',
        'Failed to send money: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    } finally {
      isTransferring(false);
    }
  }

  Future<bool> unfriend(String userId, String friendId) async {
    try {
      final response = await ApiService.removeFriend(userId, friendId);
      if (response.statusCode == 200) {
        return true;
      } else {
        errorMessage.value = 'Failed to unfriend: ${response.body}';
        return false;
      }
    } catch (e) {
      errorMessage.value = e.toString();
      return false;
    }
  }

  // Add new method to calculate per-minute rate
  double calculatePerMinuteRate(double thirtyMinuteRate) {
    return thirtyMinuteRate /
        30; // Divides 30-minute rate by 30 to get per-minute rate
  }

  // Modify purchaseChatSession method
  Future<bool> purchaseChatSession(
    String participantId,
    double amount, {
    int minutes = 1,
    bool silent = false,
  }) async {
    try {
      isTransferring(true);

      // Deduct money from wallet
      final response = await ApiService.deductMoneyToWallet(amount);

      if (response.statusCode != 200) {
        throw Exception('Failed to deduct money from wallet: ${response.body}');
      }

      // Update wallet balance
      await fetchWalletBalance();

      if (!silent) {
        Get.snackbar(
          'Success',
          'Payment successful! Chat session extended by $minutes minute${minutes > 1 ? 's' : ''}.',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }

      return true;
    } catch (e) {
      print('Error in purchaseChatSession: $e');

      if (!silent) {
        Get.snackbar(
          'Payment Failed',
          'Could not process payment: ${e.toString()}',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
          mainButton: TextButton(
            onPressed: () => Get.toNamed('/wallet/topup'),
            child: const Text('Top Up', style: TextStyle(color: Colors.white)),
          ),
        );
      }

      return false;
    } finally {
      isTransferring(false);
    }
  }

  bool isFreeChat(double? chatRate) {
    return chatRate == null || chatRate == 0;
  }

  // Add helper method to check chatroom status
  bool get hasChatRoom => chatRoom.value != null && chatRoom.value?.sId != null;

  // Add helper method to get chatroom ID safely
  String? get currentChatRoomId => chatRoom.value?.sId;
}
