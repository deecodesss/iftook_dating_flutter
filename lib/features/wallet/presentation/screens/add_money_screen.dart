import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:iftook/helpers/app_colors.dart';
import '../../controllers/wallet_controller.dart';

class AddMoneyScreen extends StatefulWidget {
  const AddMoneyScreen({super.key});

  @override
  State<AddMoneyScreen> createState() => _AddMoneyScreenState();
}

class _AddMoneyScreenState extends State<AddMoneyScreen> {
  final TextEditingController _amountController = TextEditingController();
  final WalletController walletController = Get.find<WalletController>();
  final List<double> quickAmounts = [100, 500, 1000, 2000, 5000, 10000];
  double selectedAmount = 0;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _selectQuickAmount(double amount) {
    setState(() {
      selectedAmount = amount;
      _amountController.text = amount.toString();
    });
  }

  void _onAmountChanged(String value) {
    setState(() {
      selectedAmount = double.tryParse(value) ?? 0;
    });
  }

  void _proceedToPayment() {
    final amount = double.tryParse(_amountController.text);

    if (amount == null || amount <= 0) {
      Get.snackbar(
        'Invalid Amount',
        'Please enter a valid amount greater than 0',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (amount < 1) {
      Get.snackbar(
        'Minimum Amount',
        'Minimum amount to add is ₹10',
        backgroundColor: Colors.amber,
        colorText: Colors.white,
      );
      return;
    }

    if (amount > 100000) {
      Get.snackbar(
        'Maximum Amount',
        'Maximum amount to add is ₹1,00,000',
        backgroundColor: Colors.amber,
        colorText: Colors.white,
      );
      return;
    }

    // Show payment confirmation
    _showPaymentConfirmation(amount);
  }

  void _showPaymentConfirmation(double amount) {
    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: Row(
          children: [
            Icon(
              HugeIcons.strokeRoundedWalletAdd02,
              color: AppColors.primaryColor,
              size: 24,
            ),
            SizedBox(width: 10),
            Text(
              'Confirm Payment',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to add money to your wallet:',
              style: TextStyle(color: Colors.grey[300]),
            ),
            SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryColor.withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Amount to Add',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '₹${amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: AppColors.primaryColor,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.blue,
                  size: 16,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You will be redirected to UPI payment',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              walletController.makePayment(amount);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Proceed to Pay'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Add Money',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: Obx(() {
        if (walletController.isLoading.value) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                ),
                SizedBox(height: 16),
                Text(
                  'Processing Payment...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Please complete the payment in your UPI app',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current Balance Card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blueGrey.withOpacity(0.1),
                      Colors.blueGrey.withOpacity(0.2),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Balance',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '₹${walletController.balance.value.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 32),

              // Enter Amount Section
              Text(
                'Enter Amount',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),

              // Amount Input Field
              Container(
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selectedAmount > 0
                        ? AppColors.primaryColor.withOpacity(0.5)
                        : Colors.grey.withOpacity(0.3),
                  ),
                ),
                child: TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                  onChanged: _onAmountChanged,
                  decoration: InputDecoration(
                    hintText: 'Enter amount',
                    hintStyle: TextStyle(color: Colors.grey),
                    prefixIcon: Icon(
                      Icons.currency_rupee,
                      color: AppColors.primaryColor,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 24),

              // Quick Amount Selection
              Text(
                'Quick Select',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 12),

              GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.5,
                ),
                itemCount: quickAmounts.length,
                itemBuilder: (context, index) {
                  final amount = quickAmounts[index];
                  final isSelected = selectedAmount == amount;

                  return GestureDetector(
                    onTap: () => _selectQuickAmount(amount),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryColor.withOpacity(0.2)
                            : Colors.blueGrey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryColor
                              : Colors.grey.withOpacity(0.3),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '₹${amount.toInt()}',
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.primaryColor
                                : Colors.white,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              SizedBox(height: 32),

              // Payment Info
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.security,
                          color: Colors.blue,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Secure Payment',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Payments are processed securely via UPI\n• No additional charges\n• Instant wallet top-up\n• Minimum: ₹10, Maximum: ₹1,00,000',
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 32),
            ],
          ),
        );
      }),
      bottomNavigationBar: Obx(() {
        return Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            border: Border(
              top: BorderSide(
                color: Colors.grey.withOpacity(0.3),
              ),
            ),
          ),
          child: SafeArea(
            child: ElevatedButton(
              onPressed: selectedAmount > 0 && !walletController.isLoading.value
                  ? _proceedToPayment
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (walletController.isLoading.value) ...[
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                  ],
                  Icon(HugeIcons.strokeRoundedWalletAdd02),
                  SizedBox(width: 8),
                  Text(
                    selectedAmount > 0
                        ? 'Add ₹${selectedAmount.toStringAsFixed(0)}'
                        : 'Enter Amount',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
