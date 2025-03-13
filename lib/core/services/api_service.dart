import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:iftook/core/services/shared_prefs.dart';
import 'package:iftook/features/friends/data/chatroom.dart';

import '../../features/friends/data/message.dart';

class ApiService {
  // static const String baseUrl = 'https://iftook-backend.vercel.app/api';
  static const String baseUrl = 'https://iftookbackendcopy.vercel.app/api';

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

    final response = await http.put(
      Uri.parse('$baseUrl/friend/requests/reject/$requestId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    print(response.body);
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
    final token = await SharedPrefs.getUserTokenSharedPreference();

    final response = await http.get(
      Uri.parse('$baseUrl/users/profile/$userId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
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
}
