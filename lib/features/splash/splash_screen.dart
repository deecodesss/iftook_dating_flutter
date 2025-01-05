import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/features/home/presentation/screens/home_screen.dart';

import '../../helpers/myassets.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  String? token = '';

  @override
  void initState() {
    super.initState();
    // Animation setup
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _controller.forward();
    Future.delayed(Duration(seconds: 3), () {
      Get.off(() => HomeScreen());
    });

    // fetchData();
  }

  // Future<void> fetchData() async {
  //   token = await SharedPrefs.getUserTokenSharedPreference();
  //   bool isBiometricEnabled =
  //       await SharedPrefs.getBiometricPreference() ?? false;
  //
  //   SchedulerBinding.instance.addPostFrameCallback((_) async {
  //     Get.put(SubscriptionController()).checkForSubscription();
  //     await updateFCMToken();
  //
  //     Future.delayed(const Duration(seconds: 3), () async {
  //       if (token?.isNotEmpty ?? false) {
  //         if (isBiometricEnabled) {
  //           bool authenticated = await BiometricService.loginWithBiometric();
  //           if (!authenticated) {
  //             Get.offAll(() => const LoginScreen());
  //             return;
  //           }
  //         }
  //       }
  //
  //       Get.offAll(() =>
  //       token?.isEmpty ?? true ? const LoginScreen() : const HomeScreen());
  //     });
  //   });
  // }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _animation,
        child: Center(
          child: Image.asset(
            MyAssets.appIconPNG,
            width: 100,
            height: 100,
          ),
        ),
      ),
    );
  }
}
