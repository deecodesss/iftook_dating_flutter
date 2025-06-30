import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:iftook/helpers/app_colors.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

import '../../../../core/services/api_service.dart';
import '../../../../features/profile/data/models/user.dart';
import '../../../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../controllers/wallet_controller.dart';
import 'add_money_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final WalletController walletController = Get.put(WalletController());

  String convertToIST(String utcDate) {
    DateTime utcDateTime = DateTime.parse(utcDate).toUtc();
    DateTime istDateTime =
        utcDateTime.add(const Duration(hours: 5, minutes: 30));
    return DateFormat('dd MMM yyyy, hh:mm a').format(istDateTime);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Ensure walletController.fetchTransactions() is called, e.g., in its onInit or here if needed.
    // walletController.fetchTransactions(); // Or handled by controller's lifecycle
  }

  Map<String, dynamic> _getTransactionDisplayDetails(
      Map<String, dynamic> transaction) {
    String paymentType = transaction['paymentType'] ?? 'unknown';
    double amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
    String transactionId = transaction['_id'] ?? 'N/A';

    bool isCredit;
    IconData iconData;
    Color statusColor;
    String title;
    String formattedAmount;
    String baseTitle;

    switch (paymentType.toLowerCase()) {
      case 'earning':
        isCredit = true;
        baseTitle = 'Earning';
        break;
      case 'refund':
        isCredit = true;
        baseTitle = 'Refund Received';
        break;
      case 'wallet_deposit':
        isCredit = true;
        baseTitle = 'Added to Wallet';
        break;
      case 'withdrawal':
        isCredit = false;
        baseTitle = 'Bank Transfer';
        break;
      case 'wallet_payment':
        isCredit = false;
        baseTitle = 'Service Payment';
        break;
      default:
        isCredit = true; // Default for unknown types, or handle as error
        baseTitle =
            GetUtils.capitalizeFirst(paymentType.replaceAll('_', ' ')) ??
                'Transaction';
        // Log unknown paymentType if necessary
        debugPrint("Unknown payment type: $paymentType");
        break;
    }

    if (isCredit) {
      iconData = HugeIcons.strokeRoundedSquareArrowDownLeft;
      statusColor = AppColors.greenColor;
      formattedAmount = '+₹${amount.toStringAsFixed(2)}';
    } else {
      iconData = HugeIcons.strokeRoundedSquareArrowUpRight;
      statusColor = AppColors.redColor;
      formattedAmount = '-₹${amount.toStringAsFixed(2)}';
    }

    title = baseTitle;
    String subtitle = 'ID: $transactionId';

    return {
      'icon': iconData,
      'color': statusColor,
      'title': title,
      'subtitle': subtitle,
      'amount': formattedAmount,
      'date': convertToIST(
          transaction['paymentDate'] ?? DateTime.now().toIso8601String()),
    };
  }

  Future<bool> _validateBankTransfer() async {
    try {
      // Show loading dialog
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      // Fetch user profile to check bank details and PAN
      final response = await ApiService.fetchMyProfile();

      // Remove loading dialog
      Get.back();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = User.fromJson(data['user']);

        // Check if bank details exist
        if (user.bankDetails == null ||
            user.bankDetails!.accountNumber == null ||
            user.bankDetails!.accountNumber!.isEmpty) {
          Get.snackbar(
            'Missing Bank Details',
            'Please add your bank account details in your profile before transferring money',
            backgroundColor: Colors.amber[700],
            colorText: Colors.white,
            duration: const Duration(seconds: 4),
          );
          return false;
        }

        // Check if PAN/Government ID details exist
        if (user.panDetails == null ||
            user.panDetails!.panNumber == null ||
            user.panDetails!.panNumber!.isEmpty) {
          Get.snackbar(
            'Verification Required',
            'Please add your PAN/Government ID details in your profile for verification',
            backgroundColor: Colors.amber[700],
            colorText: Colors.white,
            duration: const Duration(seconds: 4),
          );
          return false;
        }

        return true; // All validations passed
      } else {
        Get.snackbar(
          'Error',
          'Failed to load user data. Please try again.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Something went wrong: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }
  }

  void _handleTransferToBank() async {
    bool isValid = await _validateBankTransfer();

    if (isValid) {
      _showTransferDialog();
    } else {
      // Show dialog to direct user to profile page
      Get.dialog(
        AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Complete Your Profile',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Would you like to update your profile with the required bank details and ID verification?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Later', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Get.back();
                Get.to(
                  () => const EditProfileScreen(),
                );
              },
              child: const Text('Update Profile',
                  style: TextStyle(color: Colors.blue)),
            ),
          ],
        ),
      );
    }
  }

  void _showTransferDialog() async {
    final amountController = TextEditingController();
    final response = await ApiService.fetchMyProfile();
    final userData = jsonDecode(response.body);
    final bankDetails = userData['user']['bankDetails'];

    if (bankDetails == null) {
      Get.snackbar(
        'Error',
        'Please add bank details in your profile first',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }

    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Transfer to Bank',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bank: ${bankDetails['bankName']}\nAccount: ${bankDetails['accountNumber']}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Amount',
                hintText: 'Enter amount to transfer',
                labelStyle: const TextStyle(color: Colors.grey),
                hintStyle: const TextStyle(color: Colors.grey),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade700),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blueAccent),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                Get.snackbar(
                  'Error',
                  'Please enter a valid amount',
                  backgroundColor: Colors.redAccent,
                  colorText: Colors.white,
                );
                return;
              }

              if (amount > walletController.balance.value) {
                Get.snackbar(
                  'Insufficient Balance',
                  'Your wallet balance is less than the requested amount',
                  backgroundColor: Colors.redAccent,
                  colorText: Colors.white,
                );
                return;
              }

              // Create transfer request data
              final transferData = {
                'bankName': bankDetails['bankName'],
                'accountNo': bankDetails['accountNumber'],
                'ifsc': bankDetails['ifscCode'],
                'accountHolderName': bankDetails['accountHolderName'],
                'accountType': bankDetails['accountType'] ?? 'Savings',
                'amount': amount,
                'txnMode': 'IMPS',
                'remarks': 'Wallet withdrawal'
              };

              try {
                Get.back(); // Close dialog
                Get.dialog(
                  const Center(child: CircularProgressIndicator()),
                  barrierDismissible: false,
                );

                await walletController.transferToBank(transferData);
                Get.back(); // Close loading dialog

                Get.snackbar(
                  'Transfer Initiated',
                  'Your transfer request has been initiated. You will be notified once completed.',
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                  duration: const Duration(seconds: 5),
                );
              } catch (e) {
                Get.back(); // Close loading dialog
                Get.snackbar(
                  'Error',
                  'Transfer failed: ${e.toString()}',
                  backgroundColor: Colors.redAccent,
                  colorText: Colors.white,
                );
              }
            },
            child: const Text('Transfer',
                style: TextStyle(color: Colors.greenAccent)),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> getFilteredTransactions() {
    final allTransactions = walletController.transactions;
    if (_tabController.index == 0) {
      // "Bank Txs" tab - show wallet_deposit and withdrawal only
      return allTransactions
          .where((tx) =>
              tx['paymentType'] == 'wallet_deposit' ||
              tx['paymentType'] == 'withdrawal')
          .toList();
    } else if (_tabController.index == 1) {
      // "Meetings" tab - show wallet_payment (service payments)
      return allTransactions
          .where((tx) => tx['paymentType'] == 'wallet_payment')
          .toList();
    } else {
      // "Earnings" tab (_tabController.index == 2) - keep empty for now
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet', style: TextStyle(color: Colors.white)),
        elevation: 0,
      ),
      body: Obx(() {
        if (walletController.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        } else {
          return Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    // Sliver for Balance Card
                    SliverPadding(
                      padding: const EdgeInsets.all(16.0),
                      sliver: SliverToBoxAdapter(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blueGrey.withOpacity(0.1),
                                Colors.blueGrey.withOpacity(0.2),
                                Colors.blueGrey.withOpacity(0.35)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total Balance',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '₹${walletController.balance.value.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Sliver for Quick Actions
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 24),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildActionButton(
                                icon: HugeIcons.strokeRoundedWalletAdd02,
                                label: 'Add Money',
                                onTap: () =>
                                    Get.to(() => const AddMoneyScreen()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildActionButton(
                                icon: HugeIcons.strokeRoundedBank,
                                label: 'Transfer to Bank',
                                onTap: _handleTransferToBank,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Sliver for Recent Activity Title
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      sliver: SliverToBoxAdapter(
                        child: const Text(
                          'Recent Activity',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // Sliver for Transaction Tabs
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 16),
                      sliver: SliverToBoxAdapter(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicatorSize: TabBarIndicatorSize.tab,
                            indicatorColor: AppColors.primaryColor,
                            labelColor: AppColors.primaryColor,
                            unselectedLabelColor: Colors.grey,
                            dividerColor: Colors.transparent,
                            tabs: const [
                              Tab(text: 'Bank Txs'),
                              Tab(text: 'Meetings'),
                              Tab(text: 'Earnings'),
                            ],
                            onTap: (_) => setState(() {}),
                          ),
                        ),
                      ),
                    ),

                    // Sliver for Transaction List
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      sliver: getFilteredTransactions().isEmpty
                          ? SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.receipt_long_outlined,
                                      size: 48,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _tabController.index == 0
                                          ? 'No bank transactions yet'
                                          : _tabController.index == 1
                                              ? 'No meeting payments yet'
                                              : 'No earnings yet',
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final transaction =
                                      getFilteredTransactions()[index];
                                  final displayDetails =
                                      _getTransactionDisplayDetails(
                                          transaction);

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blueGrey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: (displayDetails['color']
                                                    as Color)
                                                .withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            displayDetails['icon'] as IconData,
                                            color: displayDetails['color']
                                                as Color,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                displayDetails['title']
                                                    as String,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                displayDetails['subtitle']
                                                    as String,
                                                style: TextStyle(
                                                  color: Colors.grey[400],
                                                  fontSize: 11,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                displayDetails['date']
                                                    as String,
                                                style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          displayDetails['amount'] as String,
                                          style: TextStyle(
                                            color: displayDetails['color']
                                                as Color,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                childCount: getFilteredTransactions().length,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
      }),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.blueGrey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primaryColor, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
