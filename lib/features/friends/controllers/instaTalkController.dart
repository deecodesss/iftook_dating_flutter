import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/core/services/api_service.dart';
import 'package:iftook/core/services/shared_prefs.dart';
import 'package:iftook/features/friends/data/chatroom.dart';
import 'package:iftook/features/friends/data/message.dart';
import 'package:iftook/features/profile/data/models/user.dart';
import 'package:iftook/features/wallet/controllers/wallet_controller.dart';

class InstaTalkController extends GetxController {
  var profiles = <User>[].obs;
  var isLoading = true.obs;
  var errorMessage = ''.obs;
  var currentIndex = 0.obs;
  var userWalletBalance = 0.0.obs;
  var countries = <String>[].obs;
  var selectedCountry = 'All'.obs;
  var allProfiles = <User>[].obs;
  var wishlistUsers = <User>[].obs;
  var isWishlistLoading = false.obs;
  var isInstaTalkLoading = false.obs;
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

    scrollController.dispose();
    super.onClose();
  }

  Future<Map<String, dynamic>?> createInstaTalk(
      String participantId, String type) async {
    try {
      isInstaTalkLoading(true);

      // First check if InstaTalk was previously used
      final userId = await SharedPrefs.getUserIdSharedPreference();
      if (userId == null) {
        throw Exception('User ID is null');
      }

      // Create InstaTalk request after payment (if required)
      final response = await ApiService.createInstaTalk(participantId, type);

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print('InstaTalk created successfully: ${data['data']}');
        return data['data'];
      } else {
        final data = jsonDecode(response.body);
        errorMessage(data['message'] ?? 'Failed to create InstaTalk');
        Get.snackbar(
          'Error',
          errorMessage.value,
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
        );
        return null;
      }
    } catch (e) {
      errorMessage('An error occurred: $e');
      print('Error creating InstaTalk: $e');
      Get.snackbar(
        'Error',
        errorMessage.value,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      return null;
    } finally {
      isInstaTalkLoading(false);
    }
  }

  Future<Map<String, dynamic>?> acceptInstaTalk(String meetingId) async {
    try {
      isLoading(true);
      final userId = await SharedPrefs.getUserIdSharedPreference();

      final response = await ApiService.acceptInstaTalk(meetingId, userId!);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('InstaTalk accepted successfully: ${data['data']}');
        return data['data'];
      } else {
        final data = jsonDecode(response.body);
        errorMessage(data['message'] ?? 'Failed to accept InstaTalk');
        Get.snackbar(
          'Error',
          errorMessage.value,
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
        );
        return null;
      }
    } catch (e) {
      errorMessage('An error occurred: $e');
      Get.snackbar(
        'Error',
        errorMessage.value,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      return null;
    } finally {
      isLoading(false);
    }
  }

  Future<bool> updateInstaTalkTimeUsage({
    required String meetingId,
    required bool isUserOne, // true for sender, false for receiver
  }) async {
    try {
      final userId = await SharedPrefs.getUserIdSharedPreference();
      if (userId == null) return false;

      final response = await ApiService.updateInstaTalkTimeUsage(
        meetingId: meetingId,
        userId: userId,
        isUserOne: isUserOne,
      );

      if (response.statusCode == 200) {
        print('InstaTalk time usage updated successfully');
        return true;
      } else {
        print('Failed to update InstaTalk time usage: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error updating InstaTalk time usage: $e');
      return false;
    }
  }

  // Future<bool> createMeeting(String participantId, String type,
  //     DateTime scheduleTime, double amount) async {
  //   try {
  //     await fetchWalletBalance();

  //     if (userWalletBalance.value < amount) {
  //       _showSnackbar(
  //         'Insufficient Balance',
  //         'Please top up your wallet to schedule this meeting',
  //         isError: true,
  //         mainButton: TextButton(
  //           onPressed: () => Get.toNamed('/wallet/topup'),
  //           child: Text('Top Up', style: TextStyle(color: Colors.white)),
  //         ),
  //       );
  //       return false;
  //     }

  //     print(
  //         'Creating meeting: $participantId, $type, $scheduleTime, Amount: $amount');

  //     final response = await ApiService.createMeeting(
  //       participantId,
  //       type,
  //       scheduleTime,
  //     );

  //     if (response.statusCode == 200 || response.statusCode == 201) {
  //       print('Meeting created successfully: ${response.body}');

  //       final deductResponse = await ApiService.deductMoneyToWallet(amount);
  //       if (deductResponse.statusCode == 200) {
  //         print('Money deducted successfully');
  //         await fetchWalletBalance();
  //       } else {
  //         print('Failed to deduct money: ${deductResponse.body}');
  //       }

  //       return true;
  //     } else {
  //       throw Exception('Failed to create meeting: ${response.body}');
  //     }
  //   } catch (e) {
  //     print('Error creating meeting: $e');
  //     _showSnackbar(
  //       'Error',
  //       'Failed to create meeting: ${e.toString()}',
  //       isError: true,
  //     );
  //     return false;
  //   }
  // }

  Future<bool> processInstaTalkPayment({
    required String userId,
    required double amount,
  }) async {
    try {
      await fetchWalletBalance();

      // Safely get or create WalletController
      WalletController? walletController;
      try {
        if (!Get.isRegistered<WalletController>()) {
          Get.put(WalletController());
        }
        walletController = Get.find<WalletController>();
      } catch (e) {
        print('Error initializing WalletController: $e');
        // Fall back to using our own balance check
        if (userWalletBalance.value < amount) {
          Get.snackbar(
            'Insufficient Balance',
            'Please top up your wallet to continue',
            backgroundColor: Colors.red.withOpacity(0.8),
            colorText: Colors.white,
          );
          return false;
        }
      }

      // Check balance using WalletController if available, otherwise use our balance
      if (walletController != null &&
          !walletController.hasEnoughBalance(amount)) {
        Get.snackbar(
          'Insufficient Balance',
          'Please top up your wallet to continue',
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
        );
        return false;
      }

      // Deduct money from wallet
      final deductResponse = await ApiService.deductMoneyToWallet(amount);
      if (deductResponse.statusCode == 200) {
        print('Money deducted successfully for InstaTalk: $amount');
        await fetchWalletBalance(); // Refresh wallet balance
        return true;
      } else {
        print('Failed to deduct money: ${deductResponse.body}');
        return false;
      }
    } catch (e) {
      print('Error processing InstaTalk payment: $e');
      Get.snackbar(
        'Error',
        'Failed to process payment',
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      return false;
    }
  }

  void _showSnackbar(String title, String message,
      {bool isError = false, Widget? mainButton}) {
    if (Get.isSnackbarOpen) {
      Get.closeAllSnackbars();
    }

    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: isError ? Colors.red : Colors.green,
      colorText: Colors.white,
      duration: Duration(seconds: isError ? 4 : 2),
      margin: const EdgeInsets.all(8),
      borderRadius: 8,
      isDismissible: true,
      dismissDirection: DismissDirection.horizontal,
      forwardAnimationCurve: Curves.easeOutBack,
      mainButton: mainButton is TextButton ? mainButton : null,
      snackStyle: SnackStyle.FLOATING,
      overlayBlur: 0,
      overlayColor: Colors.black26,
    );
  }

  Future<void> fetchWalletBalance() async {
    try {
      final response = await ApiService.fetchUSerWallet();
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Wallet API Response: ${response.body}');
        userWalletBalance.value = data['data']['balance'] != null
            ? (data['data']['balance'] as num).toDouble()
            : 0.0;
        print('Updated wallet balance: ${userWalletBalance.value}');
      }
    } catch (e) {
      print('Error fetching wallet balance: $e');
    }
  }
}
