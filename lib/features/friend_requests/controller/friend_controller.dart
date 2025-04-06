import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'dart:io';

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
  var errorMessage = ''.obs;
  var instaTalkRequests = <Map<String, dynamic>>[].obs;
  var isInstaTalkLoading = false.obs;

  // Add new observable for current time
  final currentTime = DateTime.now().obs;
  Timer? _timeUpdateTimer;

  @override
  void onInit() {
    super.onInit();
    _initCurrentUserId();
    fetchFriendRequests();
    fetchFriends();
    fetchSentRequests();
    fetchMeetings();
    fetchInstaTalkRequests(); // Add this line

    // Start timer to update current time every minute
    _timeUpdateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      currentTime.value = DateTime.now();
    });
  }

  @override
  void onClose() {
    _timeUpdateTimer?.cancel();
    super.onClose();
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

  Future<void> fetchInstaTalkRequests() async {
    try {
      isInstaTalkLoading(true);
      final userId = await SharedPrefs.getUserIdSharedPreference();

      print('🎯 [Controller] Fetching InstaTalks - UserID: $userId');

      final response = await ApiService.getUserInstaTalks(userId!);
      final data = jsonDecode(response.body);

      print('🎯 [Controller] Raw response: ${response.body}');
      print('🎯 [Controller] Response success: ${data['success']}');

      if (response.statusCode == 200 && data['success'] == true) {
        // Changed from 'instaTalks' to 'meetings'
        if (data['meetings'] is List) {
          final List talks = data['meetings'];
          print('🎯 [Controller] Found ${talks.length} InstaTalk requests');

          // Debug: Print each talk's structure
          for (var talk in talks) {
            print('🎯 [Controller] Talk structure: ${jsonEncode(talk)}');
          }

          final processedTalks = talks
              .map((talk) {
                try {
                  return Map<String, dynamic>.from(talk);
                } catch (e) {
                  print('🎯 [Controller] Error processing talk: $e');
                  return null;
                }
              })
              .where((talk) => talk != null)
              .toList();

          instaTalkRequests
              .assignAll(processedTalks.cast<Map<String, dynamic>>());
          print(
              '🎯 [Controller] Successfully processed ${instaTalkRequests.length} talks');
        } else {
          print('🎯 [Controller] No meetings array in response');
          instaTalkRequests.clear();
        }
      } else {
        print('🎯 [Controller] Invalid response: ${response.statusCode}');
        instaTalkRequests.clear();
      }
    } catch (e, stackTrace) {
      print('🎯 [Controller] Error fetching InstaTalks: $e');
      print('🎯 [Controller] Stack trace: $stackTrace');
      instaTalkRequests.clear();
    } finally {
      isInstaTalkLoading(false);
      print(
          '🎯 [Controller] Final InstaTalk count: ${instaTalkRequests.length}');
    }
  }

  Future<Map<String, dynamic>?> acceptInstaTalk(String meetingId) async {
    try {
      isLoading(true);
      final userId = await SharedPrefs.getUserIdSharedPreference();

      final response = await ApiService.acceptInstaTalk(meetingId, userId!);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Refresh the InstaTalk requests list
        await fetchInstaTalkRequests();

        print('InstaTalk accepted successfully');
        return data['data'];
      } else {
        errorMessage(jsonDecode(response.body)['message'] ??
            'Failed to accept InstaTalk');
        Get.snackbar(
          'Error',
          errorMessage.value,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return null;
      }
    } catch (e) {
      errorMessage('Error accepting InstaTalk: $e');
      Get.snackbar(
        'Error',
        errorMessage.value,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return null;
    } finally {
      isLoading(false);
    }
  }

  Future<bool> declineInstaTalk(String meetingId) async {
    try {
      isLoading(true);
      final userId = await SharedPrefs.getUserIdSharedPreference();

      final response = await ApiService.declineInstaTalk(meetingId, userId!);

      if (response.statusCode == 200) {
        // Refresh the InstaTalk requests list
        await fetchInstaTalkRequests();

        Get.snackbar(
          'Success',
          'InstaTalk request declined',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        return true;
      } else {
        errorMessage(jsonDecode(response.body)['message'] ??
            'Failed to decline InstaTalk');
        Get.snackbar(
          'Error',
          errorMessage.value,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }
    } catch (e) {
      errorMessage('Error declining InstaTalk: $e');
      Get.snackbar(
        'Error',
        errorMessage.value,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    } finally {
      isLoading(false);
    }
  }

  Future<bool> updateInstaTalkTimeUsage({
    required String meetingId,
    required bool isUserOne,
  }) async {
    try {
      final userId = getCurrentUserId;
      if (userId == null) return false;

      print(
          'Updating InstaTalk time usage - Meeting: $meetingId, IsUserOne: $isUserOne');

      // Double check if time is already used
      final instaTalk = instaTalkRequests.firstWhere(
        (talk) => talk['_id'] == meetingId,
        orElse: () => <String, dynamic>{},
      );

      if (instaTalk.isEmpty) {
        print('InstaTalk not found in requests');
        return false;
      }

      // Check if time is already used for this user
      final bool timeAlreadyUsed = isUserOne
          ? instaTalk['userOneTimeUsed'] ?? false
          : instaTalk['userTwoTimeUsed'] ?? false;

      // if (timeAlreadyUsed) {
      //   print('Time already used for this user');
      //   return false;
      // }

      final response = await ApiService.updateInstaTalkTimeUsage(
        meetingId: meetingId,
        userId: userId,
        isUserOne: isUserOne,
      );

      if (response.statusCode == 200) {
        print('Time usage updated successfully');
        await fetchInstaTalkRequests(); // Refresh to get updated status
        return true;
      }

      print('Failed to update time usage: ${response.body}');
      return false;
    } catch (e) {
      print('Error updating InstaTalk time usage: $e');
      return false;
    }
  }

  Future<bool> renewInstatalk({
    required String meetingId,
    required bool isUserOne,
  }) async {
    try {
      final userId = getCurrentUserId;
      if (userId == null) return false;

      print(
          'Updating InstaTalk time usage - Meeting: $meetingId, IsUserOne: $isUserOne');

      // Double check if time is already used
      final instaTalk = instaTalkRequests.firstWhere(
        (talk) => talk['_id'] == meetingId,
        orElse: () => <String, dynamic>{},
      );

      if (instaTalk.isEmpty) {
        print('InstaTalk not found in requests');
        return false;
      }

      // Check if time is already used for this user
      final bool timeAlreadyUsed = isUserOne
          ? instaTalk['userOneTimeUsed'] ?? false
          : instaTalk['userTwoTimeUsed'] ?? false;

      // if (timeAlreadyUsed) {
      //   print('Time already used for this user');
      //   return false;
      // }

      final response = await ApiService.renewInstatalk(
        meetingId: meetingId,
        userId: userId,
        isUserOne: isUserOne,
      );

      if (response.statusCode == 200) {
        print('Time usage updated successfully');
        await fetchInstaTalkRequests(); // Refresh to get updated status
        return true;
      }

      print('Failed to update time usage: ${response.body}');
      return false;
    } catch (e) {
      print('Error updating InstaTalk time usage: $e');
      return false;
    }
  }

  // Add helper method to get user ID synchronously
  String? _currentUserId;

  String? get getCurrentUserId => _currentUserId;

  Future<void> _initCurrentUserId() async {
    _currentUserId = await SharedPrefs.getUserIdSharedPreference();
  }
  // }

  // Add helper method to check if user can interact with request
  bool canInteractWithRequest(Map<String, dynamic> instaTalk) {
    final currentUserId = getCurrentUserId;
    if (currentUserId == null) return false;

    // Only recipient can accept/decline
    final isRecipient = instaTalk['participant']?['_id'] == currentUserId;
    final status = instaTalk['status'];
    final isWaiting = status == 'waiting';

    return isRecipient && isWaiting;
  }

  String getInstaTalkDisplayName(Map<String, dynamic> instaTalk) {
    final currentUserId = getCurrentUserId;
    if (currentUserId == null || instaTalk.isEmpty) return "Unknown";

    // If current user is the sender, show recipient's name
    if (instaTalk['user']?['_id'] == currentUserId) {
      return instaTalk['participant']?['name'] ?? 'Unknown';
    }
    // If current user is the recipient, show sender's name
    else {
      return instaTalk['user']?['name'] ?? 'Unknown';
    }
  }

  // Check if current user is sender (synchronous version)
  bool isInstaTalkSender(Map<String, dynamic> instaTalk) {
    final currentUserId = getCurrentUserId;
    if (currentUserId == null || instaTalk.isEmpty) return false;

    return instaTalk['user']?['_id'] == currentUserId;
  }

  bool isInstaTalkExpired(Map<String, dynamic> instaTalk) {
    if (instaTalk['status'] == 'completed') return true;

    // Check if it's more than 30 minutes old
    final scheduledTime = DateTime.parse(instaTalk['scheduledTime']);
    final now = DateTime.now();
    final difference = now.difference(scheduledTime).inMinutes;

    return difference > 60; // Consider expired after 1 hour
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

  Future<bool> deleteSentRequest(String requestId) async {
    try {
      final response = await ApiService.deleteSentRequest(requestId);
      if (response.statusCode == 200) {
        // Refresh the sent requests list after successful deletion
        await fetchSentRequests();
        Get.back(); // Close the dialog
        Get.snackbar(
          'Success',
          'Request deleted successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        return true;
      } else {
        errorMessage.value = 'Failed to delete sent request: ${response.body}';
        return false;
      }
    } catch (e) {
      errorMessage.value = e.toString();
      return false;
    }
  }

  // Add method to get meeting status
  String getMeetingStatus(DateTime scheduledTime, String currentStatus) {
    final now = currentTime.value;
    final adjustedScheduledTime =
        scheduledTime.subtract(const Duration(hours: 5, minutes: 30));
    final minutesDifference = now.difference(adjustedScheduledTime).inMinutes;

    if (minutesDifference > 30) {
      if (currentStatus == 'completed') return 'Completed';
      if (currentStatus == 'cancelled') return 'Cancelled';
      return 'Expired';
    }

    if (minutesDifference >= 0 && minutesDifference <= 30) {
      if (currentStatus == 'completed') return 'Completed';
      if (currentStatus == 'cancelled') return 'Cancelled';
      return 'Join Now';
    }

    return 'Scheduled';
  }

  // Add this method to update time in a controlled way
  void updateCurrentTime() {
    currentTime.value = DateTime.now();
    // Update meeting statuses if needed without rebuilding the entire list
    if (meetings.isNotEmpty) {
      refreshMeetingStatuses();
    }
  }

  // Add this method to refresh only meeting statuses without rebuilding the entire list
  void refreshMeetingStatuses() {
    // This will trigger a more targeted update
    meetings.refresh();
  }

  // Add this method for a non-reactive access to meetings
  List<Map<String, dynamic>> getMeetingsSnapshot() {
    return List<Map<String, dynamic>>.from(meetings);
  }
}
