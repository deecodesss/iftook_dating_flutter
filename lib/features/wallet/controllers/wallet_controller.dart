import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/core/services/api_service.dart';
import 'package:iftook/core/services/shared_prefs.dart';
import 'package:iftook/core/widgets/webview_screen.dart';
import 'package:iftook/helpers/app_constants.dart';
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
        final payPageUrl = data['payPageUrl'];
        final merchantReferenceId = data['merchantReferenceId'];

        if (payPageUrl != null) {
          isLoading(false); // Stop loading before pushing WebView
          
          // Construct success and failure URLs based on your backend configuration
          final String successUrlPrefix = '${AppConstants.BASE_URL}/api/payments/redirect/success';
          final String failureUrlPrefix = '${AppConstants.BASE_URL}/api/payments/redirect/failure';
          
          // Open WebView with the payment URL
          final result = await Get.to<Map<String, String>>(
            () => WebviewScreen(
              initialUrl: payPageUrl,
              successUrlPrefix: successUrlPrefix, 
              failureUrlPrefix: failureUrlPrefix,
            ),
          );
          
          // Handle the result from WebView
          if (result != null) {
            final status = result['status'];
            final returnedMerchantReferenceId = result['merchantReferenceId'];
            
            if (status == 'success' && returnedMerchantReferenceId == merchantReferenceId) {
              // Verify payment status with backend
              await verifyPaymentStatus(merchantReferenceId);
            } else if (status == 'failure') {
              Get.snackbar(
                'Payment Failed',
                'Your payment was not successful. Please try again.',
                backgroundColor: Colors.red,
                colorText: Colors.white,
              );
            } else {
              Get.snackbar(
                'Payment Status Unknown',
                'Please check your wallet for updated balance.',
                backgroundColor: Colors.orange,
                colorText: Colors.white,
              );
            }
            
            // Refresh wallet data regardless of status
            await fetchWalletData();
          } else {
            // User canceled the payment
            Get.snackbar(
              'Payment Canceled',
              'You canceled the payment process.',
              backgroundColor: Colors.grey,
              colorText: Colors.white,
            );
          }
        } else {
          throw Exception('Payment URL not provided');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to initiate payment');
      }
    } catch (e) {
      print('Error in payment process: $e');
      Get.snackbar(
        'Error', 
        'Failed to make payment: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading(false);
    }
  }
  
  // Add this new method to verify payment status
  Future<void> verifyPaymentStatus(String merchantReferenceId) async {
    try {
      isLoading(true);
      
      // Create a verification endpoint in your API service or use:
      final response = await ApiService.verifyPayment(merchantReferenceId);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['paymentStatus'] == 'completed') {
          Get.snackbar(
            'Payment Successful',
            'Your payment was successful and your wallet has been updated.',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
          
          // Refresh wallet data to show updated balance
          await fetchWalletData();
        } else {
          Get.snackbar(
            'Payment Status',
            'Payment status: ${data['paymentStatus']}. Your wallet will be updated when the payment is confirmed.',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
          );
        }
      } else {
        throw Exception('Failed to verify payment status');
      }
    } catch (e) {
      print('Error verifying payment: $e');
      Get.snackbar(
        'Verification Error',
        'Could not verify payment status: ${e.toString()}',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
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
