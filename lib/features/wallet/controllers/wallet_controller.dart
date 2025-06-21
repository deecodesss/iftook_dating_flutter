import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/core/services/api_service.dart';
import 'package:iftook/features/wallet/presentation/screens/wallet_screen.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:http/http.dart' as http;

class WalletController extends GetxController {
  var balance = 0.0.obs;
  var transactions = <Map<String, dynamic>>[].obs;
  var isLoading = true.obs;
  var errorMessage = ''.obs;
  var paymentSuccess = false.obs;
  var isQRDialogOpen = false.obs;
  Timer? _paymentTimer;

  String MERCH_ID = "IFTOOK";
  String MERCHANT_PASSWORD = "VUY*^587v^%g";
  String? AUTH_TOKEN;
  // Generate merchant token
  Future<void> generateMerchantToken() async {
    try {
      print('=== GENERATING MERCHANT TOKEN ===');
      print('Merchant ID: $MERCH_ID');
      print('Password length: ${MERCHANT_PASSWORD.length}');

      final requestBody = {
        'mid': MERCH_ID,
        'password': MERCHANT_PASSWORD,
        'expiry': false,
      };

      print('Token request body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse("https://server.paygic.in/api/v3/createMerchantToken"),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print('Token response status: ${response.statusCode}');
      print('Token response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Token response parsed successfully');
        print('Response data keys: ${data.keys.toList()}');

        if (data['status'] == true) {
          if (data['data'] != null && data['data']['token'] != null) {
            AUTH_TOKEN = data['data']['token'];
            print('Token generated successfully: ${data['data']['expires']}');
            print('Token length: ${AUTH_TOKEN!.length}');
            print('Token preview: ${AUTH_TOKEN!.substring(0, 50)}...');
          } else {
            print('ERROR: Token data is null or missing');
            print('Available keys in data: ${data['data']?.keys?.toList()}');
            throw Exception('Token not found in response');
          }
        } else {
          print('ERROR: Token generation failed');
          print('Response status: ${data['status']}');
          print('Response message: ${data['msg']}');
          throw Exception(data['msg'] ?? 'Failed to generate token');
        }
      } else {
        print('ERROR: HTTP ${response.statusCode}');
        try {
          final errorData = jsonDecode(response.body);
          print('Error response parsed: $errorData');
          throw Exception(
              'HTTP ${response.statusCode}: ${errorData['msg'] ?? 'Failed to generate token'}');
        } catch (parseError) {
          print('Failed to parse error response: $parseError');
          throw Exception(
              'HTTP ${response.statusCode}: Failed to generate token');
        }
      }
    } catch (e) {
      print('EXCEPTION in generateMerchantToken: $e');
      print('Exception type: ${e.runtimeType}');
      throw Exception('Failed to generate merchant token: $e');
    } finally {
      print('=== TOKEN GENERATION END ===');
    }
  }

  // Generate unique merchant reference ID
  String generateUniqueMerchantRefId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random();
    final randomNumber = random.nextInt(999999).toString().padLeft(6, '0');
    return 'PMT_${timestamp}_$randomNumber';
  }

  // Check payment status periodically
  void checkPaymentStatus({
    required String merchantId,
    required String authToken,
    required String merchantReferenceId,
  }) {
    _paymentTimer?.cancel();

    _paymentTimer = Timer.periodic(Duration(seconds: 3), (timer) async {
      print('Checking payment status...');
      try {
        final response = await http.post(
          Uri.parse("https://server.paygic.in/api/v2/checkPaymentStatus"),
          headers: {
            'Content-Type': 'application/json',
            'token': authToken,
          },
          body: jsonEncode({
            'mid': merchantId,
            'merchantReferenceId': merchantReferenceId,
          }),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['txnStatus']?.toString().toLowerCase() == 'success') {
            timer.cancel();
            paymentSuccess.value = true;

            print('🎉 Payment successful detected!');
            print('🎉 Transaction Status: ${data['txnStatus']}');

            // Update payment status in database and add money to wallet
            print('💰 Updating payment in backend database...');
            await _updatePaymentSuccessInDatabase(merchantReferenceId);

            // Also try the backend API check
            print('🔍 Double-checking with backend API...');
            await checkPaymentStatusWithBackend(merchantReferenceId);

            // Close QR dialog if it's open
            if (isQRDialogOpen.value) {
              Get.back(); // Close QR dialog
              isQRDialogOpen.value = false;
            }

            // Show success message
            Get.snackbar(
              'Payment Successful!',
              'Your payment has been processed successfully.',
              backgroundColor: Colors.green,
              colorText: Colors.white,
              duration: Duration(seconds: 3),
            );

            // Refresh wallet data
            await fetchWalletData();
            Get.back(); // Go back to wallet screen
          }
        }
      } catch (e) {
        print('Error checking payment status: $e');
      }
    });
  }

  // Create payment request using Paygic
  Future<void> createPaygicPaymentRequest({
    required double amount,
    required String customerName,
    required String customerEmail,
    required String customerMobile,
  }) async {
    try {
      isLoading.value = true;
      print('Starting payment request for amount: $amount');
      print(
          'Customer details - Name: $customerName, Email: $customerEmail, Mobile: $customerMobile'); // Generate token if not available
      if (AUTH_TOKEN == null) {
        print('Auth token is null, generating new token...');
        await generateMerchantToken();
        print(
            'Token generation completed. Token available: ${AUTH_TOKEN != null}');

        if (AUTH_TOKEN != null) {
          print('Generated token preview: ${AUTH_TOKEN!.substring(0, 50)}...');
        }
      } else {
        print(
            'Using existing token. Token preview: ${AUTH_TOKEN!.substring(0, 50)}...');
      }

      if (AUTH_TOKEN == null) {
        print('ERROR: Auth token is still null after generation attempt');
        throw Exception('Failed to generate authentication token');
      }
      final merchantReferenceId = generateUniqueMerchantRefId();
      print('Generated merchant reference ID: $merchantReferenceId');

      // First, create payment entry in our database
      print('🗃️ Creating payment entry in database...');
      try {
        await _createPaymentEntryInDatabase(
          amount: amount,
          merchantReferenceId: merchantReferenceId,
          customerName: customerName,
          customerEmail: customerEmail,
          customerMobile:
              customerMobile.isEmpty ? '9999999999' : customerMobile,
        );
      } catch (e) {
        print('❌ Failed to create payment entry, but continuing: $e');
      }

      print('DEBUG: MERCH_ID value: "$MERCH_ID"');
      print('DEBUG: MERCHANT_PASSWORD length: ${MERCHANT_PASSWORD.length}');
      print('DEBUG: AUTH_TOKEN length: ${AUTH_TOKEN?.length}');

      // Ensure mobile number is valid
      if (customerMobile.isEmpty) {
        customerMobile = '7014892480';
        print('Mobile was empty, using default: $customerMobile');
      }

      final requestBody = {
        'mid': MERCH_ID, // This should be "IFTOOK"
        'amount': amount.toString(),
        'merchantReferenceId': merchantReferenceId,
        'customer_name': customerName,
        'customer_email': customerEmail,
        'customer_mobile': customerMobile.isEmpty
            ? '7014892480'
            : customerMobile, // Ensure mobile is not empty
      };

      print('DEBUG: requestBody mid value: "${requestBody['mid']}"');
      print('Request body: ${jsonEncode(requestBody)}');
      print(
          'Request headers: Content-Type: application/json, token: ${AUTH_TOKEN!.substring(0, 20)}...');

      final response = await http.post(
        Uri.parse("https://server.paygic.in/api/v2/createPaymentRequest"),
        headers: {
          'Content-Type': 'application/json',
          'token': AUTH_TOKEN!,
        },
        body: jsonEncode(requestBody),
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Parsed response data: $data');

        // Check if the API returned success status
        if (data['status'] == false) {
          print('ERROR: API returned failure status');
          print('Status code: ${data['statusCode']}');
          print('Message: ${data['msg']}');

          if (data['statusCode'] == 401 ||
              data['msg']?.toString().toLowerCase().contains('token') == true) {
            print('Token is invalid, attempting to regenerate...');
            AUTH_TOKEN = null;
            await generateMerchantToken();
            if (AUTH_TOKEN != null) {
              print('Token regenerated, retrying payment request...');
              await createPaygicPaymentRequest(
                amount: amount,
                customerName: customerName,
                customerEmail: customerEmail,
                customerMobile: customerMobile,
              );
              return;
            } else {
              throw Exception('Failed to regenerate authentication token');
            }
          } else {
            throw Exception(data['msg'] ?? 'Payment request failed');
          }
        }

        // Check if response has the expected structure
        if (data == null) {
          print('ERROR: Response data is null');
          throw Exception('Empty response from payment gateway');
        }

        if (data['data'] == null) {
          print('ERROR: Response data[\'data\'] is null');
          print('Available keys in response: ${data.keys.toList()}');
          throw Exception('Invalid response structure: missing data field');
        }

        if (data['data']['intent'] == null) {
          print('ERROR: Response data[\'data\'][\'intent\'] is null');
          print('Available keys in data: ${data['data']?.keys?.toList()}');
          throw Exception('Invalid response structure: missing intent field');
        }

        final upiUri = data['data']['intent'];
        print('UPI URI received: $upiUri');

        // Start checking payment status
        print('Starting payment status monitoring...');
        checkPaymentStatus(
          merchantId: MERCH_ID,
          authToken: AUTH_TOKEN!,
          merchantReferenceId: merchantReferenceId,
        );

        bool launched = false;

        try {
          print('Attempting to launch UPI intent...');
          // Try to launch UPI intent
          launched = await url_launcher.launch(
            upiUri,
            forceSafariVC: false,
            forceWebView: false,
          );
          print('First launch attempt result: $launched');

          if (!launched) {
            print('First launch failed, trying alternative method...');
            launched = await url_launcher.launch(upiUri);
            print('Second launch attempt result: $launched');
          }
        } catch (e) {
          print('UPI launch error: $e');
          launched = false;
        }

        // If UPI intent launch failed, show QR code
        if (!launched) {
          print('UPI intent launch failed, showing QR code dialog');
          showQRCodeDialog(upiUri, merchantReferenceId);
        } else {
          print('UPI intent launched successfully');
        }
      } else if (response.statusCode == 401) {
        print('ERROR: Unauthorized - Invalid token');
        // Try to regenerate token and retry once
        print('Attempting to regenerate token...');
        AUTH_TOKEN = null;
        await generateMerchantToken();
        if (AUTH_TOKEN != null) {
          print('Token regenerated, retrying payment request...');
          // Retry the request with new token
          await createPaygicPaymentRequest(
            amount: amount,
            customerName: customerName,
            customerEmail: customerEmail,
            customerMobile: customerMobile,
          );
          return;
        } else {
          throw Exception('Failed to regenerate authentication token');
        }
      } else {
        print('ERROR: HTTP ${response.statusCode}');
        print('Error response body: ${response.body}');

        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['message'] ??
              errorData['msg'] ??
              'Unknown error from payment gateway';
          throw Exception('Payment gateway error: $errorMessage');
        } catch (jsonError) {
          print('Failed to parse error response as JSON: $jsonError');
          throw Exception(
              'HTTP ${response.statusCode}: Failed to create payment request');
        }
      }
    } catch (e) {
      print('EXCEPTION in createPaygicPaymentRequest: $e');
      print('Exception type: ${e.runtimeType}');

      String errorMessage = 'Failed to create payment request';

      if (e.toString().contains('No such method')) {
        errorMessage = 'Invalid response format from payment gateway';
      } else if (e.toString().contains('null')) {
        errorMessage = 'Invalid response from payment gateway (null data)';
      } else if (e.toString().contains('token')) {
        errorMessage = 'Authentication failed - please try again';
      } else if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        errorMessage = 'Network error - please check your internet connection';
      }

      Get.snackbar(
        'Payment Error',
        '$errorMessage: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 5),
      );
    } finally {
      isLoading.value = false;
      print('Payment request completed, loading set to false');
    }
  }

  // Show QR code dialog
  void showQRCodeDialog(String upiUri, String merchantReferenceId) {
    isQRDialogOpen.value = true;

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 400,
            maxHeight: 600,
          ),
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.qr_code, color: Colors.blue, size: 30),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Scan QR Code to Pay',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),

              Text(
                'UPI apps could not be launched automatically. Please scan the QR code below with any UPI app to complete the payment.',
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),

              // QR Code would be displayed here
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white,
                ),
                padding: EdgeInsets.all(10),
                child: Center(
                  child: Text('QR Code\n$upiUri', textAlign: TextAlign.center),
                ),
              ),
              SizedBox(height: 15),

              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    Text(
                      'Transaction ID: $merchantReferenceId',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue),
                        SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Payment status will be updated automatically',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue.shade700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        _paymentTimer?.cancel();
                        Get.back();
                        isQRDialogOpen.value = false;
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Close',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: true,
    ).then((_) {
      isQRDialogOpen.value = false;
    });
  }

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
      print('=== MAKE PAYMENT START ===');
      print('Payment amount: $amount');

      // Get user profile data for payment
      print('Fetching user profile...');
      final profileResponse = await ApiService.fetchMyProfile();
      print('Profile response status: ${profileResponse.statusCode}');
      print('Profile response body: ${profileResponse.body}');

      if (profileResponse.statusCode == 200) {
        final profileData = jsonDecode(profileResponse.body);
        print('Profile data parsed successfully');
        print('Profile data keys: ${profileData.keys.toList()}');

        final userData = profileData['user'];
        if (userData == null) {
          print('ERROR: userData is null');
          print('Available keys in profileData: ${profileData.keys.toList()}');
          throw Exception('User data not found in profile response');
        }
        print(
            'User data keys: ${userData.keys.toList()}'); // Extract user details
        String customerName = userData['name'] ?? 'User';
        String customerEmail = userData['email'] ?? '';
        String customerMobile = userData['mobile'] ?? userData['phone'] ?? '';

        // Ensure we have a valid mobile number
        if (customerMobile.isEmpty) {
          customerMobile = '7014892480'; // Default mobile number
        }

        print('Extracted customer details:');
        print('Name: $customerName');
        print('Email: $customerEmail');
        print('Mobile: $customerMobile'); // Create Paygic payment request
        print('🚀 Calling createPaygicPaymentRequest...');
        print('🚀 Amount: $amount');
        print('🚀 Customer Name: $customerName');
        print('🚀 Customer Email: $customerEmail');
        print('🚀 Customer Mobile: $customerMobile');

        await createPaygicPaymentRequest(
          amount: amount,
          customerName: customerName,
          customerEmail: customerEmail,
          customerMobile: customerMobile,
        );
        print('✅ createPaygicPaymentRequest completed');
      } else {
        print('ERROR: Failed to fetch profile');
        print('Response status: ${profileResponse.statusCode}');
        print('Response body: ${profileResponse.body}');
        throw Exception('Failed to get user profile');
      }
    } catch (e) {
      print('EXCEPTION in makePayment: $e');
      print('Exception type: ${e.runtimeType}');
      print('Stack trace: ${StackTrace.current}');

      Get.snackbar(
        'Error',
        'Failed to make payment: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      isLoading.value = false;
    } finally {
      print('=== MAKE PAYMENT END ===');
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

  // Create payment entry in database before Paygic request
  Future<void> _createPaymentEntryInDatabase({
    required double amount,
    required String merchantReferenceId,
    required String customerName,
    required String customerEmail,
    required String customerMobile,
  }) async {
    try {
      print('🗃️ Creating payment entry in database...');
      print('🗃️ Amount: $amount');
      print('🗃️ Merchant Reference ID: $merchantReferenceId');

      final response = await ApiService.createPaymentEntry(
        amount: amount,
        merchantReferenceId: merchantReferenceId,
        customerName: customerName,
        customerEmail: customerEmail,
        customerMobile: customerMobile,
      );

      print('🗃️ Database response status: ${response.statusCode}');
      print('🗃️ Database response body: ${response.body}');

      if (response.statusCode == 201) {
        print('✅ Payment entry created successfully in database');
      } else {
        final errorData = jsonDecode(response.body);
        print('❌ Failed to create payment entry: ${errorData['message']}');
        // Don't throw error here as payment can still proceed
      }
    } catch (e) {
      print('❌ Error creating payment entry in database: $e');
      // Don't throw error here as payment can still proceed
    }
  }

  // Update payment status and wallet balance on success
  Future<void> _updatePaymentSuccessInDatabase(
      String merchantReferenceId) async {
    try {
      final response = await ApiService.updatePaymentStatusAndWallet(
        merchantReferenceId: merchantReferenceId,
        paymentStatus: 'success',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Payment updated successfully: ${data['message']}');
        print('New wallet balance: ${data['newBalance']}');

        // Update local balance
        if (data['newBalance'] != null) {
          balance.value = (data['newBalance'] as num).toDouble();
        }
      } else {
        print('Failed to update payment status: ${response.body}');
      }
    } catch (e) {
      print('Error updating payment status: $e');
    }
  }

  // Test method to manually create payment entry
  Future<void> testCreatePaymentEntry() async {
    try {
      print('🧪 Testing payment entry creation...');
      final testMerchantRefId = generateUniqueMerchantRefId();

      await _createPaymentEntryInDatabase(
        amount: 1.0,
        merchantReferenceId: testMerchantRefId,
        customerName: 'Test User',
        customerEmail: 'test@example.com',
        customerMobile: '9999999999',
      );

      print('🧪 Test completed');
    } catch (e) {
      print('🧪 Test failed: $e');
    }
  }

  // Test method to manually update payment status
  Future<void> testUpdatePaymentStatus(String merchantReferenceId) async {
    try {
      print('🧪 Testing payment status update...');
      await _updatePaymentSuccessInDatabase(merchantReferenceId);
      print('🧪 Test completed');
    } catch (e) {
      print('🧪 Test failed: $e');
    }
  }

  // Check payment status using our backend API
  Future<void> checkPaymentStatusWithBackend(String merchantReferenceId) async {
    try {
      print('🔍 Checking payment status with backend...');
      print('🔍 Merchant Reference ID: $merchantReferenceId');

      final response = await ApiService.checkAndUpdatePaymentStatus(
        merchantReferenceId: merchantReferenceId,
      );

      print('🔍 Backend response status: ${response.statusCode}');
      print('🔍 Backend response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Backend check completed: ${data['message']}');

        // If payment was successfully verified and wallet updated
        if (data['newBalance'] != null) {
          balance.value = (data['newBalance'] as num).toDouble();
          print('💰 Wallet balance updated to: ${balance.value}');

          // Show success message
          Get.snackbar(
            'Payment Verified!',
            'Your payment has been verified and wallet updated.',
            backgroundColor: Colors.green,
            colorText: Colors.white,
            duration: Duration(seconds: 3),
          );

          // Refresh wallet data
          await fetchWalletData();
        }
      } else {
        print('❌ Backend check failed: ${response.body}');
      }
    } catch (e) {
      print('❌ Error checking payment status with backend: $e');
    }
  }
}
