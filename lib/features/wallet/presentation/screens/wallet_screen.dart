import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:iftook/helpers/app_colors.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with SingleTickerProviderStateMixin {
  final double balance = 1250.00; // Example balance
  late TabController _tabController;

  // Example transaction data
  final List<Map<String, dynamic>> transactions = List.generate(20, (index) {
    bool isRefund = index % 3 == 0;
    return {
      'id': 1000 + index,
      'type': isRefund ? 'Refund' : 'Transaction',
      'amount': (index + 1) * 100,
      'date': 'Dec 10, 2024',
      'isRefund': isRefund,
    };
  });

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  List<Map<String, dynamic>> getFilteredTransactions() {
    if (_tabController.index == 0) {
      return transactions; // All
    } else if (_tabController.index == 1) {
      return transactions.where((tx) => !tx['isRefund']).toList(); // Earnings
    } else {
      return transactions.where((tx) => tx['isRefund']).toList(); // Refunds
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet', style: TextStyle(color: Colors.white)),
        elevation: 0,
      ),
      body: Column(
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
                            '₹${balance.toStringAsFixed(2)}',
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
                            onTap: () {
                              // Add money logic
                            },
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
                          Tab(text: 'All'),
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
                        final transaction = getFilteredTransactions()[index];
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
                                  color: transaction['isRefund']
                                      ? AppColors.redColor.withOpacity(0.2)
                                      : AppColors.greenColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  transaction['isRefund']
                                      ? HugeIcons
                                          .strokeRoundedSquareArrowUpRight
                                      : HugeIcons
                                          .strokeRoundedSquareArrowDownLeft, // Refund (remove), Transaction (add)
                                  color: transaction['isRefund']
                                      ? AppColors.redColor
                                      : AppColors
                                          .greenColor, // Red for refunds, green for earnings
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      transaction['isRefund']
                                          ? 'Refund #${transaction['id']}' // Deduction
                                          : 'Earning #${transaction['id']}', // Earning
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      transaction['date'],
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                transaction['isRefund']
                                    ? '-₹${transaction['amount']}' // Refund (Deduction)
                                    : '+₹${transaction['amount']}', // Transaction (Earning)
                                style: TextStyle(
                                  color: transaction['isRefund']
                                      ? AppColors.redColor // Red for deductions
                                      : AppColors
                                          .greenColor, // Green for earnings
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
