import 'dart:convert';

import 'package:get/get.dart';
import 'package:iftook/core/services/api_service.dart';
import 'package:iftook/core/services/shared_prefs.dart';
import 'package:iftook/core/widgets/webview_screen.dart';
import 'package:iftook/features/wallet/presentation/screens/wallet_screen.dart';

class WalletController extends GetxController {
  var balance = 0.0.obs;
  var transactions = <Map<String, dynamic>>[].obs;
  var isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    fetchWalletData();
  }

  Future<void> fetchWalletData() async {
    try {
      isLoading(true);
      final token = await SharedPrefs.getUserTokenSharedPreference();
      final response = await ApiService.fetchUSerWallet();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        balance.value = data['data']['balance'].toDouble();
        transactions.value =
            List<Map<String, dynamic>>.from(data['data']['transactions']);
      } else {
        throw Exception('Failed to load wallet data');
      }
    } catch (e) {
      print(e);
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
}
