import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/core/services/api_service.dart';
import 'package:iftook/core/services/shared_prefs.dart';
import 'package:iftook/features/profile/data/models/user.dart';

class HomeController extends GetxController {
  var profiles = <User>[].obs;
  var isLoading = true.obs;
  var errorMessage = ''.obs;
  var currentIndex = 0.obs;
  var userWalletBalance = 0.0.obs;
  var countries = <String>[].obs;
  var selectedCountry = 'All'.obs;
  var allProfiles = <User>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchProfiles();
    fetchWalletBalance();
  }

  Future<void> fetchProfiles() async {
    try {
      isLoading(true);
      final response = await ApiService.fetchDatingFeed();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final users = data['users'] as List;

        // Store all profiles
        allProfiles
            .assignAll(users.map((user) => User.fromJson(user)).toList());

        // Extract unique countries
        final uniqueCountries = allProfiles
            .map((user) => user.location?.country ?? 'Unknown')
            .toSet()
            .toList();
        countries.value = ['All', ...uniqueCountries];

        // Update displayed profiles based on selected country
        _filterProfilesByCountry();
      } else {
        throw Exception('Failed to load profiles');
      }
    } catch (e) {
      print('Error fetching profiles: $e');
    } finally {
      isLoading(false);
    }
  }

  void setSelectedCountry(String country) {
    selectedCountry.value = country;
    currentIndex.value = 0; // Reset index when filtering
    _filterProfilesByCountry();
  }

  void _filterProfilesByCountry() {
    try {
      if (selectedCountry.value == 'All') {
        profiles.assignAll(allProfiles);
      } else {
        final filteredProfiles = allProfiles
            .where(
              (profile) => profile.location?.country == selectedCountry.value,
            )
            .toList();

        if (filteredProfiles.isEmpty) {
          profiles.clear();
          Get.snackbar(
            'No Profiles',
            'No profiles found in ${selectedCountry.value}',
            backgroundColor: Colors.grey[800],
            colorText: Colors.white,
            duration: const Duration(seconds: 2),
          );
        } else {
          profiles.assignAll(filteredProfiles);
        }
      }
    } catch (e) {
      print('Error filtering profiles: $e');
      profiles.clear();
    }
  }

  Future<void> sendFriendRequest(String receiverId) async {
    try {
      print('Sending friend request to: $receiverId');

      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      final userId = await SharedPrefs.getUserIdSharedPreference();
      final currentProfile = profiles[currentIndex.value];

      if (userId == receiverId) {
        Get.back();
        Get.snackbar(
          'Error',
          'You cannot send a friend request to yourself',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      if (currentProfile.isFriend == true) {
        Get.back();
        Get.snackbar(
          'Info',
          'Already in your circle',
          backgroundColor: Colors.blue,
          colorText: Colors.white,
        );
        return;
      }

      final requestBody = {
        'requesterId': userId,
        'receiverId': receiverId,
      };

      final response = await ApiService.addFriend(requestBody);
      print('Friend request response: ${response.body}');

      Get.back();

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Update the profile's friend status
        final updatedProfile = User(
          sId: currentProfile.sId,
          name: currentProfile.name,
          email: currentProfile.email,
          // phone: currentProfile.phone,
          dob: currentProfile.dob,
          gender: currentProfile.gender,
          profession: currentProfile.profession,
          photos: currentProfile.photos,
          location: currentProfile.location,
          isFriend: true,
        );

        profiles[currentIndex.value] = updatedProfile;
        profiles.refresh();

        Get.snackbar(
          'Success',
          'Friend Request Sent',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        final errorMsg = jsonDecode(response.body)['message']?.toString() ??
            'Failed to send friend request';
        throw Exception(errorMsg);
      }
    } catch (e) {
      Get.back();
      print('Error sending friend request: $e');
      Get.snackbar(
        'Error',
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<bool> createMeeting(String participantId, String type,
      DateTime scheduleTime, double amount) async {
    try {
      await fetchWalletBalance();

      if (userWalletBalance.value < amount) {
        _showSnackbar(
          'Insufficient Balance',
          'Please top up your wallet to schedule this meeting',
          isError: true,
          mainButton: TextButton(
            onPressed: () => Get.toNamed('/wallet/topup'),
            child: Text('Top Up', style: TextStyle(color: Colors.white)),
          ),
        );
        return false;
      }

      print(
          'Creating meeting: $participantId, $type, $scheduleTime, Amount: $amount');

      final response = await ApiService.createMeeting(
        participantId,
        type,
        scheduleTime,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Meeting created successfully: ${response.body}');

        // Deduct money from wallet after successful meeting creation
        final deductResponse = await ApiService.deductMoneyToWallet(amount);
        if (deductResponse.statusCode == 200) {
          print('Money deducted successfully');
          await fetchWalletBalance(); // Refresh wallet balance after deduction
        } else {
          print('Failed to deduct money: ${deductResponse.body}');
        }

        return true;
      } else {
        throw Exception('Failed to create meeting: ${response.body}');
      }
    } catch (e) {
      print('Error creating meeting: $e');
      _showSnackbar(
        'Error',
        'Failed to create meeting: ${e.toString()}',
        isError: true,
      );
      return false;
    }
  }

  void _showSnackbar(String title, String message,
      {bool isError = false, Widget? mainButton}) {
    if (Get.isSnackbarOpen) {
      Get.closeAllSnackbars();
    }

    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: isError ? Colors.red : Colors.green,
      colorText: Colors.white,
      duration: Duration(seconds: isError ? 4 : 2),
      margin: const EdgeInsets.all(8),
      borderRadius: 8,
      isDismissible: true,
      dismissDirection: DismissDirection.horizontal,
      forwardAnimationCurve: Curves.easeOutBack,
      // Convert Widget to TextButton if needed
      mainButton: mainButton is TextButton ? mainButton : null,
      snackStyle: SnackStyle.FLOATING,
      overlayBlur: 0,
      overlayColor: Colors.black26,
    );
  }

  Future<void> fetchWalletBalance() async {
    try {
      final response = await ApiService.fetchUSerWallet();
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Wallet API Response: ${response.body}');
        // Update to match the actual API response structure
        userWalletBalance.value = data['data']['balance'] != null
            ? (data['data']['balance'] as num).toDouble()
            : 0.0;
        print('Updated wallet balance: ${userWalletBalance.value}');
      }
    } catch (e) {
      print('Error fetching wallet balance: $e');
    }
  }

  // Update current profile index
  void updateCurrentIndex(int index) {
    if (profiles.isEmpty) return;
    if (index >= 0 && index < profiles.length) {
      currentIndex.value = index;
      print('Current profile index updated to: $index');
    } else {
      currentIndex.value = 0;
      print('Invalid index, reset to 0');
    }
  }
}
