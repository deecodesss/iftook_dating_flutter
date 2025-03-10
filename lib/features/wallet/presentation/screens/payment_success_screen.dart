import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/features/wallet/controllers/wallet_controller.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final String transactionId;
  final double amount;
  const PaymentSuccessScreen({
    super.key,
    required this.transactionId,
    required this.amount,
  });

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  @override
  void initState() {
    Future.delayed(Duration(seconds: 1), () {
      Get.put(WalletController()).addMoney(widget.amount, widget.transactionId);
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: GetBuilder<WalletController>(
        builder: (controller) => controller.isLoading.isTrue
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Payment Success Card
                      _buildPaymentSuccessCard(controller),
                      const SizedBox(height: 20),
                      // Action Buttons
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildPaymentSuccessCard(WalletController controller) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: Color(0xFF4CAF50),
              size: 80,
            ),
            const SizedBox(height: 20),
            Text(
              'Payment Success!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                // color: Theme.of(context).colorScheme.onSurface.withOpacity(0.9),
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your payment has been successfully processed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
