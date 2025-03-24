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
  var wishlistUsers = <User>[].obs;
  var isWishlistLoading = false.obs;

  // Add a set to track users who have had Insta Talk
  final RxSet<String> _instaTalkUsedWith = <String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    fetchProfiles();
    fetchWalletBalance();
    fetchWishlist();
    _loadInstaTalkHistory();
  }

  // Load Insta Talk history from SharedPrefs
  Future<void> _loadInstaTalkHistory() async {
    try {
      final history = await SharedPrefs.getInstaTalkHistory();
      if (history.isNotEmpty) {
        _instaTalkUsedWith.addAll(history);
      }
    } catch (e) {
      print('Error loading Insta Talk history: $e');
    }
  }

  // Record that Insta Talk has been used with a user
  Future<void> recordInstaTalkUsage(String userId) async {
    try {
      _instaTalkUsedWith.add(userId);
      await SharedPrefs.saveInstaTalkHistory(_instaTalkUsedWith.toList());
    } catch (e) {
      print('Error recording Insta Talk usage: $e');
    }
  }

  // Check if Insta Talk has been used with a user
  bool hasUsedInstaTalk(String userId) {
    return _instaTalkUsedWith.contains(userId);
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

  Future<void> addToWishlist(String userId) async {
    try {
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      final response = await ApiService.addToWishlist(userId);

      Get.back(); // Close loading dialog

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Update UI if needed or refresh wishlist
        await fetchWishlist();

        Get.snackbar(
          'Success',
          'Added to favorites',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
      } else {
        final errorMsg = jsonDecode(response.body)['message']?.toString() ??
            'Failed to add to favorites';
        throw Exception(errorMsg);
      }
    } catch (e) {
      print('Error adding to wishlist: $e');
      Get.snackbar(
        'Error',
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> removeFromWishlist(String userId) async {
    try {
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      final response = await ApiService.removeFromWishlist(userId);

      Get.back(); // Close loading dialog

      if (response.statusCode == 200) {
        // Remove from local list if it exists
        wishlistUsers.removeWhere((user) => user.sId == userId);
        wishlistUsers.refresh();

        Get.snackbar(
          'Success',
          'Removed from favorites',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
      } else {
        final errorMsg = jsonDecode(response.body)['message']?.toString() ??
            'Failed to remove from favorites';
        throw Exception(errorMsg);
      }
    } catch (e) {
      print('Error removing from wishlist: $e');
      Get.snackbar(
        'Error',
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> fetchWishlist() async {
    try {
      isWishlistLoading(true);
      final response = await ApiService.getWishlist();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('RAW WISHLIST RESPONSE: ${response.body}');
        final wishlistData = data['wishlist'] as List;

        // Create proper User objects based on the structure in the response
        wishlistUsers.clear();
        for (var item in wishlistData) {
          try {
            print('Processing wishlist item: $item');

            // Create safe values for potential null fields
            final String itemId = item['_id']?.toString() ?? '';
            final String name = item['name']?.toString() ?? 'No Name';
            final String email = item['email']?.toString() ?? '';
            final String dob = item['dob']?.toString() ?? '';

            // Handle potential different formats in the API response
            List<String>? photosList;
            if (item['photos'] is List) {
              photosList =
                  (item['photos'] as List).map((p) => p.toString()).toList();
            } else if (item['profilePicture'] != null &&
                item['profilePicture'].toString().isNotEmpty) {
              photosList = [item['profilePicture'].toString()];
            } else {
              photosList = [];
            }

            // Extract earnings data if available
            Earnings? earnings;
            if (item['earnings'] is Map) {
              var earningsData = item['earnings'] as Map;
              earnings = Earnings(
                chat: earningsData['chat'] ?? 150,
                voice: earningsData['voice'] ?? 300,
                video: earningsData['video'] ?? 450,
                live: earningsData['live'] ?? 5,
                subscription: earningsData['subscription'] ?? 700,
              );
              print('Created earnings object: ${earnings.toJson()}');
            } else {
              earnings = Earnings(); // Use defaults
              print('Using default earnings');
            }

            // Build location data if available
            Location? location;
            if (item['location'] != null && item['location'] is Map) {
              var loc = item['location'] as Map;
              location = Location(
                city: loc['city']?.toString() ?? 'Unknown',
                state: loc['state']?.toString() ?? '',
                country: loc['country']?.toString() ?? '',
              );
            }

            final user = User(
              sId: itemId,
              name: name,
              email: email,
              dob: dob,
              photos: photosList,
              location: location,
              earnings: earnings, // Add earnings object explicitly
            );

            wishlistUsers.add(user);
            print(
                'Successfully added user to wishlist: $name ($itemId) with earnings: ${earnings.toJson()}');
          } catch (e) {
            print('Error processing wishlist user: $e');
            print('Problematic item data: $item');
          }
        }

        print('Wishlist fetched: ${wishlistUsers.length} users');
      } else {
        throw Exception('Failed to load wishlist');
      }
    } catch (e) {
      print('Error fetching wishlist: $e');
      _showSnackbar(
        'Error',
        'Failed to fetch favorites: ${e.toString()}',
        isError: true,
      );
    } finally {
      isWishlistLoading(false);
    }
  }

  // Add a convenient method to check if a user is in wishlist with better logging
  bool isUserInWishlist(String userId) {
    if (userId.isEmpty) {
      print('⚠️ Warning: Checking empty userId for wishlist');
      return false;
    }

    final result = wishlistUsers.any((user) => user.sId == userId);
    print('🔍 Checking if user $userId is in wishlist: $result');
    return result;
  }

  // Add a method for creating instant meetings
  Future<bool> createInstantMeeting(
    String participantId,
    String type,
    double rate,
  ) async {
    try {
      isLoading(true);
      final scheduleTime = DateTime.now();

      final response =
          await ApiService.createMeeting(participantId, type, scheduleTime);

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);

        Get.snackbar(
          'Success',
          'Instant session created successfully',
          backgroundColor: Colors.green.withOpacity(0.8),
          colorText: Colors.white,
        );

        // Here you would navigate to the actual meeting interface
        // For example:
        // Get.to(() => MeetingRoom(meetingData: data));

        return true;
      } else {
        final data = jsonDecode(response.body);
        errorMessage(data['message'] ?? 'Failed to create instant session');

        Get.snackbar(
          'Error',
          errorMessage.value,
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
        );

        return false;
      }
    } catch (e) {
      errorMessage('An error occurred: $e');

      Get.snackbar(
        'Error',
        errorMessage.value,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );

      return false;
    } finally {
      isLoading(false);
    }
  }
}
