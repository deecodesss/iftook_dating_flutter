import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/core/services/shared_prefs.dart';
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
    isLoggedIn = await SharedPrefs.getUserTokenSharedPreference() != null;
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
