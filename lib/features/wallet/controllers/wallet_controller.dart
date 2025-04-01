import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/core/services/api_service.dart';
import 'package:iftook/core/services/shared_prefs.dart';
import 'package:iftook/core/widgets/webview_screen.dart';
import 'package:iftook/features/wallet/presentation/screens/wallet_screen.dart';
import 'dart:async';

class WalletController extends GetxController {
  var balance = 0.0.obs;
  var transactions = <Map<String, dynamic>>[].obs;
  var isLoading = true.obs;
  var errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchWalletData();
  }

  Future<void> fetchWalletData() async {
    try {
      isLoading(true);
      errorMessage('');
      final response = await ApiService.fetchUSerWallet();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Wallet data response: ${response.body}');

        // Update to match the actual API response structure
        balance.value = data['data']['balance'] != null
            ? (data['data']['balance'] as num).toDouble()
            : 0.0;

        if (data['data']['transactions'] != null) {
          transactions.value =
              List<Map<String, dynamic>>.from(data['data']['transactions']);
        }

        print('Updated balance: ${balance.value}');
        print('Transactions count: ${transactions.length}');
      } else {
        final data = jsonDecode(response.body);
        errorMessage(data['message'] ?? 'Failed to fetch wallet balance');
        throw Exception('Failed to load wallet data');
      }
    } catch (e) {
      errorMessage('An error occurred: $e');
      print('Error in fetchWalletData: $e');
    } finally {
      isLoading(false);
    }
  }

  Future<void> addMoney(double amount, String paymentId) async {
    try {
      isLoading(true);
      final response = await ApiService.addMoneyToWallet(amount, paymentId);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        balance.value = data['balance'].toDouble(); // Update the balance
        fetchWalletData(); // Refresh the wallet data
        Get.off(() => WalletScreen());
      } else {
        throw Exception('Failed to add money');
      }
    } catch (e) {
      print(e);
      Get.snackbar('Error', 'Failed to add money: $e');
    } finally {
      isLoading(false);
    }
  }

  Future<void> makePayment(double amount) async {
    try {
      isLoading(true);
      final response = await ApiService.makePayment(amount);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        Get.to(() => WebViewScreen(
              url: data['payPageUrl'],
              title: "Wallet Top Up",
              amount: amount,
            ));
      } else {
        throw Exception('Failed to make payment');
      }
    } catch (e) {
      print(e);
      Get.snackbar('Error', 'Failed to make payment: $e');
    } finally {
      isLoading(false);
    }
  }

  Future<void> transferToBank(Map<String, dynamic> bankDetails) async {
    try {
      isLoading.value = true;

      final response = await ApiService.transferToBank(bankDetails);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        String orderId = data['data']['dataContent']['OrderId'];

        // Start checking transfer status
        Timer.periodic(const Duration(seconds: 30), (timer) async {
          final statusResponse = await ApiService.checkTransferStatus(orderId);
          final statusData = jsonDecode(statusResponse.body);

          if (statusData['data']['dataContent'][0]['Status'] != 'PENDING') {
            timer.cancel();
            if (statusData['data']['dataContent'][0]['Status'] == 'SUCCESS') {
              await fetchWalletData();
              Get.snackbar(
                'Success',
                'Money transferred successfully!',
                backgroundColor: Colors.green,
                colorText: Colors.white,
              );
            }
          }
        });
      } else {
        throw Exception(data['message']);
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Transfer failed: ${e.toString()}',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> sendTip(String receiverId, double amount) async {
    try {
      isLoading(true);
      errorMessage('');

      // Check if user has enough balance
      if (balance.value < amount) {
        errorMessage('Insufficient wallet balance');
        Get.snackbar(
          'Error',
          'Insufficient wallet balance. Please add funds to your wallet.',
          backgroundColor: Colors.redAccent,
          colorText: Colors.white,
        );
        return false;
      }

      // First deduct from user's wallet
      final deductResponse = await ApiService.deductMoneyToWallet(amount);

      if (deductResponse.statusCode != 200) {
        throw Exception('Failed to deduct from wallet');
      }

      // Then add to receiver's wallet
      final addResponse =
          await ApiService.addMoneyToReceiverWallet(amount, receiverId);

      if (addResponse.statusCode != 200) {
        // If adding to receiver fails, we should refund the user
        // This would require a refund API endpoint
        throw Exception('Failed to add to receiver wallet');
      }

      // Update local balance
      balance.value -= amount;

      Get.snackbar(
        'Success',
        'Tip sent successfully!',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      return true;
    } catch (e) {
      errorMessage('An error occurred: $e');
      Get.snackbar(
        'Error',
        'Failed to send tip: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    } finally {
      isLoading(false);
    }
  }

  bool hasEnoughBalance(double amount) {
    return balance.value >= amount;
  }
}
