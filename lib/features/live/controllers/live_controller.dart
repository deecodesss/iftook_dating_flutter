import 'dart:convert';
import 'package:get/get.dart';
import 'package:iftook/core/services/api_service.dart';
import 'package:iftook/core/services/shared_prefs.dart';
import 'package:iftook/features/live/models/live_stream.dart';
import 'package:iftook/features/live/models/subscription.dart';

class LiveController extends GetxController {
  var isLoading = false.obs;
  var errorMessage = ''.obs;
  var activeStreams = <LiveStream>[].obs;
  var currentLiveStream = Rx<LiveStream?>(null);
  var userSubscriptions = <Subscription>[].obs;
  var isInitialized = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchActiveLiveStreams();
    fetchUserSubscriptions();
  }

  Future<void> fetchActiveLiveStreams() async {
    try {
      isLoading(true);
      errorMessage('');

      final response = await ApiService.getActiveLiveStreams();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final liveStreams = List<LiveStream>.from(
              data['data']['liveStreams'].map((x) => LiveStream.fromJson(x)));
          activeStreams.value = liveStreams;
        }
      } else {
        final data = jsonDecode(response.body);
        errorMessage(data['message'] ?? 'Failed to load live streams');
      }
    } catch (e) {
      errorMessage('An error occurred: $e');
    } finally {
      isLoading(false);
    }
  }

  Future<LiveStream?> startLiveStream({
    String title = 'Live Stream',
    String description = '',
  }) async {
    try {
      isLoading(true);
      errorMessage('');

      final response = await ApiService.startLiveStream(
        title: title,
        description: description,
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final liveStream = LiveStream.fromJson(data['data']);
          currentLiveStream.value = liveStream;
          return liveStream;
        }
      } else {
        final data = jsonDecode(response.body);
        if (data['data'] != null) {
          // If user already has a live stream, return it
          currentLiveStream.value = LiveStream.fromJson(data['data']);
          return currentLiveStream.value;
        }
        errorMessage(data['message'] ?? 'Failed to start live stream');
      }
      return null;
    } catch (e) {
      errorMessage('An error occurred: $e');
      return null;
    } finally {
      isLoading(false);
    }
  }

  Future<bool> endLiveStream(String liveStreamId) async {
    try {
      isLoading(true);
      errorMessage('');

      final response = await ApiService.endLiveStream(liveStreamId);

      if (response.statusCode == 200) {
        currentLiveStream.value = null;
        return true;
      } else {
        final data = jsonDecode(response.body);
        errorMessage(data['message'] ?? 'Failed to end live stream');
        return false;
      }
    } catch (e) {
      errorMessage('An error occurred: $e');
      return false;
    } finally {
      isLoading(false);
    }
  }

  Future<Map<String, dynamic>?> joinLiveStream(String liveStreamId) async {
    try {
      isLoading(true);
      errorMessage('');

      final response = await ApiService.joinLiveStream(liveStreamId);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data'];
        }
      } else {
        final data = jsonDecode(response.body);
        errorMessage(data['message'] ?? 'Failed to join live stream');

        // If subscription is required, return the subscription details
        if (data['subscriptionRequired'] == true) {
          return {
            'subscriptionRequired': true,
            'subscriptionPrice': data['subscriptionPrice'],
            'broadcasterId': data['broadcasterId'],
          };
        }
      }
      return null;
    } catch (e) {
      errorMessage('An error occurred: $e');
      return null;
    } finally {
      isLoading(false);
    }
  }

  Future<bool> leaveLiveStream(String liveStreamId) async {
    try {
      final response = await ApiService.leaveLiveStream(liveStreamId);
      return response.statusCode == 200;
    } catch (e) {
      errorMessage('An error occurred: $e');
      return false;
    }
  }

  Future<bool> subscribeToCreator(String creatorId) async {
    try {
      isLoading(true);
      errorMessage('');

      // Generate a unique payment ID
      final userId = await SharedPrefs.getUserIdSharedPreference();
      final paymentId =
          'sub_${userId}_${creatorId}_${DateTime.now().millisecondsSinceEpoch}';

      final response =
          await ApiService.subscribeToCreator(creatorId, paymentId);

      if (response.statusCode == 201) {
        await fetchUserSubscriptions();
        return true;
      } else {
        final data = jsonDecode(response.body);
        errorMessage(data['message'] ?? 'Failed to subscribe');
        return false;
      }
    } catch (e) {
      errorMessage('An error occurred: $e');
      return false;
    } finally {
      isLoading(false);
    }
  }

  Future<void> fetchUserSubscriptions() async {
    try {
      final response = await ApiService.getUserSubscriptions();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          // Safely convert data to list of Subscription objects
          try {
            final List<dynamic> subscriptionsJson = data['data'];
            final subscriptions =
                subscriptionsJson.map((x) => Subscription.fromJson(x)).toList();
            userSubscriptions.value = subscriptions;
          } catch (e) {
            print('Error parsing subscription data: $e');
            // Initialize with empty list instead of leaving as null
            userSubscriptions.value = [];
          }
        } else {
          // If no data or success is false, initialize with empty list
          userSubscriptions.value = [];
        }
      } else {
        // Handle API error
        userSubscriptions.value = [];
        print('API error fetching subscriptions: ${response.statusCode}');
      }
    } catch (e) {
      // Set empty list and log error
      userSubscriptions.value = [];
      print('Error fetching subscriptions: $e');
    }
  }

  Future<LiveStream?> getUserActiveLiveStream(String userId) async {
    try {
      final response = await ApiService.getUserActiveLiveStream(userId);
      print('GET USER LIVE STREAM RESPONSE: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          try {
            print('User is live: ${data['data']}');
            final liveStream = LiveStream.fromJson(data['data']);
            print('Successfully parsed LiveStream object: ${liveStream.id}');
            return liveStream;
          } catch (parseError) {
            print('Error parsing LiveStream object: $parseError');
            // Create a simpler LiveStream object with minimal data
            if (data['data']['_id'] != null &&
                data['data']['broadcaster'] != null) {
              return LiveStream(
                id: data['data']['_id'],
                broadcasterId: data['data']['broadcaster'] is Map
                    ? data['data']['broadcaster']['_id']
                    : data['data']['broadcaster'],
                title: data['data']['title'] ?? 'Live Stream',
                description: data['data']['description'] ?? '',
                status: data['data']['status'] ?? 'active',
                startTime: DateTime.now(),
                viewers: [],
                channelName: data['data']['channelName'] ?? '',
                agoraToken: data['data']['agoraToken'] ?? '',
                tags: [],
                maxDuration: data['data']['maxDuration'] ?? 3600,
              );
            }
          }
        }
      } else {
        print(
            'User not live. Status code: ${response.statusCode}, Body: ${response.body}');
      }
      return null;
    } catch (e) {
      print('Error fetching user live stream: $e');
      return null;
    }
  }

  bool hasSubscription(String creatorId) {
    // Check if creatorId is empty, return false
    if (creatorId.isEmpty) return false;

    // Check if the current user has an active subscription to this creator
    return userSubscriptions
        .any((sub) => sub.creatorId == creatorId && sub.isActive);
  }
}
