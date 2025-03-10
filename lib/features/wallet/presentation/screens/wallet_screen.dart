import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:iftook/helpers/app_colors.dart';
import 'package:intl/intl.dart';

import '../../controllers/wallet_controller.dart';

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
  }

  List<Map<String, dynamic>> getFilteredTransactions() {
    if (_tabController.index == 0) {
      return walletController.transactions; // All
    } else if (_tabController.index == 1) {
      return walletController.transactions
          .where((tx) => tx['paymentType'] != 'refund')
          .toList(); // Earnings
    } else {
      return walletController.transactions
          .where((tx) => tx['paymentType'] == 'refund')
          .toList(); // Refunds
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
                                onTap:
                                    _showAddMoneyDialog, // Call the dialog here
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildActionButton(
                                icon: HugeIcons.strokeRoundedBank,
                                label: 'Transfer to Bank',
                                onTap: () {
                                  // Transfer to bank logic
                                },
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
                            tabs: const [
                              Tab(text: 'Transactions'),
                              Tab(text: 'Earnings'),
                              Tab(text: 'Refunds'),
                            ],
                            onTap: (_) => setState(() {}),
                          ),
                        ),
                      ),
                    ),

                    // Sliver for Transaction List
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final transaction =
                                getFilteredTransactions()[index];
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
                                      color: transaction['paymentType'] ==
                                              'refund'
                                          ? AppColors.redColor.withOpacity(0.2)
                                          : AppColors.greenColor
                                              .withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      transaction['paymentType'] == 'refund'
                                          ? HugeIcons
                                              .strokeRoundedSquareArrowUpRight
                                          : HugeIcons
                                              .strokeRoundedSquareArrowDownLeft,
                                      color:
                                          transaction['paymentType'] == 'refund'
                                              ? AppColors.redColor
                                              : AppColors.greenColor,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          transaction['paymentType'] == 'refund'
                                              ? 'Refund #${transaction['_id']}'
                                              : 'Earning #${transaction['_id']}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          convertToIST(
                                              transaction['paymentDate']),
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    transaction['paymentType'] == 'refund'
                                        ? '-₹${transaction['amount']}'
                                        : '+₹${transaction['amount']}',
                                    style: TextStyle(
                                      color:
                                          transaction['paymentType'] == 'refund'
                                              ? AppColors.redColor
                                              : AppColors.greenColor,
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

  void _showAddMoneyDialog() {
    final amountController = TextEditingController();

    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.grey[900], // Dark background
        title: const Text(
          'Add Money to Wallet',
          style: TextStyle(color: Colors.white), // Light text
        ),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white), // Light text input
          decoration: InputDecoration(
            labelText: 'Amount',
            hintText: 'Enter amount',
            labelStyle: const TextStyle(color: Colors.grey), // Light label
            hintStyle: const TextStyle(color: Colors.grey), // Light hint
            enabledBorder: OutlineInputBorder(
              borderSide:
                  BorderSide(color: Colors.grey.shade700), // Border color
            ),
            focusedBorder: OutlineInputBorder(
              borderSide:
                  BorderSide(color: Colors.blueAccent), // Highlight color
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back(); // Close the dialog
            },
            child: const Text('Cancel',
                style: TextStyle(
                    color: Colors.redAccent)), // Dark mode friendly button
          ),
          TextButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                walletController
                    .makePayment(amount); // Call the addMoney method
                Get.back(); // Close the dialog
              } else {
                Get.snackbar(
                  'Error',
                  'Please enter a valid amount',
                  backgroundColor: Colors.redAccent,
                  colorText: Colors.white,
                );
              }
            },
            child: const Text('Add',
                style: TextStyle(
                    color: Colors.greenAccent)), // Green for confirmation
          ),
        ],
      ),
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
