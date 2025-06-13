import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../features/wallet/presentation/screens/payment_success_screen.dart';
import '../../helpers/app_colors.dart';

class WebViewScreen extends StatefulWidget {
  final String url;
  final String title;
  final bool isPayment;
  final double amount;

  const WebViewScreen({
    super.key,
    required this.url,
    required this.title,
    this.isPayment = true,
    required this.amount,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController controller;
  bool isLoading = true;
  final Completer<void> _pageLoaded = Completer<void>();

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar
            if (progress == 100) {
              setState(() {
                isLoading = false;
              });
              if (!_pageLoaded.isCompleted) {
                _pageLoaded.complete();
              }
            }
          },
          onPageStarted: (String url) {
            setState(() {
              isLoading = true;
            });
            print('Page started loading: $url');
          },
          onPageFinished: (String url) async {
            setState(() {
              isLoading = false;
            });

            print('Page finished loading: $url');

            // Check if we're on a success or failure page
            if (url.startsWith(widget.url) && (url.contains("success") || url.contains("failed"))) {
              // Extract payment data from the page's JavaScript
              try {
                final result = await controller.runJavaScriptReturningResult(
                  'JSON.stringify(window.paymentData || {})'
                );

                String jsonString = result.toString();
                // Remove any quotes that wrap the JSON string
                if (jsonString.startsWith('"') && jsonString.endsWith('"')) {
                  jsonString = jsonString.substring(1, jsonString.length - 1);
                  // Unescape any quotes inside the JSON
                  jsonString = jsonString.replaceAll('\\"', '"');
                }

                print('Extracted payment data: $jsonString');

                if (jsonString.isNotEmpty && jsonString != '{}') {
                  // Parse query parameters from URL if needed
                  Uri uri = Uri.parse(url);
                  final merchantReferenceId = uri.queryParameters['merchantReferenceId'];

                  final Map<String, String> paymentResult = {
                    'status': url.contains("success") ? 'success' : 'failure',
                    'merchantReferenceId': merchantReferenceId ?? '',
                  };

                  // Delayed to ensure visual feedback before closing
                  Future.delayed(const Duration(seconds: 2), () {
                    Get.back(result: paymentResult);
                  });
                }
              } catch (e) {
                print('Error extracting payment data: $e');
              }
            }
          },
          onWebResourceError: (WebResourceError error) {
            print('Web resource error: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            print('Navigation request: ${request.url}');

            // Detect success/failure URLs in navigation
            if (request.url.startsWith(widget.url) && (request.url.contains("success") || request.url.contains("failed"))) {

              // Extract merchantReferenceId from URL
              Uri uri = Uri.parse(request.url);
              final merchantReferenceId = uri.queryParameters['merchantReferenceId'];

              if (merchantReferenceId != null) {
                final status = request.url.contains("success") ? 'success' : 'failure';

                // Allow navigation to continue so we can extract data in onPageFinished
                return NavigationDecision.navigate;
              }
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..addJavaScriptChannel(
        'PaymentComplete',
        onMessageReceived: (JavaScriptMessage message) {
          print('Message from JavaScript: ${message.message}');
          // Parse message data if needed
          try {
            // Check if we've already handled this redirect
            if (!Get.isDialogOpen! && context.mounted) {
              final messageData = message.message.split(',');
              if (messageData.length >= 2) {
                final status = messageData[0];
                final merchantReferenceId = messageData[1];

                Get.back(result: {
                  'status': status,
                  'merchantReferenceId': merchantReferenceId
                });
              }
            }
          } catch (e) {
            print('Error processing JavaScript message: $e');
          }
        },
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Handle back button press - show confirmation dialog
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cancel Payment?'),
            content: const Text('Are you sure you want to cancel this payment?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yes'),
              ),
            ],
          ),
        );
        return shouldPop ?? false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Complete Payment'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Cancel Payment?'),
                  content: const Text('Are you sure you want to cancel this payment?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('No'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(true);
                        Get.back(result: null);
                      },
                      child: const Text('Yes'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: controller),
            if (isLoading)
              Container(
                color: Colors.black87,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.accentColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
