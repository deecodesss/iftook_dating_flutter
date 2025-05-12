import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:iftook/core/services/api_service.dart';
import 'package:iftook/core/services/shared_prefs.dart';
import 'package:iftook/core/services/socket_service.dart';
import 'package:http/http.dart' as http;

class ChatCallService {
  static Timer? _debounceTimer;
  static bool _isRequestInProgress = false;

  static Future<Map<String, dynamic>?> initiateChatCall(
    String participantId,
    String type,
  ) async {
    if (_isRequestInProgress) {
      throw Exception('A call request is already in progress');
    }

    try {
      _isRequestInProgress = true;
      final response = await ApiService.createMeeting(
        participantId,
        type,
        DateTime.now(),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final meetingData = data['data']['meeting'];
        final token = data['data']['token'];
        final channelName = data['data']['channelName'];

        return {
          'meetingId': meetingData['_id'],
          'token': token,
          'channelName': channelName,
        };
      } else {
        throw Exception('Failed to initiate call');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initiating chat call: $e');
      }
      rethrow;
    } finally {
      // Reset after a short delay to prevent accidental double-taps
      Future.delayed(const Duration(seconds: 2), () {
        _isRequestInProgress = false;
      });
    }
  }

  static Future<bool> rejectCall(String meetingId) async {
    try {
      final userId = await SharedPrefs.getUserIdSharedPreference();
      if (userId == null) throw Exception('User ID not found');

      // Notify via Socket.io for real-time feedback
      SocketService().emitCallRejected(meetingId, userId);

      // Call the API to update the call status in the database
      final response = await ApiService.rejectCall(
        meetingId,
        {
          'status': 'rejected',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('Call rejected successfully');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('Failed to reject call: ${response.body}');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error rejecting call: $e');
      }
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getCallStatus(String meetingId) async {
    try {
      final response = await ApiService.getCallStatus(meetingId);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'status': data['status'],
          'rejectedAt': data['rejectedAt'],
          'rejectedBy': data['rejectedBy'],
        };
      } else {
        if (kDebugMode) {
          print('Failed to get call status: ${response.body}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting call status: $e');
      }
      return null;
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
