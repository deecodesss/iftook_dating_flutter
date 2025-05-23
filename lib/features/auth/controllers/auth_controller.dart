import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';
import 'package:iftook/core/services/api_service.dart'; // Assuming you have an API service
import 'package:iftook/core/services/shared_prefs.dart';
import 'package:iftook/features/home/presentation/screens/home_screen.dart';
import 'package:iftook/features/notifications/controllers/notification_controller.dart';
import 'package:flutter/material.dart';

class AuthController extends GetxController {
  // Form fields
  var name = ''.obs;
  var email = ''.obs;
  var password = ''.obs;
  var dob = ''.obs;
  var gender = ''.obs;
  var interestedIn = ''.obs;
  var about = ''.obs;
  var profession = ''.obs;
  var height = ''.obs;
  var languages = <String>[].obs;
  var location = {
    'country': '',
    'state': '',
    'city': '',
  }.obs;
  var photos = <String>[].obs;
  var interests = <String>[].obs;
  var panDetails = {
    'panNumber': '',
    'panImage': '',
  }.obs;
  var earnings = {
    'chat': 0,
    'voice': 0,
    'video': 0,
    'live': 0,
    'subscription': 0,
  }.obs;
  var isOnline = true.obs;

  // Loading state
  var isLoading = false.obs;

  // Error message
  var errorMessage = ''.obs;

  var isEmailVerified = false.obs;

  // Register method
  Future<void> register() async {
    try {
      isLoading(true);
      errorMessage('');

      // Prepare the request body
      final requestBody = {
        'name': name.value,
        'email': email.value,
        'password': password.value,
        'dob': dob.value,
        'gender': gender.value.toLowerCase(),
        'interestedIn':
            gender.value.toLowerCase() == 'female' ? 'men' : "women",
        'about': about.value,
        'profession': profession.value,
        'height': height.value,
        'languages': languages.toList(),
        'location': location,
        'interests': interests.toList(),
        'panDetails': panDetails,
        'earnings': earnings,
        'isOnline': isOnline.value,
      };

      print("register body: $requestBody");

      // Call the API
      final response = await ApiService.register(requestBody);
      print("Registration response: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);

        // Check if the response contains success flag
        if (responseData['success'] == true) {
          // Save user data and token
          if (responseData['user'] != null) {
            await SharedPrefs.saveUserIdSharedPreference(
                responseData['user']['_id']);
          }

          // Update FCM token
          updateFCMToken();

          // Handle successful registration
          Get.offAll(() => const HomeScreen()); // Navigate to home screen
          Get.snackbar('Success', 'Registration successful!',
              backgroundColor: Colors.green, colorText: Colors.white);
        } else {
          errorMessage.value =
              responseData['message']?.toString() ?? 'Registration failed';
        }
      } else {
        // Handle API errors
        final errorData = jsonDecode(response.body);
        errorMessage.value =
            errorData['message']?.toString() ?? 'Registration failed';
      }
    } catch (e) {
      print('Registration error: $e');
      errorMessage.value = 'An error occurred during registration';
    } finally {
      isLoading(false);
    }
  }

  String fcmToken = '';
  Future<void> updateFCMToken() async {
    FirebaseMessaging.instance.getToken().then((token) {
      fcmToken = token!;
      Get.put(NotificationController()).updateFCMToken(fcmToken!);
      print("FCM Token: $token");
    });
  }

  Future<void> login(String email, String password) async {
    try {
      isLoading(true);
      errorMessage('');

      final requestBody = {
        'email': email,
        'password': password,
      };

      final response = await ApiService.login(requestBody);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);

        // Save both tokens
        await SharedPrefs.saveTokens(
            responseData['accessToken'], responseData['refreshToken']);

        // Save user ID and other necessary data
        await SharedPrefs.saveUserIdSharedPreference(
            responseData['user']['_id']);
        await SharedPrefs.saveUserEmailSharedPreference(email);
        await SharedPrefs.saveUsernameSharedPreference(
            responseData['user']['name']);

        // Update FCM token
        updateFCMToken();

        Get.offAll(() => const HomeScreen());
      } else {
        final errorData = jsonDecode(response.body);
        errorMessage.value = errorData['message'] ?? 'Login failed';
      }
    } catch (e) {
      print('Login error: $e');
      errorMessage('An error occurred during login');
    } finally {
      isLoading(false);
    }
  }

  Future<Map<String, dynamic>> sendOtp(String email) async {
    try {
      isLoading(true);

      final response = await ApiService.sendOtp(email);
      final responseBody = response.body;

      // Check if response contains HTML (error page)
      if (responseBody.contains('<!DOCTYPE html>')) {
        return {
          'success': false,
          'message': 'Server error. Please try again later.'
        };
      }

      final data = jsonDecode(responseBody);

      if (data['success']) {
        return {
          'success': true,
          'message': 'OTP sent successfully',
          'otp': data['data']['otp']
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to send OTP'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to connect to server. Please try again.'
      };
    } finally {
      isLoading(false);
    }
  }

  void setEmailVerified(bool value) {
    isEmailVerified(value);
  }

  Future<bool> isLoggedIn() async {
    String? token = await SharedPrefs.getUserTokenSharedPreference();
    if (token == null || token == '') {
      return false;
    } else {
      return true;
    }
  }
}
