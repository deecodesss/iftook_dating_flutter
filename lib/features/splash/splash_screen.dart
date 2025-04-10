import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/core/services/api_service.dart';
import 'package:iftook/core/services/shared_prefs.dart';
import 'package:iftook/core/services/socket_service.dart';
import 'package:iftook/features/auth/presentation/screens/login_screen.dart';
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
  bool isLoggedIn = false;

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
    _checkIsLoggedIn();
    Future.delayed(Duration(seconds: 3), () {
      Get.off(() => isLoggedIn ? HomeScreen() : LoginScreen());
    });

    // fetchData();
  }

  void _checkIsLoggedIn() async {
    final accessToken = await SharedPrefs.getAccessToken();
    final refreshToken = await SharedPrefs.getRefreshToken();

    // Only consider logged out if both tokens are null
    isLoggedIn = (accessToken != null || refreshToken != null);

    if (isLoggedIn) {
      // Try refreshing the token during splash screen
      final refreshed = await ApiService.refreshToken();
      isLoggedIn = refreshed; // Update login state based on refresh result

      if (isLoggedIn) {
        await SocketService().initSocket(); // 👈 connect socket if login valid
      }
    }
  }

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
            width: 200,
            height: 200,
          ),
        ),
      ),
    );
  }
}
