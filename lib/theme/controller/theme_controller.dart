// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:stoxii/core/shared_prefs/shared_prefs.dart';
// import 'package:stoxii/theme/app_theme.dart';
//
// class ThemeController extends GetxController {
//   RxBool isDarkMode = true.obs;
//   RxBool isBiometricEnabled = false.obs;
//
//   @override
//   void onInit() {
//     super.onInit();
//     _loadTheme();
//   }
//
//   void _loadTheme() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     isDarkMode.value = prefs.getBool('isDarkMode') ?? false;
//     isBiometricEnabled.value =
//         await SharedPrefs.getBiometricPreference() ?? false;
//   }
//
//   void toggleTheme() async {
//     isDarkMode.value = !isDarkMode.value;
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     prefs.setBool('isDarkMode', isDarkMode.value);
//   }
//
//   void toggleBiometric() async {
//     isBiometricEnabled.value = !isBiometricEnabled.value;
//     SharedPrefs.setBiometricPreference(isBiometricEnabled.value);
//   }
//
//   ThemeData get currentTheme {
//     return isDarkMode.value ? AppThemes.darkTheme : AppThemes.lightTheme;
//   }
// }
