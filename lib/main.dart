import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/features/splash/splash_screen.dart';
import 'package:iftook/theme/app_theme.dart';

void main() {
  runApp(
    GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: "iftook",
      home: SplashScreen(),
      theme: AppThemes.darkTheme,
      initialRoute: '/',
    ),
  );
}
