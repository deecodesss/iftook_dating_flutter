import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:iftook/core/services/api_service.dart';
import 'package:iftook/core/services/shared_prefs.dart';
import 'package:http/http.dart' as http;

class ChatCallService {
  static Timer? _debounceTimer;
  static bool _isRequestInProgress = false;

  static Future<Map<String, dynamic>> initiateChatCall(
    String participantId,
    String type,
  ) async {
    // Debounce check
    if (_isRequestInProgress) {
      throw Exception('Call request already in progress');
    }

    // Cancel any existing timer
    _debounceTimer?.cancel();

    try {
      _isRequestInProgress = true;

      print('Initiating $type call with participant: $participantId');

      final response = await ApiService.createMeeting(
        participantId,
        type,
        DateTime.now(),
      );

      if (response.statusCode != 201) {
        print('Error response: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to create meeting: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);

      if (!data['success']) {
        throw Exception('Server returned error: ${data['message']}');
      }

      final meetingData = data['data'];
      final result = {
        'meetingId': meetingData['meeting']['_id'],
        'token': meetingData['token'],
        'channelName': meetingData['channelName'],
        'type': type,
      };

      print('Call initialized successfully:');
      print('Meeting ID: ${result['meetingId']}');
      print('Channel: ${result['channelName']}');

      return result;
    } catch (e) {
      print('Error in ChatCallService.initiateChatCall: $e');
      rethrow;
    } finally {
      // Reset request flag after 2 seconds
      _debounceTimer = Timer(const Duration(seconds: 2), () {
        _isRequestInProgress = false;
      });
    }
  }

  static Future<bool> updateCallStatus(String meetingId, String status) async {
    try {
      final response = await ApiService.updateMeetingStatus(meetingId, status);
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating call status: $e');
      return false;
    }
  }
}
