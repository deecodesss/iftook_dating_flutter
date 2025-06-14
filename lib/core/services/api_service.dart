import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:iftook/core/services/shared_prefs.dart';
import 'package:iftook/features/friends/data/chatroom.dart';
import 'package:iftook/features/auth/presentation/screens/login_screen.dart';
import 'package:iftook/helpers/app_constants.dart';

import '../../features/friends/data/message.dart';

class ApiService {
  static const String baseUrl = AppConstants.BASE_URL;

  static Future<bool> refreshToken() async {
    try {
      final refreshToken = await SharedPrefs.getRefreshToken();
      if (refreshToken == null) return false;

      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Save both new tokens
        await SharedPrefs.saveTokens(
          data['accessToken'],
          data['refreshToken'],
        );
        return true;
      } else if (response.statusCode == 401) {
        await SharedPrefs.clearTokens();
        return false;
      }
      return false;
    } catch (e) {
      print('Error refreshing token: $e');
      return false;
    }
  }

  static Future<http.Response> authenticatedRequest(
    Future<http.Response> Function() requestFunction,
  ) async {
    try {
      var response = await requestFunction();

      if (response.statusCode == 401) {
        final refreshed = await refreshToken();
        if (refreshed) {
          response = await requestFunction();
        } else {
          // Clear all tokens and redirect to login
          await SharedPrefs.clearUserSharedPreferences();
          Get.offAll(() => const LoginScreen());
          throw Exception('Session expired');
        }
      }

      return response;
    } catch (e) {
      rethrow;
    }
  }

  static Future<http.Response> register(Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    print(response.body);
    return response;
  }

  static Future<http.Response> login(Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] && responseData['accessToken'] != null) {
          await SharedPrefs.saveTokens(
            responseData['accessToken'],
            responseData['refreshToken'],
          );
        }
      }

      return response;
    } catch (e) {
      print('Login error in API service: $e');
      rethrow;
    }
  }

  static Future<http.Response> fetchMyProfile() async {
    final token = await SharedPrefs.getAccessToken();
    return authenticatedRequest(() => http.get(
          Uri.parse('$baseUrl/users/profile'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ));
  }

  static Future<http.Response> searchUsers(String query) async {
    final token = await SharedPrefs.getAccessToken();

    return authenticatedRequest(() => http.get(
          Uri.parse('$baseUrl/users/search?search=$query'),
          headers: {'Authorization': 'Bearer $token'},
        ));
  }

  static Future<http.Response> addFriend(Map<String, dynamic> body) async {
    final token = await SharedPrefs.getAccessToken();

    return authenticatedRequest(() => http.post(
          Uri.parse('$baseUrl/friend/requests/send'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token'
          },
          body: jsonEncode(body),
        ));
  }

  static Future<http.Response> getFriendRequests() async {
    final token = await SharedPrefs.getAccessToken();
    final userId = await SharedPrefs.getUserIdSharedPreference();
    print("userid: $userId");

    return authenticatedRequest(() => http.get(
          Uri.parse('$baseUrl/friend/requests/$userId'),
          headers: {'Authorization': 'Bearer $token'},
        ));
  }

  static Future<http.Response> getRatings(String creator) async {
    final token = await SharedPrefs.getAccessToken();
    return authenticatedRequest(() => http.get(
          Uri.parse('$baseUrl/ratings/$creator'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ));
  }

  static Future<http.Response> addRating(
    String userId,
    Map<String, double> ratings,
    String review,
  ) async {
    final token = await SharedPrefs.getAccessToken();
    final currentUserId = await SharedPrefs.getUserIdSharedPreference();

    print('Adding rating for user: $userId by reviewer: $currentUserId');

    final ratingData = {
      'creator': userId, // Changed from userId to creator
      'reviewer': currentUserId,
      'politeness': ratings['Politeness'],
      'communication': ratings['Communication'],
      'professionalism': ratings['Professionalism'],
      'punctuality': ratings['Punctuality'],
      'review': review,
    };

    print('Sending rating data: $ratingData');

    return authenticatedRequest(() => http.post(
          Uri.parse('$baseUrl/ratings/add'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(ratingData),
        ));
  }

  static Future<http.Response> getSentFriendRequests() async {
    final token = await SharedPrefs.getAccessToken();
    final userId = await SharedPrefs.getUserIdSharedPreference();

    return authenticatedRequest(() => http.get(
          Uri.parse('$baseUrl/friend/requests/sent/$userId'),
          headers: {'Authorization': 'Bearer $token'},
        ));
  }

  static Future<http.Response> getFriendList() async {
    final token = await SharedPrefs.getAccessToken();
    final userId = await SharedPrefs.getUserIdSharedPreference();
    print("userid: $userId");

    return authenticatedRequest(() => http.get(
          Uri.parse('$baseUrl/friend/list/$userId'),
          headers: {'Authorization': 'Bearer $token'},
        ));
  }

  static Future<http.Response> acceptFriendRequest(String requestId) async {
    final token = await SharedPrefs.getAccessToken();

    return authenticatedRequest(() => http.put(
          Uri.parse('$baseUrl/friend/requests/accept/$requestId'),
          headers: {'Authorization': 'Bearer $token'},
        ));
  }

  static Future<http.Response> declineFriendRequest(String requestId) async {
    final token = await SharedPrefs.getAccessToken();

    return authenticatedRequest(() => http.delete(
          Uri.parse('$baseUrl/friend/requests/delete/$requestId'),
          headers: {'Authorization': 'Bearer $token'},
        ));
  }

  static Future<http.Response> removeFriend(
      String userId, String friendId) async {
    final token = await SharedPrefs.getAccessToken();

    return authenticatedRequest(() => http.delete(
          Uri.parse('$baseUrl/friend/remove/$userId/$friendId'),
          headers: {'Authorization': 'Bearer $token'},
        ));
  }

  static Future<http.Response> deleteSentRequest(String requestId) async {
    final token = await SharedPrefs.getAccessToken();

    return authenticatedRequest(() => http.delete(
          Uri.parse('$baseUrl/friend/requests/delete/$requestId'),
          headers: {'Authorization': 'Bearer $token'},
        ));
  }

  Future<Chatroom> createOrGetChatRoom(
      String userId, String participantId) async {
    final token = await SharedPrefs.getAccessToken();

    final response = await authenticatedRequest(() => http.post(
          Uri.parse('$baseUrl/chat-room'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token'
          },
          body: jsonEncode({'userId': userId, 'participantId': participantId}),
        ));

    print(response.body);

    if (response.statusCode == 200) {
      return Chatroom.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create or get chat room');
    }
  }

  Future<List<Message>> getAllMsgsOfChatRoom(String chatRoomId) async {
    final token = await SharedPrefs.getAccessToken();

    final response = await authenticatedRequest(() => http.get(
          Uri.parse('$baseUrl/chat-room/$chatRoomId/messages'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token'
          },
        ));

    if (response.statusCode == 200) {
      List<dynamic> messagesJson =
          jsonDecode(response.body)['data']['messages'];
      return messagesJson.map((json) => Message.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load messages');
    }
  }

  Future<void> sendMessage(
      String senderId, String chatRoomId, String text) async {
    final token = await SharedPrefs.getAccessToken();

    final response = await authenticatedRequest(() => http.post(
          Uri.parse('$baseUrl/chat-room/message/send'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token'
          },
          body: jsonEncode({
            'senderId': senderId,
            'chatRoomId': chatRoomId,
            'text': text,
          }),
        ));

    if (response.statusCode != 200) {
      throw Exception('Failed to send message');
    }
  }

  static Future<http.Response> fetchDatingFeed() async {
    final token = await SharedPrefs.getAccessToken();

    return authenticatedRequest(() => http.get(
          Uri.parse('$baseUrl/users/feed'),
          headers: {'Authorization': 'Bearer $token'},
        ));
  }

  static Future<http.Response> fetchUSerWallet() async {
    final token = await SharedPrefs.getAccessToken();

    final userId = await SharedPrefs.getUserIdSharedPreference();

    return authenticatedRequest(() => http.get(
          Uri.parse('$baseUrl/users/wallet/$userId'),
          headers: {'Authorization': 'Bearer $token'},
        ));
  }

  static Future<http.Response> makePayment(double amount) async {
    final token = await SharedPrefs.getAccessToken();

    return authenticatedRequest(() => http.post(
          Uri.parse('$baseUrl/payments/create'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'amount': amount}),
        ));
  }

  static Future<http.Response> verifyPayment(String merchantReferenceId) async {
    final token = await SharedPrefs.getAccessToken();

    return authenticatedRequest(() => http.get(
          Uri.parse('$baseUrl/payments/verify/$merchantReferenceId'),
          headers: {
            'Authorization': 'Bearer $token',
          },
        ));
  }

  static Future<http.Response> addMoneyToWallet(
      double amount, String paymentId) async {
    final token = await SharedPrefs.getAccessToken();
    final userId = await SharedPrefs.getUserIdSharedPreference();

    return authenticatedRequest(() => http.put(
          Uri.parse(
              '$baseUrl/users/wallet/add/$userId'), // Update the endpoint as per your API
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'paymentId': paymentId,
            'amount': amount
          }), // Pass the amount in the body
        ));
  }

  static Future<http.Response> deductMoneyToWallet(double amount) async {
    final token = await SharedPrefs.getAccessToken();
    final userId = await SharedPrefs.getUserIdSharedPreference();

    return authenticatedRequest(() => http.put(
          Uri.parse(
              '$baseUrl/users/wallet/deduct/$userId'), // Update the endpoint as per your API
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'amount': amount}), // Pass the amount in the body
        ));
  }

  static Future<http.Response> addMoneyToReceiverWallet(
      double amount, String receiverId) async {
    final token = await SharedPrefs.getAccessToken();

    return authenticatedRequest(() => http.put(
          Uri.parse(
              '$baseUrl/users/wallet/give/$receiverId'), // Update the endpoint as per your API
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'amount': amount}), // Pass the amount in the body
        ));
  }

  static Future<http.Response> updateFCMToken(String fcmToken) async {
    String? token = await SharedPrefs.getAccessToken();
    try {
      print("$baseUrl/users/device-token/update");
      Map<String, dynamic> data = {
        "fcmToken": fcmToken,
      };
      print(data);
      final response = await authenticatedRequest(() => http.put(
            Uri.parse(
              "$baseUrl/users/device-token/update",
            ),
            body: jsonEncode(data),
            headers: {
              "Content-Type": "application/json",
              "Accept": "application/json",
              'Authorization': 'Bearer $token',
            },
          ));

      print(response.body);
      return response;
    } catch (err) {
      throw Exception(err.toString());
    }
  }

  static Future<http.Response> initiateCall(String participantId, String type,
      DateTime scheduleTime, bool isInstatalk) async {
    final token = await SharedPrefs.getAccessToken();
    final userId = await SharedPrefs.getUserIdSharedPreference();
    Map<String, dynamic> data = {
      "userId": userId,
      "participantId": participantId,
      "type": type,
      "scheduledTime": scheduleTime.toIso8601String(),
      "isInstatalk": isInstatalk, // Assuming this is an InstaTalk call
    };

    print('Initiating call with data: $data');
    print('Token: $token');

    return authenticatedRequest(() => http.post(
          Uri.parse('$baseUrl/meeting/create-meeting'),
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(data),
        ));
  }

  static Future<http.Response> createMeeting(String participantId, String type,
      DateTime scheduleTime, double duration, bool isFriend) async {
    final token = await SharedPrefs.getAccessToken();
    final userId = await SharedPrefs.getUserIdSharedPreference();

    Map<String, dynamic> data = {
      "userId": userId,
      "participantId": participantId,
      "type": type,
      "scheduledTime": scheduleTime.toIso8601String(),
      "duration": duration, // Default duration
      "isFriend": isFriend,
    };

    print('Creating meeting with data: $data');

    return authenticatedRequest(() => http.post(
          Uri.parse('$baseUrl/meeting/create-meeting'),
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(data),
        ));
  }

  static Future<http.Response> initiateNormalMeetingCall(
      String participantId,
      String type,
      DateTime scheduleTime,
      String meetingId,
      double duration) async {
    final token = await SharedPrefs.getAccessToken();
    final userId = await SharedPrefs.getUserIdSharedPreference();

    Map<String, dynamic> data = {
      "userId": userId,
      "participantId": participantId,
      "type": type,
      "scheduledTime": scheduleTime.toIso8601String(),
      "duration": duration, // Default duration
      "meetingId": meetingId, // Include meetingId if needed
    };

    print('Creating meeting with data: $data');

    return authenticatedRequest(() => http.post(
          Uri.parse('$baseUrl/meeting/initiateNormalCall'),
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(data),
        ));
  }

  static Future<http.Response> createScheduledMeeting(
      String participantId, String type, DateTime scheduleTime) async {
    final token = await SharedPrefs.getAccessToken();
    final userId = await SharedPrefs.getUserIdSharedPreference();

    Map<String, dynamic> data = {
      "userId": userId,
      "participantId": participantId,
      "type": type,
      "scheduledTime": scheduleTime.toIso8601String(),
      "duration": 30, // Default duration
    };

    print('Creating meeting with data: $data');

    return authenticatedRequest(() => http.post(
          Uri.parse('$baseUrl/meeting/create-meeting-request'),
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(data),
        ));
  }

  static Future<http.Response> updateMeetingStatus(
      String meetingId, String status) async {
    final token = await SharedPrefs.getAccessToken();
    return authenticatedRequest(() => http.put(
          Uri.parse('$baseUrl/meeting/$meetingId'),
          headers: {
            "Content-Type": "application/json",
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'status': status}),
        ));
  }

  static Future<http.Response> getUserMeetings(String userId) async {
    final token = await SharedPrefs.getAccessToken();

    return authenticatedRequest(() => http.get(
          Uri.parse('$baseUrl/meeting/$userId'),
          headers: {
            'Authorization': 'Bearer $token',
          },
        ));
  }

  static Future<http.Response> getUserInstaTalks(String userId) async {
    final token = await SharedPrefs.getAccessToken();
    final Duration timeout = Duration(seconds: 15);
    int retryCount = 0;
    const maxRetries = 2;

    while (retryCount <= maxRetries) {
      try {
        print('🌐 [API] Starting InstaTalk fetch for user: $userId');
        final url = '$baseUrl/insta-talk/$userId';
        print('🌐 [API] Using URL: $url');
        print('🌐 [API] Token available: ${token != null}');

        final response = await authenticatedRequest(() => http.get(
              Uri.parse(url),
              headers: {
                'Authorization': 'Bearer $token',
                'Accept': 'application/json',
              },
            ));

        print('🌐 [API] Response received - Status: ${response.statusCode}');
        print('🌐 [API] Response body: ${response.body}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final talks = data['meetings']
              as List?; // Changed from 'instaTalks' to 'meetings'
          print('🌐 [API] Parsed ${talks?.length ?? 0} InstaTalk requests');
          print('🌐 [API] Talks data: $talks');
          return response;
        }

        throw HttpException('Failed with status: ${response.statusCode}');
      } catch (e) {
        retryCount++;
        print('🌐 [API] Error on attempt $retryCount: $e');
        if (retryCount > maxRetries) rethrow;
        await Future.delayed(Duration(seconds: pow(2, retryCount).toInt()));
      }
    }

    throw Exception('Failed after $maxRetries retries');
  }

  static Future<http.Response> sendOtp(String email) async {
    return authenticatedRequest(() => http.post(
          Uri.parse('$baseUrl/auth/send-otp'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email}),
        ));
  }

  static Future<http.Response> getUserById(String userId) async {
    try {
      final token = await SharedPrefs.getAccessToken();
      print('Fetching user profile for ID: $userId');

      final response = await authenticatedRequest(() => http.get(
            Uri.parse('$baseUrl/users/profile/$userId'),
            headers: {
              'Authorization': 'Bearer $token',
            },
          ));

      print('User profile response status: ${response.statusCode}');
      print('User profile response body: ${response.body}');
      return response;
    } catch (e) {
      print('Error in getUserById: $e');
      rethrow; // Rethrow to handle in the UI
    }
  }

  static Future<http.Response> addToWishlist(String userId) async {
    final token = await SharedPrefs.getAccessToken();

    return authenticatedRequest(() => http.post(
          Uri.parse('$baseUrl/users/wishlist/add'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'userId': userId}),
        ));
  }

  static Future<http.Response> removeFromWishlist(String userId) async {
    final token = await SharedPrefs.getAccessToken();

    return authenticatedRequest(() => http.delete(
          Uri.parse('$baseUrl/users/wishlist/remove/$userId'),
          headers: {
            'Authorization': 'Bearer $token',
          },
        ));
  }

  static Future<http.Response> getWishlist() async {
    final token = await SharedPrefs.getAccessToken();

    return authenticatedRequest(() => http.get(
          Uri.parse('$baseUrl/users/wishlist'),
          headers: {
            'Authorization': 'Bearer $token',
          },
        ));
  }

  static Future<http.Response> updateProfile(Map<String, dynamic> data) async {
    final token = await SharedPrefs.getAccessToken();

    return authenticatedRequest(() => http.put(
          Uri.parse('$baseUrl/users/update'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(data),
        ));
  }

  // Live streaming endpoints
  static Future<http.Response> startLiveStream(
      {String title = 'Live Stream', String description = ''}) async {
    final token = await SharedPrefs.getAccessToken();

    return authenticatedRequest(() => http.post(
          Uri.parse('$baseUrl/live-stream/start'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'title': title,
            'description': description,
          }),
        ));
  }

  static Future<http.Response> endLiveStream(String liveStreamId) async {
    final token = await SharedPrefs.getAccessToken();

    return authenticatedRequest(() => http.put(
          Uri.parse('$baseUrl/live-stream/end/$liveStreamId'),
          headers: {
            'Authorization': 'Bearer $token',
          },
        ));
  }

  static Future<http.Response> getActiveLiveStreams({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final token = await SharedPrefs.getAccessToken();
      final response = await authenticatedRequest(() => http.get(
            Uri.parse('$baseUrl/live-stream/active?page=$page&limit=$limit'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          ));

      print('Get active live streams response: ${response.body}');
      return response;
    } catch (e) {
      print('Error in getActiveLiveStreams: $e');
      rethrow;
    }
  }

  static Future<http.Response> joinLiveStream(String liveStreamId) async {
    final token = await SharedPrefs.getAccessToken();

    return authenticatedRequest(() => http.post(
          Uri.parse('$baseUrl/live-stream/join/$liveStreamId'),
          headers: {
            'Authorization': 'Bearer $token',
          },
        ));
  }

  static Future<http.Response> leaveLiveStream(String liveStreamId) async {
    final token = await SharedPrefs.getAccessToken();

    return authenticatedRequest(() => http.post(
          Uri.parse('$baseUrl/live-stream/leave/$liveStreamId'),
          headers: {
            'Authorization': 'Bearer $token',
          },
        ));
  }

  static Future<http.Response> subscribeToCreator(
      String creatorId, String paymentId) async {
    final token = await SharedPrefs.getAccessToken();

    return authenticatedRequest(() => http.post(
          Uri.parse('$baseUrl/live-stream/subscribe/$creatorId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'paymentId': paymentId,
          }),
        ));
  }

  static Future<http.Response> getUserActiveLiveStream(String userId) async {
    final token = await SharedPrefs.getAccessToken();

    return authenticatedRequest(() => http.get(
          Uri.parse('$baseUrl/live-stream/user/$userId'),
          headers: {
            'Authorization': 'Bearer $token',
          },
        ));
  }

  static Future<http.Response> getUserSubscriptions() async {
    final token = await SharedPrefs.getAccessToken();

    return authenticatedRequest(() => http.get(
          Uri.parse('$baseUrl/live-stream/subscriptions'),
          headers: {
            'Authorization': 'Bearer $token',
          },
        ));
  }

  static Future<bool> checkIsFriend(String otherUserId) async {
    try {
      final token = await SharedPrefs.getAccessToken();
      final userId = await SharedPrefs.getUserIdSharedPreference();

      final response = await authenticatedRequest(() => http.get(
            Uri.parse('$baseUrl/friend/check-status/$userId/$otherUserId'),
            headers: {'Authorization': 'Bearer $token'},
          ));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['isFriend'] == true;
      }
      return false;
    } catch (e) {
      print('Error checking friendship status: $e');
      return false;
    }
  }

  // InstaTalk API methods
  static Future<http.Response> createInstaTalk(
      String participantId, String type) async {
    final url = Uri.parse('$baseUrl/insta-talk/create-meeting');
    final userId = await SharedPrefs.getUserIdSharedPreference();
    final token = await SharedPrefs.getAccessToken();

    final body = {
      'userId': userId,
      'participantId': participantId,
      'type': type,
      'scheduledTime': DateTime.now().toIso8601String(),
    };

    print('Creating InstaTalk: $body');

    return authenticatedRequest(() => http.post(
          url,
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
            'Authorization': 'Bearer $token',
          },
          body: json.encode(body),
        ));
  }

  // Check if trial used
  static Future<http.Response> checkIfTrialUsed(
      String participantId, String userId) async {
    final url = Uri.parse('$baseUrl/insta-talk/checkExistingInstaTalk');
    final token = await SharedPrefs.getAccessToken();

    // Ensure userId is a string and not a Future
    if (userId == null) {
      throw Exception('User ID is null');
    }

    // Log the actual values being sent
    print(
        'Checking InstaTalk trial with userId: $userId and participantId: $participantId');

    final body = {
      'userId': userId,
      'participantId': participantId,
    };

    // Make the API call and return the response
    return authenticatedRequest(() => http.post(
          url,
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
            'Authorization': 'Bearer $token',
          },
          body: json.encode(body),
        ));
  }

  static Future<http.Response> acceptInstaTalk(
      String meetingId, String userId) async {
    final url = Uri.parse('$baseUrl/insta-talk/$meetingId/accept');
    final token = await SharedPrefs.getAccessToken();

    return authenticatedRequest(() => http.put(
          url,
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
            'Authorization': 'Bearer $token',
          },
          body: json.encode({
            'userId': userId,
          }),
        ));
  }

  static Future<http.Response> updateInstaTalkTimeUsage({
    required String meetingId,
    required String userId,
    required bool isUserOne,
  }) async {
    try {
      final token = await SharedPrefs.getAccessToken();
      final String fieldToUpdate =
          isUserOne ? 'userOneTimeUsed' : 'userTwoTimeUsed';

      print(
          'Updating InstaTalk time usage: ${meetingId} - Field: ${fieldToUpdate}');

      final response = await authenticatedRequest(() => http.patch(
            Uri.parse('$baseUrl/insta-talk/$meetingId/time-usage'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'userId': userId, 'field': fieldToUpdate}),
          ));

      print('Update response: ${response.statusCode} - ${response.body}');
      return response;
    } catch (e) {
      print('Error updating InstaTalk time usage: $e');
      rethrow;
    }
  }

  static Future<http.Response> renewInstatalk({
    required String meetingId,
    required String userId,
    required bool isUserOne,
  }) async {
    try {
      final token = await SharedPrefs.getAccessToken();
      final String fieldToUpdate =
          isUserOne ? 'userOneTimeUsed' : 'userTwoTimeUsed';

      print(
          'Updating InstaTalk time usage: ${meetingId} - Field: ${fieldToUpdate}');

      final response = await authenticatedRequest(() => http.patch(
            Uri.parse('$baseUrl/insta-talk/$meetingId/renew'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(
                // {'userId': userId, 'field': fieldToUpdate, 'duration': 1}),
                {
                  'userId': userId,
                  'userOneTimeUsed': false,
                  'userTwoTimeUsed': false,
                  'duration': 1
                }),
          ));

      print('Update response: ${response.statusCode} - ${response.body}');
      return response;
    } catch (e) {
      print('Error updating InstaTalk time usage: $e');
      rethrow;
    }
  }

  static Future<http.Response> checkInstaTalkStatus(
      String participantId) async {
    final userId = await SharedPrefs.getUserIdSharedPreference();
    final token = await SharedPrefs.getAccessToken();
    final url = Uri.parse(
        '$baseUrl/insta-talk/check-status?userId=$userId&participantId=$participantId');

    return authenticatedRequest(() => http.get(
          url,
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
            'Authorization': 'Bearer $token',
          },
        ));
  }

  static Future<http.Response> declineInstaTalk(
      String meetingId, String userId) async {
    final url = Uri.parse('$baseUrl/insta-talk/$meetingId/decline');
    final token = await SharedPrefs.getAccessToken();

    return authenticatedRequest(() => http.put(
          url,
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
            'Authorization': 'Bearer $token',
          },
          body: json.encode({
            'userId': userId,
          }),
        ));
  }

  static Future<http.Response> transferToBank(Map<String, dynamic> data) async {
    final token = await SharedPrefs.getAccessToken();

    return authenticatedRequest(() => http.post(
          Uri.parse('$baseUrl/payments/transfer-to-bank'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(data),
        ));
  }

  static Future<http.Response> checkTransferStatus(String orderId) async {
    final token = await SharedPrefs.getAccessToken();

    return authenticatedRequest(() => http.post(
          Uri.parse('$baseUrl/payments/transfer-status'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'orderId': orderId}),
        ));
  }

  static Future<http.Response> getMeetingStatus(String meetingId) async {
    final token = await SharedPrefs.getAccessToken();
    return authenticatedRequest(() => http.get(
          Uri.parse('$baseUrl/meeting/status/$meetingId'),
          headers: {
            'Authorization': 'Bearer $token',
          },
        ));
  }

  static Future<http.Response> getCurrentMeeting(String meetingId) async {
    final token = await SharedPrefs.getAccessToken();
    return authenticatedRequest(() => http.get(
          Uri.parse('$baseUrl/meeting/status/$meetingId'),
          headers: {
            'Authorization': 'Bearer $token',
          },
        ));
  }

  static Future<http.Response> rejectCall(
      String meetingId, Map<String, dynamic> rejectionData) async {
    final token = await SharedPrefs.getAccessToken();

    return authenticatedRequest(() => http.post(
          Uri.parse('$baseUrl/meeting/reject/$meetingId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(rejectionData),
        ));
  }

  static Future<http.Response> getCallStatus(String meetingId) async {
    final token = await SharedPrefs.getAccessToken();

    return authenticatedRequest(() => http.get(
          Uri.parse('$baseUrl/meeting/status/$meetingId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ));
  }

  // Method to check if a user is online via API
  static Future<bool> isUserOnline(String userId) async {
    try {
      final token = await SharedPrefs.getAccessToken();

      final response = await authenticatedRequest(() => http.get(
            Uri.parse('$baseUrl/users/online-status/$userId'),
            headers: {
              'Authorization': 'Bearer $token',
            },
          ));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['isOnline'] ?? false;
      }

      return false;
    } catch (e) {
      print('Error checking online status: $e');
      return false;
    }
  }

  // Method to check if a user is in a call via API
  static Future<Map<String, dynamic>> isUserInCall(String userId) async {
    try {
      final token = await SharedPrefs.getAccessToken();

      final response = await authenticatedRequest(() => http.get(
            Uri.parse('$baseUrl/api/call-status/$userId'),
            headers: {
              'Authorization': 'Bearer $token',
            },
          ));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'inCall': data['inCall'] ?? false,
          'callType': data['callInfo']?['callType'],
          'meetingId': data['callInfo']?['meetingId'],
        };
      }

      return {'inCall': false};
    } catch (e) {
      print('Error checking call status: $e');
      return {'inCall': false};
    }
  }

  // Method to check multiple users' call status via API
  static Future<Map<String, Map<String, dynamic>>> checkBatchCallStatus(
      List<String> userIds) async {
    try {
      final token = await SharedPrefs.getAccessToken();

      final response = await authenticatedRequest(() => http.post(
            Uri.parse('$baseUrl/api/call-status/batch'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'userIds': userIds}),
          ));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final Map<String, Map<String, dynamic>> result = {};

        if (data.containsKey('statuses')) {
          final statuses = data['statuses'] as Map<String, dynamic>;

          statuses.forEach((userId, status) {
            result[userId] = {
              'inCall': status['inCall'] ?? false,
              'callType': status['callInfo']?['callType'],
              'meetingId': status['callInfo']?['meetingId'],
            };
          });
        }

        return result;
      }

      return {};
    } catch (e) {
      print('Error checking batch call status: $e');
      return {};
    }
  }

  // Get all users currently in calls
  static Future<List<Map<String, dynamic>>> getAllUsersInCalls() async {
    try {
      final token = await SharedPrefs.getAccessToken();

      final response = await authenticatedRequest(() => http.get(
            Uri.parse('$baseUrl/api/users-in-call'),
            headers: {
              'Authorization': 'Bearer $token',
            },
          ));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<Map<String, dynamic>> usersInCall = [];

        if (data.containsKey('usersInCall')) {
          final Map<String, dynamic> callData = data['usersInCall'];

          callData.forEach((userId, callInfo) {
            usersInCall.add({
              'userId': userId,
              'inCall': true,
              'callType': callInfo['callType'],
              'meetingId': callInfo['meetingId'],
              'joinedAt': callInfo['joinedAt'],
            });
          });
        }

        return usersInCall;
      }

      return [];
    } catch (e) {
      print('Error getting all users in calls: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> uploadImage(File imageFile) async {
    try {
      final token = await SharedPrefs.getAccessToken();

      // Check if file exists and is readable
      if (!imageFile.existsSync()) {
        print('Error: Image file does not exist: ${imageFile.path}');
        return {'success': false, 'message': 'Image file does not exist'};
      }

      final fileSize = await imageFile.length();
      final fileExtension = imageFile.path.split('.').last.toLowerCase();

      print('Uploading image: ${imageFile.path}');
      print('File size: ${fileSize ~/ 1024} KB');
      print('File extension: $fileExtension');

      // Validate file extension
      final validExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
      if (!validExtensions.contains(fileExtension)) {
        print('Error: Invalid file extension: $fileExtension');
        return {
          'success': false,
          'message': 'Invalid file type. Only images are allowed.'
        };
      }

      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload/image'),
      );

      // Add authorization header
      request.headers.addAll({
        'Authorization': 'Bearer $token',
      });

      // Add file to request with explicit mimetype
      final mimeType = 'image/$fileExtension'.replaceAll('jpg', 'jpeg');

      final multipartFile = await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
        filename: imageFile.path.split('/').last,
        contentType: MediaType.parse(mimeType),
      );

      request.files.add(multipartFile);

      // Send the request
      print('Sending image upload request with mimetype: $mimeType');
      final streamedResponse = await request.send();

      // Get the response
      final response = await http.Response.fromStream(streamedResponse);
      print('Image upload response status: ${response.statusCode}');
      print('Image upload response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'imageUrl': responseData['imageUrl'],
          'filename': responseData['filename'],
        };
      } else {
        print('Error uploading image: ${response.statusCode} ${response.body}');
        return {
          'success': false,
          'message': 'Failed to upload image: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Exception during image upload: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  // Post (Activity) API methods

  static Future<http.Response> createPost({
    required String photoUrl,
    String? caption,
  }) async {
    final token = await SharedPrefs.getAccessToken();
    final body = {
      'photo': photoUrl,
      if (caption != null) 'caption': caption,
    };
    return authenticatedRequest(() => http.post(
          Uri.parse('$baseUrl/posts'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        ));
  }

  static Future<http.Response> getPosts({int page = 1}) async {
    final token = await SharedPrefs.getAccessToken();
    return authenticatedRequest(() => http.get(
          Uri.parse('$baseUrl/posts?pageNumber=$page'),
          headers: {
            'Authorization': 'Bearer $token',
          },
        ));
  }

  static Future<http.Response> getPostById(String postId) async {
    final token = await SharedPrefs.getAccessToken();
    return authenticatedRequest(() => http.get(
          Uri.parse('$baseUrl/posts/$postId'),
          headers: {
            'Authorization': 'Bearer $token',
          },
        ));
  }

  static Future<http.Response> updatePost(String postId,
      {String? caption}) async {
    final token = await SharedPrefs.getAccessToken();
    final body = {
      if (caption != null) 'caption': caption,
      // Add other updatable fields if necessary
    };
    return authenticatedRequest(() => http.put(
          Uri.parse('$baseUrl/posts/$postId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        ));
  }

  static Future<http.Response> deletePost(String postId) async {
    final token = await SharedPrefs.getAccessToken();
    return authenticatedRequest(() => http.delete(
          Uri.parse('$baseUrl/posts/$postId'),
          headers: {
            'Authorization': 'Bearer $token',
          },
        ));
  }

  static Future<http.Response> likePost(String postId) async {
    final token = await SharedPrefs.getAccessToken();
    return authenticatedRequest(() => http.post(
          Uri.parse('$baseUrl/posts/$postId/like'),
          headers: {
            'Authorization': 'Bearer $token',
          },
        ));
  }

  static Future<http.Response> unlikePost(String postId) async {
    final token = await SharedPrefs.getAccessToken();
    return authenticatedRequest(() => http.post(
          Uri.parse('$baseUrl/posts/$postId/unlike'),
          headers: {
            'Authorization': 'Bearer $token',
          },
        ));
  }

  static Future<http.Response> addComment(String postId, String text) async {
    final token = await SharedPrefs.getAccessToken();
    final body = {'text': text};
    return authenticatedRequest(() => http.post(
          Uri.parse('$baseUrl/posts/$postId/comments'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        ));
  }

  static Future<http.Response> deleteComment(
      String postId, String commentId) async {
    final token = await SharedPrefs.getAccessToken();
    return authenticatedRequest(() => http.delete(
          Uri.parse('$baseUrl/posts/$postId/comments/$commentId'),
          headers: {
            'Authorization': 'Bearer $token',
          },
        ));
  }
}
