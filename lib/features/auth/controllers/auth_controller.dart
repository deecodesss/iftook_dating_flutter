import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:iftook/core/services/api_service.dart'; // Assuming you have an API service
import 'package:iftook/core/services/shared_prefs.dart';
import 'package:iftook/features/home/presentation/screens/home_screen.dart';
import 'package:iftook/features/auth/presentation/screens/register_screen.dart';
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
  // Future<void> register() async {
  //   try {
  //     isLoading(true);
  //     errorMessage('');

  //     // Prepare the request body
  //     final requestBody = {
  //       'name': name.value,
  //       'email': email.value,
  //       'password': password.value,
  //       'dob': dob.value,
  //       'gender': gender.value.toLowerCase(),
  //       'interestedIn':
  //           gender.value.toLowerCase() == 'female' ? 'men' : "women",
  //       'about': about.value,
  //       'profession': profession.value,
  //       'height': height.value,
  //       'languages': languages.toList(),
  //       'location': location,
  //       'interests': interests.toList(),
  //       'panDetails': panDetails,
  //       'earnings': earnings,
  //       'isOnline': isOnline.value,
  //     };

  //     print("register body: $requestBody");

  //     // Call the API
  //     final response = await ApiService.register(requestBody);
  //     print("Registration response: ${response.body}");

  //     if (response.statusCode == 200 || response.statusCode == 201) {
  //       final responseData = jsonDecode(response.body);

  //       // Check if the response contains success flag
  //       if (responseData['success'] == true) {
  //         // Save user data and token
  //         if (responseData['user'] != null) {
  //           await SharedPrefs.saveUserIdSharedPreference(
  //               responseData['user']['_id']);
  //         }

  //         // Update FCM token
  //         updateFCMToken();

  //         // Handle successful registration
  //         Get.offAll(() => const HomeScreen()); // Navigate to home screen
  //         Get.snackbar('Success', 'Registration successful!',
  //             backgroundColor: Colors.green, colorText: Colors.white);
  //       } else {
  //         errorMessage.value =
  //             responseData['message']?.toString() ?? 'Registration failed';
  //       }
  //     } else {
  //       // Handle API errors
  //       final errorData = jsonDecode(response.body);
  //       errorMessage.value =
  //           errorData['message']?.toString() ?? 'Registration failed';
  //     }
  //   } catch (e) {
  //     print('Registration error: $e');
  //     errorMessage.value = 'An error occurred during registration';
  //   } finally {
  //     isLoading(false);
  //   }
  // }

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

  // Google Sign In instance
  GoogleSignIn? _googleSignIn;
  var isGoogleLoading = false.obs;

  // Required scopes
  static const List<String> scopes = <String>[
    'email',
    'profile',
  ];

  @override
  void onInit() {
    super.onInit();
    _initializeGoogleSignIn();
  }

  void _initializeGoogleSignIn() {
    try {
      _googleSignIn = GoogleSignIn(
        serverClientId:
            '857030913183-lv6238u30mab49a2us1c7h4q9o8j3ps2.apps.googleusercontent.com',
        scopes: scopes,
        signInOption: SignInOption.standard,
      );

      print('Google Sign-in initialized successfully');
      print('Available scopes: $scopes');
    } catch (e) {
      print('Google Sign-in initialization error: $e');
    }
  }

  // Google Sign In method
  Future<void> signInWithGoogle() async {
    try {
      isGoogleLoading(true);
      errorMessage('');

      if (_googleSignIn == null) {
        errorMessage('Google Sign-in not properly configured');
        return;
      }

      print('Starting Google Sign-in process...');

      // Check if Google Play Services is available
      print('Checking Google Play Services availability...');

      // Sign out first to ensure clean state
      await _googleSignIn!.signOut();
      print('Signed out from previous session');

      // Use the standard signIn method
      print('Attempting to sign in...');
      final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();

      if (googleUser == null) {
        print('User cancelled sign-in');
        Get.snackbar('Info', 'Sign-in cancelled',
            backgroundColor: Colors.orange, colorText: Colors.white);
        return;
      }

      print('Google user obtained: ${googleUser.email}');

      // Get the authentication details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      print('Authentication tokens obtained');

      // Verify we have the required tokens
      if (googleAuth.idToken == null) {
        print('ID Token is null');
        errorMessage('Failed to get authentication tokens from Google');
        return;
      }

      print('Google Sign-in successful for: ${googleUser.email}');

      // Check if user exists in backend
      final userExists = await checkUserExists(googleUser.email);

      if (userExists) {
        // User exists, proceed with login
        await loginWithGoogle(googleUser);
      } else {
        // User doesn't exist, proceed with registration
        await registerWithGoogle(googleUser);
      }
    } catch (e) {
      print('Google Sign-In error details: $e');
      print('Error type: ${e.runtimeType}');

      String errorMsg = 'Failed to sign in with Google. Please try again.';

      if (e.toString().contains('ApiException: 10')) {
        errorMsg =
            'Google Sign-in configuration error. Please contact support.';
      } else if (e.toString().contains('network_error')) {
        errorMsg = 'Network error. Please check your internet connection.';
      } else if (e.toString().contains('sign_in_canceled')) {
        errorMsg = 'Sign-in was cancelled.';
      }

      errorMessage(errorMsg);
      Get.snackbar('Error', errorMsg,
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      isGoogleLoading(false);
    }
  }

  // Check if user exists
  Future<bool> checkUserExists(String email) async {
    try {
      final response = await ApiService.checkUserExists(email);
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['exists'] ?? false;
      }
      return false;
    } catch (e) {
      print('Check user exists error: $e');
      return false;
    }
  }

  // Login with Google
  Future<void> loginWithGoogle(GoogleSignInAccount googleUser) async {
    try {
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final requestBody = {
        'email': googleUser.email,
        'googleId': googleUser.id,
        'name': googleUser.displayName,
        'photoUrl': googleUser.photoUrl,
        'idToken': googleAuth.idToken,
      };

      final response = await ApiService.loginWithGoogle(requestBody);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['success'] == true) {
          // Save tokens and user data
          if (responseData['accessToken'] != null) {
            await SharedPrefs.saveTokens(
                responseData['accessToken'], responseData['refreshToken']);
          }

          await SharedPrefs.saveUserIdSharedPreference(
              responseData['user']['_id']);
          await SharedPrefs.saveUserEmailSharedPreference(googleUser.email);
          await SharedPrefs.saveUsernameSharedPreference(
              responseData['user']['name']);

          // Update FCM token
          updateFCMToken();

          Get.offAll(() => const HomeScreen());
          Get.snackbar('Success', 'Signed in successfully!',
              backgroundColor: Colors.green, colorText: Colors.white);
        } else {
          errorMessage.value =
              responseData['message'] ?? 'Google sign-in failed';
        }
      } else {
        final errorData = jsonDecode(response.body);
        errorMessage.value = errorData['message'] ?? 'Google sign-in failed';
      }
    } catch (e) {
      print('Google login error: $e');
      errorMessage('Failed to sign in with Google');
    }
  }

  // Register with Google (navigate to registration with pre-filled data)
  Future<void> registerWithGoogle(GoogleSignInAccount googleUser) async {
    try {
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Pre-fill the form data
      name.value = googleUser.displayName ?? '';
      email.value = googleUser.email;
      isEmailVerified.value = true; // Google email is already verified

      // Navigate to registration screen
      Get.to(() => const RegisterScreen(), arguments: {
        'fromGoogle': true,
        'googleData': {
          'id': googleUser.id,
          'name': googleUser.displayName,
          'email': googleUser.email,
          'photoUrl': googleUser.photoUrl,
          'idToken': googleAuth.idToken,
        }
      });

      Get.snackbar('Welcome!', 'Please complete your profile to get started',
          backgroundColor: Colors.blue, colorText: Colors.white);
    } catch (e) {
      print('Register with Google error: $e');
      errorMessage('Failed to start registration process');
    }
  }

  // Modified register method to handle Google registration
  Future<void> register(
      {bool isGoogleSignup = false, Map<String, dynamic>? googleData}) async {
    try {
      isLoading(true);
      errorMessage('');

      String? freshIdToken;
      if (isGoogleSignup) {
        try {
          // Re-authenticate silently to get a fresh ID token, as the original one might have expired
          // during the multi-step registration process.
          final googleUser = _googleSignIn?.currentUser;
          if (googleUser == null) {
            errorMessage.value =
                'Google session expired. Please try signing in again.';
            isLoading(false);
            return;
          }
          final googleAuth = await googleUser.authentication;
          freshIdToken = googleAuth.idToken;

          if (freshIdToken == null) {
            errorMessage.value =
                'Could not refresh Google token. Please try again.';
            isLoading(false);
            return;
          }
        } catch (e) {
          print('Error refreshing Google token: $e');
          errorMessage.value =
              'Failed to refresh Google session. Please try again.';
          isLoading(false);
          return;
        }
      }

      // Prepare the request body
      final requestBody = {
        'name': name.value,
        'email': email.value,
        'password': isGoogleSignup ? null : password.value,
        'googleId': isGoogleSignup ? (googleData?['id']) : null,
        'photoUrl': isGoogleSignup
            ? (googleData != null ? googleData['photoUrl'] : null)
            : null,
        'idToken': isGoogleSignup ? freshIdToken : null,
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

      // Call the appropriate API endpoint
      final response = isGoogleSignup
          ? await ApiService.registerWithGoogle(requestBody)
          : await ApiService.register(requestBody);

      print("Registration response: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);

        // Check if the response contains success flag
        if (responseData['success'] == true) {
          // Save user data and tokens
          if (responseData['user'] != null) {
            await SharedPrefs.saveUserIdSharedPreference(
                responseData['user']['_id']);
          }

          if (responseData['accessToken'] != null) {
            await SharedPrefs.saveTokens(
                responseData['accessToken'], responseData['refreshToken']);
          }

          // Update FCM token
          updateFCMToken();

          // Handle successful registration
          Get.offAll(() => const HomeScreen());
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

  // Clean up Google Sign-in on dispose
  @override
  void onClose() {
    _googleSignIn?.signOut();
    super.onClose();
  }
}
