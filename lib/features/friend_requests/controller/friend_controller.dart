import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/core/services/api_service.dart';
import 'package:iftook/features/friend_requests/data/models/friend_request.dart';
import 'package:iftook/features/profile/data/models/user.dart';

import '../../../core/services/shared_prefs.dart';

class FriendController extends GetxController {
  var friendRequests = <FriendRequest>[].obs;
  var friends = <User>[].obs;
  var isLoading = false.obs;
  var sentRequests = <FriendRequest>[].obs;
  var meetings = <dynamic>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchFriendRequests();
    fetchFriends();
    fetchSentRequests();
    fetchMeetings();
  }

  Future<void> fetchFriendRequests() async {
    try {
      print('request....');
      isLoading(true);
      var response =
          await ApiService.getFriendRequests(); // Replace with your API call
      if (response != null) {
        // Parse the JSON response to a list of FriendRequest objects
        List<dynamic> requestsJson = jsonDecode(response.body)['requests'];
        List<FriendRequest> friendRequestList =
            requestsJson.map((json) => FriendRequest.fromJson(json)).toList();
        friendRequests.assignAll(
            friendRequestList); // Assign the list to the observable list
        print('success....');
      }
    } catch (e) {
      print("Error fetching friend requests: $e");
    } finally {
      isLoading(false);
    }
  }

  Future<void> fetchFriends() async {
    try {
      print('request....');
      isLoading(true);
      var response =
          await ApiService.getFriendList(); // Replace with your API call
      if (response != null) {
        // Parse the JSON response to a list of FriendRequest objects
        List<dynamic> requestsJson = jsonDecode(response.body)['friends'];
        List<User> friendsList =
            requestsJson.map((json) => User.fromJson(json)).toList();
        friends
            .assignAll(friendsList); // Assign the list to the observable list
        print('success....');
      }
    } catch (e) {
      print("Error fetching friend requests: $e");
    } finally {
      isLoading(false);
    }
  }

  Future<void> fetchSentRequests() async {
    try {
      isLoading(true);
      final response = await ApiService.getSentFriendRequests();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Raw sent requests data: ${response.body}');

        if (data['success'] == true && data['requests'] is List) {
          final requests = data['requests'] as List;
          final parsedRequests = requests
              .map((request) => FriendRequest.fromJson(request))
              .toList();

          sentRequests.assignAll(parsedRequests);
          print('Processed ${parsedRequests.length} sent requests');
        }
      }
    } catch (e) {
      print('Error in fetchSentRequests: $e');
      sentRequests.clear();
    } finally {
      isLoading(false);
    }
  }

  Future<void> fetchMeetings() async {
    try {
      isLoading(true);
      final userId = await SharedPrefs.getUserIdSharedPreference();
      print('Fetching meetings for user: $userId');

      final response = await ApiService.getUserMeetings(userId!);
      print('Meetings response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        meetings.assignAll(data['meetings'] ?? []);
        print('Fetched ${meetings.length} meetings');
      } else {
        print('Failed to fetch meetings: ${response.statusCode}');
        throw Exception('Failed to load meetings');
      }
    } catch (e) {
      print('Error fetching meetings: $e');
    } finally {
      isLoading(false);
    }
  }

  Future<void> acceptRequest(String requestId, BuildContext context) async {
    try {
      // Call the API to accept the friend request
      var response = await ApiService.acceptFriendRequest(requestId);
      if (response != null) {
        fetchFriendRequests(); // Refresh the friend requests list after acceptance
        // Show success snackbar
        Get.snackbar('Success', 'Friend Request Accepted',
            backgroundColor: Colors.green, colorText: Colors.white);
        // Navigate back after success
        Navigator.pop(context); // This should go back to the previous screen
      } else {
        // Handle error response
        Get.snackbar(
            'Error',
            jsonDecode(response.body)['message']?.toString() ??
                'Friend Request failed',
            backgroundColor: Colors.red,
            colorText: Colors.white);
      }
    } catch (e) {
      print("Error accepting friend request: $e");
      Get.snackbar('Error', 'Something went wrong. Try again later.',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<void> rejectRequest(String requestId, BuildContext context) async {
    try {
      // Call the API to reject the friend request
      var response = await ApiService.declineFriendRequest(requestId);
      if (response != null) {
        fetchFriendRequests(); // Refresh the friend requests list after rejection
        // Show success snackbar
        Get.snackbar('Success', 'Friend Request Rejected',
            backgroundColor: Colors.green, colorText: Colors.white);
        // Navigate back after rejection
        Navigator.pop(context); // This should go back to the previous screen;
      } else {
        // Handle error response
        Get.snackbar(
            'Error',
            jsonDecode(response.body)['message']?.toString() ??
                'Friend Request failed',
            backgroundColor: Colors.red,
            colorText: Colors.white);
      }
    } catch (e) {
      print("Error rejecting friend request: $e");
      Get.snackbar('Error', 'Something went wrong. Try again later.',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }
}
