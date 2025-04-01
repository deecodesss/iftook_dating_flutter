import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:iftook/core/services/shared_prefs.dart';
import 'package:iftook/features/friends/data/chatroom.dart';

import '../../features/friends/data/message.dart';

class ApiService {
  // static const String baseUrl = 'https://iftook-backend.vercel.app/api';
  static const String baseUrl = 'https://iftookbackendcopy.vercel.app/api';
  // static const String baseUrl = 'http://localhost:3000/api';

  static Future<http.Response> register(Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body), // Ensure the body is JSON-encoded
    );
    print(response.body);
    return response;
  }

  static Future<http.Response> login(Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body), // Ensure the body is JSON-encoded
    );
    print(response.body);
    return response;
  }

  static Future<http.Response> fetchMyProfile() async {
    final token = await SharedPrefs.getUserTokenSharedPreference();
    final response = await http.get(
      Uri.parse('$baseUrl/users/profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    print(response.body);
    return response;
  }

  static Future<http.Response> searchUsers(String query) async {
    final token = await SharedPrefs.getUserTokenSharedPreference();

    final response = await http.get(
      Uri.parse('$baseUrl/users/search?search=$query'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return response;
  }

  static Future<http.Response> addFriend(Map<String, dynamic> body) async {
    final token = await SharedPrefs.getUserTokenSharedPreference();

    final response = await http.post(
      Uri.parse('$baseUrl/friend/requests/send'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: jsonEncode(body), // Ensure the body is JSON-encoded
    );
    print(response.body);
    return response;
  }

  static Future<http.Response> getFriendRequests() async {
    final token = await SharedPrefs.getUserTokenSharedPreference();
    final userId = await SharedPrefs.getUserIdSharedPreference();
    print("userid: $userId");

    final response = await http.get(
      Uri.parse('$baseUrl/friend/requests/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    print(response.body);
    return response;
  }

  static Future<http.Response> getRatings(String userId) async {
    final token = await SharedPrefs.getUserTokenSharedPreference();
    final userId = await SharedPrefs.getUserIdSharedPreference();
    print("userid: $userId");

    final response = await http.get(
      Uri.parse('$baseUrl/users/reviews/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    print(response.body);
    return response;
  }

  static Future<http.Response> submitRating(
    String userId,
    double rating,
    String review,
    String interactionType,
  ) async {
    final token = await SharedPrefs.getUserTokenSharedPreference();

    final response = await http.post(
      Uri.parse('$baseUrl/users/review/add'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'userId': userId,
        'rating': rating,
        'review': review,
        'interactionType': interactionType, // "chat", "voice", or "video"
      }),
    );
    print('Submit rating response: ${response.body}');
    return response;
  }

  static Future<http.Response> getSentFriendRequests() async {
    final token = await SharedPrefs.getUserTokenSharedPreference();
    final userId = await SharedPrefs.getUserIdSharedPreference();

    final response = await http.get(
      Uri.parse('$baseUrl/friend/requests/sent/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    print(
        "Sent Friend REQUESTS are here ---------------------------\n \n\n\n\n HERE" +
            response.body);
    return response;
  }

  static Future<http.Response> getFriendList() async {
    final token = await SharedPrefs.getUserTokenSharedPreference();
    final userId = await SharedPrefs.getUserIdSharedPreference();
    print("userid: $userId");

    final response = await http.get(
      Uri.parse('$baseUrl/friend/list/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    print(response.body);
    return response;
  }

  static Future<http.Response> acceptFriendRequest(String requestId) async {
    final token = await SharedPrefs.getUserTokenSharedPreference();

    final response = await http.put(
      Uri.parse('$baseUrl/friend/requests/accept/$requestId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    print(response.body);
    return response;
  }

  static Future<http.Response> declineFriendRequest(String requestId) async {
    final token = await SharedPrefs.getUserTokenSharedPreference();

    // final response = await http.put(
    final response = await http.delete(
      // Uri.parse('$baseUrl/friend/requests/reject/$requestId'),
      Uri.parse('$baseUrl/friend/requests/delete/$requestId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    print(response.body);
    return response;
  }

  static Future<http.Response> removeFriend(
      String userId, String friendId) async {
    final token = await SharedPrefs.getUserTokenSharedPreference();

    final response = await http.delete(
      Uri.parse('$baseUrl/friend/remove/$userId/$friendId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    print(response.body);
    return response;
  }

  static Future<http.Response> deleteSentRequest(String requestId) async {
    final token = await SharedPrefs.getUserTokenSharedPreference();

    final response = await http.delete(
      Uri.parse('$baseUrl/friend/requests/delete/$requestId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    print('Delete response: ${response.body}');
    return response;
  }

  Future<Chatroom> createOrGetChatRoom(
      String userId, String participantId) async {
    final token = await SharedPrefs.getUserTokenSharedPreference();

    final response = await http.post(
      Uri.parse('$baseUrl/chat-room'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: jsonEncode({'userId': userId, 'participantId': participantId}),
    );
    print(response.body);

    if (response.statusCode == 200) {
      return Chatroom.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create or get chat room');
    }
  }

  Future<List<Message>> getAllMsgsOfChatRoom(String chatRoomId) async {
    final token = await SharedPrefs.getUserTokenSharedPreference();

    final response = await http.get(
      Uri.parse('$baseUrl/chat-room/$chatRoomId/messages'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
    );
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
    final token = await SharedPrefs.getUserTokenSharedPreference();

    final response = await http.post(
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
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to send message');
    }
  }

  static Future<http.Response> fetchDatingFeed() async {
    final token = await SharedPrefs.getUserTokenSharedPreference();

    final response = await http.get(
      Uri.parse('$baseUrl/users/feed'),
      headers: {'Authorization': 'Bearer $token'},
    );
    print("feed");
    print(response.body);
    return response;
  }

  static Future<http.Response> fetchUSerWallet() async {
    final token = await SharedPrefs.getUserTokenSharedPreference();

    final userId = await SharedPrefs.getUserIdSharedPreference();

    final response = await http.get(
      Uri.parse('$baseUrl/users/wallet/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    print("feed");
    print(response.body);
    return response;
  }

  static Future<http.Response> makePayment(double amount) async {
    final token = await SharedPrefs.getUserTokenSharedPreference();
    final userId = await SharedPrefs.getUserIdSharedPreference();

    final response = await http.post(
      Uri.parse(
          '$baseUrl/payments/create'), // Update the endpoint as per your API
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'amount': amount}), // Pass the amount in the body
    );

    print(response.body);
    return response;
  }

  static Future<http.Response> addMoneyToWallet(
      double amount, String paymentId) async {
    final token = await SharedPrefs.getUserTokenSharedPreference();
    final userId = await SharedPrefs.getUserIdSharedPreference();

    final response = await http.put(
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
    );

    print(response.body);
    return response;
  }

  static Future<http.Response> deductMoneyToWallet(double amount) async {
    final token = await SharedPrefs.getUserTokenSharedPreference();
    final userId = await SharedPrefs.getUserIdSharedPreference();

    final response = await http.put(
      Uri.parse(
          '$baseUrl/users/wallet/deduct/$userId'), // Update the endpoint as per your API
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'amount': amount}), // Pass the amount in the body
    );

    print(response.body);
    return response;
  }

  static Future<http.Response> addMoneyToReceiverWallet(
      double amount, String receiverId) async {
    final token = await SharedPrefs.getUserTokenSharedPreference();
    // final userId = await SharedPrefs.getUserIdSharedPreference();

    final response = await http.put(
      Uri.parse(
          '$baseUrl/users/wallet/give/$receiverId'), // Update the endpoint as per your API
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'amount': amount}), // Pass the amount in the body
    );

    print(response.body);
    return response;
  }

  static Future<http.Response> updateFCMToken(String fcmToken) async {
    String? token = await SharedPrefs.getUserTokenSharedPreference();
    try {
      print("$baseUrl/users/device-token/update");
      Map<String, dynamic> data = {
        "fcmToken": fcmToken,
      };
      print(data);
      final response = await http.put(
          Uri.parse(
            "$baseUrl/users/device-token/update",
          ),
          body: jsonEncode(data),
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
            'Authorization': 'Bearer $token',
          });

      print(response.body);
      return response;
    } catch (err) {
      throw Exception(err.toString());
    }
  }

  static Future<http.Response> initiateCall(
      String participantId, String type, DateTime scheduleTime) async {
    final token = await SharedPrefs.getUserTokenSharedPreference();
    final userId = await SharedPrefs.getUserIdSharedPreference();
    Map<String, dynamic> data = {
      "userId": userId,
      "participantId": participantId,
      "type": type,
      "scheduledTime": scheduleTime.toIso8601String(),
    };

    print(data);
    final response = await http.post(
      Uri.parse('$baseUrl/meeting/create'),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    print(response.body);
    return response;
  }

  static Future<http.Response> createMeeting(
      String participantId, String type, DateTime scheduleTime) async {
    final token = await SharedPrefs.getUserTokenSharedPreference();
    final userId = await SharedPrefs.getUserIdSharedPreference();
    Map<String, dynamic> data = {
      "userId": userId,
      "participantId": participantId,
      "type": type,
      "scheduledTime": scheduleTime.toIso8601String(),
    };

    print(data);
    final response = await http.post(
      Uri.parse('$baseUrl/meeting/create-meeting'),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    print(response.body);
    return response;
  }

  static Future<http.Response> getUserMeetings(String userId) async {
    final token = await SharedPrefs.getUserTokenSharedPreference();

    final response = await http.get(
      Uri.parse('$baseUrl/meeting/$userId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    return response;
  }

  static Future<http.Response> getUserInstaTalks(String userId) async {
    final token = await SharedPrefs.getUserTokenSharedPreference();
    final Duration timeout = Duration(seconds: 15);
    int retryCount = 0;
    const maxRetries = 2;

    while (retryCount <= maxRetries) {
      try {
        print('🌐 [API] Starting InstaTalk fetch for user: $userId');
        final url = '$baseUrl/insta-talk/$userId';
        print('🌐 [API] Using URL: $url');
        print('🌐 [API] Token available: ${token != null}');

        final response = await http.get(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ).timeout(timeout);

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
    final response = await http.post(
      Uri.parse('$baseUrl/auth/send-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    print("OTP Response: ${response.body}");
    return response;
  }

  static Future<http.Response> getUserById(String userId) async {
    try {
      final token = await SharedPrefs.getUserTokenSharedPreference();
      print('Fetching user profile for ID: $userId');

      // Add timeout to the request
      final response = await http.get(
        Uri.parse('$baseUrl/users/profile/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Connection timed out');
        },
      );

      print('User profile response status: ${response.statusCode}');
      print('User profile response body: ${response.body}');
      return response;
    } catch (e) {
      print('Error in getUserById: $e');
      rethrow; // Rethrow to handle in the UI
    }
  }

  static Future<http.Response> addToWishlist(String userId) async {
    final token = await SharedPrefs.getUserTokenSharedPreference();

    final response = await http.post(
      Uri.parse('$baseUrl/users/wishlist/add'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'userId': userId}),
    );
    print('Add to wishlist response: ${response.body}');
    return response;
  }

  static Future<http.Response> removeFromWishlist(String userId) async {
    final token = await SharedPrefs.getUserTokenSharedPreference();

    final response = await http.delete(
      Uri.parse('$baseUrl/users/wishlist/remove/$userId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    print('Remove from wishlist response: ${response.body}');
    return response;
  }

  static Future<http.Response> getWishlist() async {
    final token = await SharedPrefs.getUserTokenSharedPreference();

    final response = await http.get(
      Uri.parse('$baseUrl/users/wishlist'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    print('Get wishlist response: ${response.body}');
    return response;
  }

  static Future<http.Response> updateProfile(Map<String, dynamic> data) async {
    final token = await SharedPrefs.getUserTokenSharedPreference();

    final response = await http.put(
      Uri.parse('$baseUrl/users/update'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    print('Update profile response: ${response.body}');
    return response;
  }

  // Live streaming endpoints
  static Future<http.Response> startLiveStream(
      {String title = 'Live Stream', String description = ''}) async {
    final token = await SharedPrefs.getUserTokenSharedPreference();

    final response = await http.post(
      Uri.parse('$baseUrl/live-stream/start'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'title': title,
        'description': description,
      }),
    );
    print('Start live stream response: ${response.body}');
    return response;
  }

  static Future<http.Response> endLiveStream(String liveStreamId) async {
    final token = await SharedPrefs.getUserTokenSharedPreference();

    final response = await http.put(
      Uri.parse('$baseUrl/live-stream/end/$liveStreamId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    print('End live stream response: ${response.body}');
    return response;
  }

  static Future<http.Response> getActiveLiveStreams({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final token = await SharedPrefs.getUserTokenSharedPreference();
      final response = await http.get(
        Uri.parse('$baseUrl/live-stream/active?page=$page&limit=$limit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Failed to load live streams');
        },
      );

      print('Get active live streams response: ${response.body}');
      return response;
    } catch (e) {
      print('Error in getActiveLiveStreams: $e');
      rethrow;
    }
  }

  static Future<http.Response> joinLiveStream(String liveStreamId) async {
    final token = await SharedPrefs.getUserTokenSharedPreference();

    final response = await http.post(
      Uri.parse('$baseUrl/live-stream/join/$liveStreamId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    print('Join live stream response: ${response.body}');
    return response;
  }

  static Future<http.Response> leaveLiveStream(String liveStreamId) async {
    final token = await SharedPrefs.getUserTokenSharedPreference();

    final response = await http.post(
      Uri.parse('$baseUrl/live-stream/leave/$liveStreamId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    print('Leave live stream response: ${response.body}');
    return response;
  }

  static Future<http.Response> subscribeToCreator(
      String creatorId, String paymentId) async {
    final token = await SharedPrefs.getUserTokenSharedPreference();

    final response = await http.post(
      Uri.parse('$baseUrl/live-stream/subscribe/$creatorId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'paymentId': paymentId,
      }),
    );
    print('Subscribe to creator response: ${response.body}');
    return response;
  }

  static Future<http.Response> getUserActiveLiveStream(String userId) async {
    final token = await SharedPrefs.getUserTokenSharedPreference();

    final response = await http.get(
      Uri.parse('$baseUrl/live-stream/user/$userId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    print('Get user active live stream response: ${response.body}');
    return response;
  }

  static Future<http.Response> getUserSubscriptions() async {
    final token = await SharedPrefs.getUserTokenSharedPreference();

    final response = await http.get(
      Uri.parse('$baseUrl/live-stream/subscriptions'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    print('Get user subscriptions response: ${response.body}');
    return response;
  }

  static Future<bool> checkIsFriend(String otherUserId) async {
    try {
      final token = await SharedPrefs.getUserTokenSharedPreference();
      final userId = await SharedPrefs.getUserIdSharedPreference();

      final response = await http.get(
        Uri.parse('$baseUrl/friend/check-status/$userId/$otherUserId'),
        headers: {'Authorization': 'Bearer $token'},
      );

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
    final token = await SharedPrefs.getUserTokenSharedPreference();

    final body = {
      'userId': userId,
      'participantId': participantId,
      'type': type,
      'scheduledTime': DateTime.now().toIso8601String(),
    };

    print('Creating InstaTalk: $body');

    return http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        'Authorization': 'Bearer $token',
      },
      body: json.encode(body),
    );
  }

  static Future<http.Response> acceptInstaTalk(
      String meetingId, String userId) async {
    final url = Uri.parse('$baseUrl/insta-talk/$meetingId/accept');
    final token = await SharedPrefs.getUserTokenSharedPreference();

    return http.put(
      url,
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'userId': userId,
      }),
    );
  }

  static Future<http.Response> updateInstaTalkTimeUsage({
    required String meetingId,
    required String userId,
    required bool isUserOne, // true if sender, false if receiver
  }) async {
    try {
      final token = await SharedPrefs.getUserTokenSharedPreference();
      print(
          'Updating InstaTalk time usage - MeetingID: $meetingId, IsUserOne: $isUserOne');

      final response = await http.patch(
        Uri.parse('$baseUrl/insta-talk/$meetingId/time-usage'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userId': userId,
          'field': isUserOne ? 'userOneTimeUsed' : 'userTwoTimeUsed',
          'value': true
        }),
      );

      print('Time usage update response: ${response.body}');
      return response;
    } catch (e) {
      print('Error updating InstaTalk time usage: $e');
      rethrow;
    }
  }

  static Future<http.Response> checkInstaTalkStatus(
      String participantId) async {
    final userId = await SharedPrefs.getUserIdSharedPreference();
    final token = await SharedPrefs.getUserTokenSharedPreference();
    final url = Uri.parse(
        '$baseUrl/insta-talk/check-status?userId=$userId&participantId=$participantId');

    return http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        'Authorization': 'Bearer $token',
      },
    );
  }

  static Future<http.Response> declineInstaTalk(
      String meetingId, String userId) async {
    final url = Uri.parse('$baseUrl/insta-talk/$meetingId/decline');
    final token = await SharedPrefs.getUserTokenSharedPreference();

    return http.put(
      url,
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'userId': userId,
      }),
    );
  }
}
