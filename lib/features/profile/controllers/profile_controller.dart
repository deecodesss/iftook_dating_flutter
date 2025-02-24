import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/core/services/api_service.dart';
import 'package:iftook/core/services/shared_prefs.dart';
import 'package:iftook/features/auth/presentation/screens/login_screen.dart';
import 'package:iftook/features/profile/data/models/user.dart';

class ProfileController extends GetxController {
  // Observable variables for profile data
  var isLoading = false.obs;
  var errorMessage = ''.obs;
  var user = User().obs; // Observable User object

  @override
  void onInit() {
    fetchProfile();
    super.onInit();
  }

  // Fetch profile data from the API
  Future<void> fetchProfile() async {
    try {
      isLoading(true); // Start loading
      errorMessage(''); // Clear any previous errors

      final response = await ApiService.fetchMyProfile();

      if (response.statusCode == 200) {
        // Parse the response and update the User object
        final data = jsonDecode(response.body);
        user.value = User.fromJson(data['user']);
      } else {
        throw Exception('Failed to load profile: ${response.statusCode}');
      }
    } catch (e) {
      errorMessage('Error fetching profile: $e');
      Get.snackbar('Error', 'Failed to load profile data',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      isLoading(false); // Stop loading
    }
  }

  // Logout the user
  void logout() {
    SharedPrefs
        .clearUserSharedPreferences(); // Clear user data from SharedPreferences
    Get.offAll(() => LoginScreen()); // Navigate to the login screen
  }
}
