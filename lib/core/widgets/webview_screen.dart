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

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              isLoading = true;
            });

            if (widget.isPayment && url.contains("success")) {
              Uri uri = Uri.parse(url);
              String? id = uri.queryParameters["merchantReferenceId"];
              print("Transaction id////////////// $id");

              // Get.offAll(() => const HomeScreen());
              Get.off(() => PaymentSuccessScreen(
                    transactionId: id!,
                    amount: widget.amount,
                  ));
            } else if (widget.isPayment && url.contains("failed")) {
              Get.back();
              Get.snackbar(
                  'Error', "Something went wrong, please try again later",
                  backgroundColor: Colors.red, colorText: Colors.white);
            }
          },
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              controller.reload();
            },
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: () async {
              final Uri url = Uri.parse(widget.url);
              // You'll need to implement url_launcher for this
              // await launchUrl(url, mode: LaunchMode.externalApplication);
            },
          ),
        ],
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
    );
  }
}
