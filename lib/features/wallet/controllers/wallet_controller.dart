import 'dart:convert';

import 'package:get/get.dart';
import 'package:iftook/core/services/api_service.dart';
import 'package:iftook/core/services/shared_prefs.dart';

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

  Future<void> addMoney(double amount) async {
    try {
      isLoading(true);
      final response = await ApiService.addMoneyToWallet(amount);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        balance.value = data['balance'].toDouble(); // Update the balance
        fetchWalletData(); // Refresh the wallet data
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
}
