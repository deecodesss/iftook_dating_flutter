import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/core/services/api_service.dart'; // Your API service
import 'package:iftook/core/services/shared_prefs.dart';
import 'package:iftook/features/home/presentation/screens/home_screen.dart';
import 'package:iftook/features/profile/data/models/user.dart';

class SearchControllerCustom extends GetxController {
  // Observable variables
  var searchQuery = ''.obs;
  var searchResults = <User>[].obs;
  var recentSearches = <String>[].obs;
  var isLoading = false.obs;
  var errorMessage = ''.obs;

  // Perform search
  Future<void> performSearch(String query) async {
    try {
      isLoading(true); // Start loading
      errorMessage(''); // Clear any previous errors

      if (query.isEmpty) {
        searchResults.clear(); // Clear results if query is empty
        return;
      }

      // Call the API to fetch search results
      final response = await ApiService.searchUsers(query);

      if (response.statusCode == 200) {
        // Parse the response and update searchResults
        final data = jsonDecode(response.body)['users'];
        searchResults.value =
            (data as List).map((item) => User.fromJson(item)).toList();

        // Add query to recent searches
        if (!recentSearches.contains(query)) {
          recentSearches.add(query);
        }
      } else {
        throw Exception(
            'Failed to load search results: ${response.statusCode}');
      }
    } catch (e) {
      errorMessage('Error searching: $e');
      // Get.snackbar('Error', 'Failed to fetch search results',
      //     backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      isLoading(false); // Stop loading
    }
  }

  Future<void> addFriend(String id) async {
    try {
      isLoading(true);
      errorMessage('');
      final userId = await SharedPrefs.getUserIdSharedPreference();

      final requestBody = {
        'requesterId': userId,
        'receiverId': id,
      };

      final response = await ApiService.addFriend(requestBody);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        // Save user data or token if needed

        Get.offAll(() => const HomeScreen());
        Get.snackbar('Success', 'Friend Request Sent',
            backgroundColor: Colors.green, colorText: Colors.white);
      } else {
        errorMessage.value = jsonDecode(response.body)['message']?.toString() ??
            'Friend Request failed';
        Get.snackbar(
            'Error',
            jsonDecode(response.body)['message']?.toString() ??
                'Friend Request failed',
            backgroundColor: Colors.red,
            colorText: Colors.white);
      }
    } catch (e) {
      errorMessage('An error occurred: $e');
    } finally {
      isLoading(false);
    }
  }

  // Clear search results
  void clearSearch() {
    searchQuery.value = '';
    searchResults.clear();
  } // Clear search results

  void clearRecentSearches() {
    // searchQuery.value = '';
    recentSearches.clear();
  }
}
