import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iftook/core/services/api_service.dart';
import 'package:iftook/features/calls/presentation/screens/laoding_voice_call_screen.dart';
import 'package:iftook/features/calls/presentation/screens/loading_video_call_screen.dart';
import 'package:iftook/features/friend_requests/controller/friend_controller.dart';
import 'package:iftook/features/friend_requests/data/models/friend_request.dart';
import 'package:iftook/features/friends/presentation/screens/chat_room_screen.dart';
import 'package:iftook/features/home/presentation/widgets/user_profile_screen.dart';
import 'package:iftook/features/instatalk/presentation/instatalk_schedule.dart';
import 'package:iftook/features/shared/controllers/user_online_controller.dart';
import 'package:iftook/features/wallet/controllers/wallet_controller.dart';
import 'package:iftook/helpers/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:iftook/features/calls/controllers/call_status_controller.dart';
import 'package:iftook/features/calls/services/chat_call_service.dart';

import '../../../../core/services/shared_prefs.dart';
import '../../../friends/controllers/chat_controller.dart';
import '../../../profile/data/models/user.dart';

class Meeting {
  final String name;
  final String imageUrl;
  final String callType;
  final DateTime meetingTime;
  final bool isLiked;
  final String charges;

  Meeting({
    required this.name,
    required this.imageUrl,
    required this.callType,
    required this.meetingTime,
    required this.charges,
    this.isLiked = false,
  });

  bool get hasStarted => DateTime.now().isAfter(meetingTime);
}

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen>
    with SingleTickerProviderStateMixin {
  FriendController controller = Get.put(FriendController());
  final ChatController _chatController = Get.put(ChatController());

  late TabController _tabController;
  late Timer _timer;

  final List<Meeting> meetings = [
    Meeting(
      isLiked: true,
      name: 'Sarah Parker',
      charges: "450",
      imageUrl: 'https://images.unsplash.com/photo-1535324492437-d8dea70a38a7',
      callType: 'Video Call',
      meetingTime: DateTime.now().add(const Duration(minutes: 30)),
    ),
    Meeting(
      name: 'John Doe',
      charges: "300",
      imageUrl: 'https://images.unsplash.com/photo-1524250502761-1ac6f2e30d43',
      callType: 'Voice Call',
      meetingTime: DateTime.now().subtract(const Duration(minutes: 15)),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 3, vsync: this); // Changed from 4 to 3
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });

    // Initialize CallStatusController if not already registered
    if (!Get.isRegistered<CallStatusController>()) {
      Get.put(CallStatusController());
    }

    controller.fetchFriendRequests();
    controller.fetchSentRequests();
    controller.fetchMeetings();
    controller.fetchInstaTalkRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _timer.cancel();
    super.dispose();
  }

  String _formatMeetingTime(DateTime meetingTimeUtc) {
    // Convert UTC to IST (UTC+5:30)
    final meetingTime =
        meetingTimeUtc.add(const Duration(hours: 5, minutes: 30));

    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));

    // Check for "Join Now" condition using UTC time for accurate comparison
    if (now.difference(meetingTimeUtc).inMinutes <= 30 &&
        now.difference(meetingTimeUtc).inMinutes >= 0) {
      return 'Join Now ${DateFormat('h:mm a').format(meetingTime)} IST';
    }

    // Check for "In X min" condition using UTC time for accurate comparison
    if (meetingTimeUtc.difference(now).inMinutes <= 60 &&
        meetingTimeUtc.isAfter(now)) {
      return 'In ${meetingTimeUtc.difference(now).inMinutes} min';
    }

    // Display times in IST
    if (meetingTime.year == now.year &&
        meetingTime.month == now.month &&
        meetingTime.day == now.day) {
      return 'Today, ${DateFormat('h:mm a').format(meetingTime)} IST';
    }

    if (meetingTime.year == tomorrow.year &&
        meetingTime.month == tomorrow.month &&
        meetingTime.day == tomorrow.day) {
      return 'Tomorrow, ${DateFormat('h:mm a').format(meetingTime)} IST';
    }

    return '${DateFormat('MMM d, h:mm a').format(meetingTime)} IST';
  }

  Widget _buildMeetingTimeIndicator(DateTime meetingTime) {
    final now = DateTime.now();
    final difference = meetingTime.difference(now);

    String timeText;
    Color timeColor;

    if (difference.isNegative) {
      timeText = 'Started ${-difference.inMinutes} min ago';
      timeColor = AppColors.greenColor;
    } else if (difference.inMinutes < 60) {
      timeText = 'In ${difference.inMinutes} min';
      timeColor = AppColors.primaryColor;
    } else {
      timeText = _formatMeetingTime(meetingTime);
      timeColor = Colors.white70;
    }

    return Text(
      timeText,
      style: TextStyle(
        color: timeColor,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  void _showAcceptWarning(BuildContext context, String reqId) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.secondaryBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppColors.primaryBackground,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.primaryColor,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Accept Friend Request?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Once you accept, all chats and calls will be free until you unfriend this person.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accentColor,
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        controller.acceptRequest(reqId, context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeclineWarning(BuildContext context, String reqId) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.secondaryBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppColors.primaryBackground,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cancel_outlined,
                  color: AppColors.primaryColor,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Decline Friend Request?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This action will remove the request, and the person will not be notified.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accentColor,
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final currentUserId =
                            await SharedPrefs.getUserIdSharedPreference();
                        if (currentUserId != null) {
                          final request = controller.friendRequests.firstWhere(
                            (req) => req.sId == reqId,
                            orElse: () => FriendRequest(),
                          );

                          if (request.requester?.sId != null) {
                            await controller.deleteSentRequest(currentUserId);
                          }
                        } else {
                          Get.snackbar(
                            'Error',
                            'Unable to identify current user',
                            backgroundColor: Colors.red,
                            colorText: Colors.white,
                          );
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text('Decline'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  DateTime _convertToIST(DateTime utc) {
    return utc.add(const Duration(hours: 5, minutes: 30));
  }

  String _getMeetingStatus(DateTime scheduledTime, String currentStatus) {
    final now = DateTime.now();
    final minutesDifference = now.difference(scheduledTime).inMinutes;

    if (minutesDifference > 30) {
      if (currentStatus == 'completed') return 'Completed';
      if (currentStatus == 'cancelled') return 'Cancelled';
      return 'Expired';
    }

    if (minutesDifference >= -30 && minutesDifference <= 30) {
      if (currentStatus == 'completed') return 'Completed';
      if (currentStatus == 'cancelled') return 'Cancelled';
      return 'Join Now';
    }

    return 'Scheduled';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'expired':
        return Colors.red[400]!;
      case 'cancelled':
        return Colors.orange;
      case 'join now':
        return Colors.green;
      case 'scheduled':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Future<void> _handleProfileNavigation(String userId) async {
    try {
      Get.dialog(
        WillPopScope(
          onWillPop: () async => false,
          child: const Center(child: CircularProgressIndicator()),
        ),
        barrierDismissible: false,
      );

      final response = await ApiService.getUserById(userId);

      if (!response.body.contains('success')) {
        throw Exception('Invalid response format');
      }

      final data = jsonDecode(response.body);
      if (data['success'] == true && data['data'] != null) {
        final userProfile = User.fromJson(data['data']);
        Get.back();
        Get.to(() => UserProfileScreen(profile: userProfile));
      } else {
        throw Exception('Failed to load profile data');
      }
    } catch (e) {
      Get.back();
      Get.snackbar(
        'Error',
        'Could not load profile. Please try again.',
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }

  void _handleJoinMeeting(Map<String, dynamic> meeting) async {
    final isInstaTalk = meeting['isInstaTalk'] ?? false;

    if (isInstaTalk) {
      _handleInstaTalkJoin(meeting);
    } else {
      _handleRegularMeetingJoin(meeting);
    }
  }

  void _handleInstaTalkJoin(Map<String, dynamic> meeting) async {
    try {
      // Get current user ID first to ensure we have the right participant
      final currentUserId = await SharedPrefs.getUserIdSharedPreference();
      if (currentUserId == null) {
        throw Exception('Unable to identify current user');
      }

      final userData = meeting['user'];
      final participantData = meeting['participant'];
      final type = meeting['type'];
      final amount = (meeting['amount'] ?? 0).toDouble();
      final meetingId = meeting['_id'];
      final isSender = controller.isInstaTalkSender(meeting);
      final int renewalCount = meeting['renewalCount'] ?? 0;
      final bool isTrial = renewalCount == 0;

      print('InstaTalk Join - Meeting details:');
      print('Meeting ID: $meetingId');
      print('Type: $type');
      print('renewalCount: $renewalCount');
      print('isTrial: $isTrial');

      // Determine if we need to swap user and participant
      final String participantId = participantData['_id'];
      final String userId = userData['_id'];
      bool usedWrongParticipant = false;

      // Debug output
      print('InstaTalk - Current user ID: $currentUserId');
      print('InstaTalk - Meeting user ID: $userId');
      print('InstaTalk - Meeting participant ID: $participantId');

      Map<String, dynamic> correctParticipantData;

      // If the "participant" is actually the current user, we need to use the "user" as our actual participant
      if (participantId == currentUserId) {
        print(
            'INSTATALK PARTICIPANT SWAP: Using meeting user as the actual participant');
        correctParticipantData = userData;
        usedWrongParticipant = true;
      } else if (userId == currentUserId && participantId != currentUserId) {
        // This is the correct scenario - currentUser is the "user" and participant is someone else
        print(
            'INSTATALK PARTICIPANT CORRECT: Current user is the meeting creator');
        correctParticipantData = participantData;
      } else {
        // Default case - just use participantData as provided
        print('INSTATALK PARTICIPANT DEFAULT: Using provided participant data');
        correctParticipantData = participantData;
      }

      final participant = User(
          sId: correctParticipantData['_id'],
          name: correctParticipantData['name'],
          photos: correctParticipantData['photos'] is List
              ? List<String>.from(correctParticipantData['photos'])
              : [],
          earnings: Earnings(
            chat: correctParticipantData['earnings']['chat'] ?? 0,
            video: correctParticipantData['earnings']['video'] ?? 0,
            voice: correctParticipantData['earnings']['voice'] ?? 0,
          ));

      print('Joining InstaTalk: $meetingId');
      print('InstaTalk type: $type');
      print('Selected participant: ${participant.name} (${participant.sId})');
      if (usedWrongParticipant) {
        print(
            'WARNING: Had to swap InstaTalk participant and user due to incorrect IDs!');
      }

      // Check if the user already used their time
      final bool hasUsedTime = isSender
          ? meeting['userOneTimeUsed'] ?? false
          : meeting['userTwoTimeUsed'] ?? false;

      if (hasUsedTime) {
        Get.snackbar(
          'Session Already Used',
          'You have already joined this InstaTalk session',
          backgroundColor: Colors.orange.withOpacity(0.8),
          colorText: Colors.white,
        );
        return;
      }

      // Mark time as used
      final success = await controller.updateInstaTalkTimeUsage(
        meetingId: meetingId,
        isUserOne: isSender,
      );

      if (!success) {
        Get.snackbar(
          'Error',
          'Unable to start InstaTalk session',
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
        );
        return;
      }

      switch (type) {
        case 'chat':
          await Get.to(() => ChatRoomScreen(
                profile: participant,
                isInstaTalk: true,
                isTrial: isTrial,
                duration: meeting['duration'],
                isInstaTalkSender: isSender,
                onSessionEnd: () =>
                    _showContinueSessionDialog(participant, amount, type),
              ));
          break;

        case 'voice':
          await Get.to(() => VoiceCallLoadingScreen(
                participant: participant,
                scheduleTime: DateTime.now(),
                type: "voice",
                isInstaTalk: true,
                isTrial: isTrial,
                instaTalkDuration: meeting['duration'],
                onSessionEnd: () =>
                    _showContinueSessionDialog(participant, amount, type),
              ));
          break;

        case 'video':
          await Get.to(() => VideoCallLoadingScreen(
                participant: participant,
                scheduleTime: DateTime.now(),
                type: "video",
                isInstaTalk: true,
                isTrial: isTrial,
                instaTalkDuration: meeting['duration'],
                onSessionEnd: () =>
                    _showContinueSessionDialog(participant, amount, type),
              ));
          break;
      }
    } catch (e) {
      print('InstaTalk join error: $e');
      Get.snackbar(
        'Error',
        'Could not join InstaTalk session. Please try again.',
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
  }

  void _handleRegularMeetingJoin(Map<String, dynamic> meeting) async {
    try {
      // Get current user ID first to ensure we have the right participant
      final currentUserId = await SharedPrefs.getUserIdSharedPreference();
      if (currentUserId == null) {
        throw Exception('Unable to identify current user');
      }

      final userData = meeting['user'];
      final participantData = meeting['participant'];
      final type = meeting['type'];
      final scheduledTime = DateTime.parse(meeting['scheduledTime']);
      final meetingId = meeting['_id'];

      // Get token and channel data from the meeting
      final String channelName = meeting['channelName'] ?? '';
      final String token = meeting['token'] ?? '';

      // Debug log for the Agora credentials
      print('Meeting Agora credentials:');
      print('Channel Name: $channelName');
      print('Token: $token');
      print('Meeting ID: $meetingId');

      // Determine if we need to swap user and participant
      final String participantId = participantData['_id'];
      final String userId = userData['_id'];
      bool usedWrongParticipant = false;

      // Debug output
      print('Current user ID: $currentUserId');
      print('Meeting user ID: $userId');
      print('Meeting participant ID: $participantId');

      Map<String, dynamic> correctParticipantData;

      // If the "participant" is actually the current user, we need to use the "user" as our actual participant
      if (participantId == currentUserId) {
        print('PARTICIPANT SWAP: Using meeting user as the actual participant');
        correctParticipantData = userData;
        usedWrongParticipant = true;
      } else if (userId == currentUserId && participantId != currentUserId) {
        // This is the correct scenario - currentUser is the "user" and participant is someone else
        print('PARTICIPANT CORRECT: Current user is the meeting creator');
        correctParticipantData = participantData;
      } else {
        // Default case - just use participantData as provided
        print('PARTICIPANT DEFAULT: Using provided participant data');
        correctParticipantData = participantData;
      }

      final participant = User(
          sId: correctParticipantData['_id'],
          name: correctParticipantData['name'],
          photos: correctParticipantData['photos'] is List
              ? List<String>.from(correctParticipantData['photos'])
              : [],
          earnings: Earnings(
            chat: correctParticipantData['earnings']['chat'] ?? 0,
            video: correctParticipantData['earnings']['video'] ?? 0,
            voice: correctParticipantData['earnings']['voice'] ?? 0,
          ));

      print('Joining regular meeting: $meetingId');
      print('Meeting type: $type');
      print('Scheduled time: $scheduledTime');
      print('Selected participant: ${participant.name} (${participant.sId})');
      if (usedWrongParticipant) {
        print(
            'WARNING: Had to swap participant and user due to incorrect IDs!');
      }

      // Check if token and channel are available in the meeting data
      if (channelName.isNotEmpty && token.isNotEmpty) {
        print('Using existing Agora credentials from meeting data');

        switch (type) {
          case 'voice':
            // await Get.to(() => VoiceCallLoadingScreen(
            //       participant: participant,
            //       scheduleTime: scheduledTime,
            //       type: "voice",
            //       isInstaTalk: false,
            //       meetingId: meetingId, // Ensure meetingId is passed
            //       token: token,
            //       channel: channelName,
            //       instaTalkDuration: meeting['duration'] ?? 30,
            //     ));
            await _handleChatVoiceCall(participant);
            break;

          case 'video':
            // await Get.to(() => VideoCallLoadingScreen(
            //       participant: participant,
            //       scheduleTime: scheduledTime,
            //       type: "video",
            //       isInstaTalk: false,
            //       meetingId: meetingId, // Ensure meetingId is passed
            //       token: token,
            //       channel: channelName,
            //       instaTalkDuration: meeting['duration'] ?? 30,
            //     ));
            await _handleChatVideoCall(participant);
            break;

          case 'chat':
            await Get.to(() => ChatRoomScreen(
                  profile: participant,
                  isInstaTalk: false,
                  duration: meeting['duration'],
                  isFriend: false,
                  isInstaTalkSender: controller.isInstaTalkSender(meeting),
                  scheduledTime: DateTime.parse(meeting['scheduledTime']),
                ));
            break;
        }
      } else {
        print(
            'WARNING: No Agora credentials found in meeting data. Initiating new call with meetingId: $meetingId');

        // Critical fix: Always pass the meetingId parameter even when token/channel aren't available
        switch (type) {
          case 'voice':
            // await Get.to(() => VoiceCallLoadingScreen(
            //       participant: participant,
            //       scheduleTime: scheduledTime,
            //       type: "voice",
            //       isInstaTalk: false,
            //       meetingId: meetingId, // Add meetingId here
            //     ));
            await _handleChatVoiceCall(participant);
            break;

          case 'video':
            // await Get.to(() => VideoCallLoadingScreen(
            //       participant: participant,
            //       scheduleTime: scheduledTime,
            //       type: "video",
            //       isInstaTalk: false,
            //       meetingId: meetingId, // Add meetingId here
            //     ));
            await _handleChatVideoCall(participant);
            break;

          case 'chat':
            await Get.to(() => ChatRoomScreen(
                  profile: participant,
                  isInstaTalk: false,
                  duration: meeting['duration'],
                  isFriend: false,
                  isInstaTalkSender: controller.isInstaTalkSender(meeting),
                  scheduledTime: DateTime.parse(meeting['scheduledTime']),
                ));
            break;
        }
      }
    } catch (e) {
      print('Regular meeting join error: $e');
      Get.snackbar(
        'Error',
        'Could not join meeting. Please try again.',
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
  }

  _handleChatVideoCall(participant) async {
    try {
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      final callData = await ChatCallService.initiateChatCall(
        participant.sId!,
        'video',
      );

      Get.back(); // Close loading dialog

      if (callData != null) {
        print('Video call initialized with data: $callData');

        await Get.to(() => VideoCallLoadingScreen(
              participant: participant,
              type: "video",
              scheduleTime: DateTime.now(),
              meetingId: callData['meetingId'],
              token: callData['token'],
              channel: callData['channelName'],
            ));
      }
    } catch (e) {
      Get.back(); // Close loading dialog
      if (e.toString().contains('already in progress')) {
        Get.snackbar(
          'Please Wait',
          'A call request is already being processed',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Error',
          'Could not start video call: ${e.toString()}',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  _handleChatVoiceCall(participant) async {
    try {
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      final callData = await ChatCallService.initiateChatCall(
        participant.sId!,
        'voice',
      );

      Get.back(); // Close loading dialog

      if (callData != null) {
        print('Voice call initialized with data: $callData');

        await Get.to(() => VoiceCallLoadingScreen(
              participant: participant,
              type: "voice",
              scheduleTime: DateTime.now(),
              meetingId: callData['meetingId'],
              token: callData['token'],
              channel: callData['channelName'],
            ));
      }
    } catch (e) {
      Get.back(); // Close loading dialog
      if (e.toString().contains('already in progress')) {
        Get.snackbar(
          'Please Wait',
          'A call request is already being processed',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Error',
          'Could not start voice call: ${e.toString()}',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  void _showContinueSessionDialog(
      User participant, double amount, String type) {
    Get.dialog(
      Dialog(
        backgroundColor: AppColors.secondaryBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_off,
                  size: 48, color: AppColors.primaryColor),
              const SizedBox(height: 16),
              const Text(
                'Session Ended',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your 30-minute session with ${participant.name} has ended. Would you like to continue for another 30 minutes?',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                'Rate: ₹$amount for 30 minutes',
                style: TextStyle(
                  color: AppColors.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: const Text('End Session'),
                  ),
                  ElevatedButton(
                    onPressed: () =>
                        _purchaseContinuation(participant, amount, type),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                    ),
                    child: const Text('Continue'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _purchaseContinuation(
      User participant, double amount, String type) async {
    final chatController = Get.find<ChatController>();

    await chatController.fetchWalletBalance();

    if (chatController.userWalletBalance.value < amount) {
      Get.back();
      Get.snackbar(
        'Insufficient Balance',
        'Please add funds to your wallet to continue the session',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
        mainButton: TextButton(
          onPressed: () => Get.toNamed('/wallet/topup'),
          child: const Text('Top Up', style: TextStyle(color: Colors.white)),
        ),
      );
      return;
    }

    final success =
        await chatController.purchaseChatSession(participant.sId!, amount);

    if (success) {
      Get.back();
      switch (type) {
        case 'chat':
          final currentUserId = await SharedPrefs.getUserIdSharedPreference();
          Get.off(() => ChatRoomScreen(
                profile: participant,
                isInstaTalk: true,
                isTrial: false, // Set to false since it's a paid continuation
                duration: 60,
                isInstaTalkSender: controller.isInstaTalkSender({
                  'user': {
                    '_id': currentUserId,
                  },
                  'participant': participant.toJson(),
                }),
                onSessionEnd: () =>
                    _showContinueSessionDialog(participant, amount, type),
              ));
          break;
        case 'voice':
          Get.off(() => VoiceCallLoadingScreen(
                participant: participant,
                scheduleTime: DateTime.now(),
                type: "voice",
                isInstaTalk: true,
                isTrial: false, // Set to false since it's a paid continuation
                instaTalkDuration: 30,
                onSessionEnd: () =>
                    _showContinueSessionDialog(participant, amount, type),
              ));
          break;
        case 'video':
          Get.off(() => VideoCallLoadingScreen(
                participant: participant,
                scheduleTime: DateTime.now(),
                type: "video",
                isInstaTalk: true,
                isTrial: false, // Set to false since it's a paid continuation
                instaTalkDuration: 30,
                onSessionEnd: () =>
                    _showContinueSessionDialog(participant, amount, type),
              ));
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'Connections',
          style: GoogleFonts.manrope(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryColor,
          indicatorWeight: 3,
          dividerColor: Colors.transparent,
          labelColor: AppColors.primaryColor,
          unselectedLabelColor: Colors.white.withOpacity(0.6),
          labelStyle: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: 'Meetings'),
            Tab(text: 'Requests'),
            Tab(text: 'InstaTalk'),
          ],
          padding: const EdgeInsets.symmetric(horizontal: 32),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          MeetingsTabView(
            controller: controller,
            buildMeetingCard: _buildMeetingCard,
            buildEmptyView: _buildEmptyMeetingsView,
          ),
          FriendRequestsTabView(
            controller: controller,
            buildRequestCard: _buildRequestCard,
            buildSentRequestCard: _buildSentRequestCard,
          ),
          InstaTalkTabView(
            controller: controller,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMeetingsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'No Meetings Scheduled',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your scheduled meetings will appear here',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingCard(Map<String, dynamic> meeting) {
    final scheduledTime = DateTime.parse(meeting['scheduledTime']);
    final participant = meeting['participant'] as Map<String, dynamic>;
    final user = meeting['user'] as Map<String, dynamic>;
    final status = meeting['status'];
    final type = meeting['type'];
    final userId = user['_id'];
    final amount = (meeting['amount'] ?? 0).toDouble();
    final otherUserId = participant['_id'];

    return FutureBuilder<String?>(
      future: SharedPrefs.getUserIdSharedPreference(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final currentUserId = snapshot.data!;
        final isCreator = userId == currentUserId;

        final displayName = isCreator
            ? participant['name'] ?? 'Unknown'
            : user['name'] ?? 'Unknown';

        final now = DateTime.now();
        final minutesDifference = now.difference(scheduledTime).inMinutes;
        final canJoin = minutesDifference >= -30 && minutesDifference <= 30;
        final currentStatus = _getMeetingStatus(scheduledTime, status);

        // Check if this is a voice or video call
        final isCallMeeting = type == 'voice' || type == 'video';

        // Determine if we should show join button
        // For voice/video calls, only show join if the current user is the creator
        final bool shouldShowJoin = !isCallMeeting || isCreator;

        // Use StreamBuilder for call status
        return StreamBuilder<Map<String, dynamic>>(
            stream: Get.find<CallStatusController>()
                .getUserCallStatusStream(otherUserId),
            initialData: {'inCall': false},
            builder: (context, callSnapshot) {
              final bool isUserInCall = callSnapshot.data?['inCall'] ?? false;
              final String? callType = callSnapshot.data?['callType'];

              final bool canActuallyJoin =
                  canJoin && !isUserInCall && shouldShowJoin;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _getStatusColor(currentStatus).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              InkWell(
                                onTap: () {
                                  try {
                                    final safeProfile = User(
                                      sId: participant['_id']?.toString() ?? '',
                                      name: participant['name']?.toString() ??
                                          'Unknown',
                                      email: participant['email']?.toString() ??
                                          '',
                                      dob: participant['dob']?.toString() ?? '',
                                      gender:
                                          participant['gender']?.toString() ??
                                              '',
                                      profession: participant['profession']
                                              ?.toString() ??
                                          'Not specified',
                                      about: participant['about']?.toString() ??
                                          'No information available',
                                      interestedIn: participant['interestedIn']
                                              ?.toString() ??
                                          '',
                                      photos: participant['photos'] is List
                                          ? List<String>.from(
                                              participant['photos'])
                                          : [],
                                      location: participant['location'] is Map
                                          ? Location(
                                              city: participant['location']
                                                          ['city']
                                                      ?.toString() ??
                                                  'Unknown',
                                              state: participant['location']
                                                          ['state']
                                                      ?.toString() ??
                                                  '',
                                              country: participant['location']
                                                          ['country']
                                                      ?.toString() ??
                                                  '',
                                            )
                                          : Location(
                                              city: 'Unknown',
                                              state: '',
                                              country: ''),
                                      walletBalance: 0,
                                      earnings: Earnings(),
                                      isOnline:
                                          participant['isOnline'] ?? false,
                                    );

                                    Get.to(() => UserProfileScreen(
                                        profile: safeProfile));
                                  } catch (e) {
                                    Get.snackbar(
                                      'Error',
                                      'Could not open profile details',
                                      backgroundColor:
                                          Colors.red.withOpacity(0.7),
                                      colorText: Colors.white,
                                    );
                                  }
                                },
                                child: CircleAvatar(
                                  radius: 30,
                                  backgroundImage: participant['photos'] !=
                                              null &&
                                          participant['photos'].isNotEmpty
                                      ? NetworkImage(participant['photos'][0])
                                      : null,
                                  child: participant['photos'] == null ||
                                          participant['photos'].isEmpty
                                      ? const Icon(Icons.person,
                                          color: Colors.white70, size: 30)
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          type == 'video'
                                              ? Icons.videocam
                                              : type == 'voice'
                                                  ? Icons.phone
                                                  : Icons.chat,
                                          size: 16,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '₹$amount',
                                          style: const TextStyle(
                                            color: AppColors.primaryColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (isUserInCall) ...[
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.red.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color:
                                                    Colors.red.withOpacity(0.3),
                                              ),
                                            ),
                                            child: Text(
                                              'In a ${callType ?? ""} call',
                                              style: const TextStyle(
                                                color: Colors.red,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(currentStatus)
                                      .withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  currentStatus,
                                  style: TextStyle(
                                    color: _getStatusColor(currentStatus),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  _formatMeetingTime(scheduledTime),
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 14,
                                  ),
                                ),
                              ),

                              // Add availability status tag
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isUserInCall
                                      ? Colors.red.withOpacity(0.15)
                                      : Colors.green.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isUserInCall
                                        ? Colors.red.withOpacity(0.3)
                                        : Colors.green.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      isUserInCall ? 'IN CALL' : 'IDLE',
                                      style: TextStyle(
                                        color: isUserInCall
                                            ? Colors.red
                                            : Colors.green,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12)),
                              color: Colors.blueGrey.withOpacity(0.1),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isCreator
                                      ? Icons.call_made_rounded
                                      : Icons.call_received_rounded,
                                  size: 16,
                                  color: isCreator
                                      ? Colors.blue.withOpacity(0.7)
                                      : Colors.green.withOpacity(0.7),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isCreator ? 'Sent' : 'Received',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isCreator
                                        ? Colors.blue.withOpacity(0.7)
                                        : Colors.green.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canJoin) ...[
                      // When user should be able to join (creator for calls or chat for anyone)
                      if (shouldShowJoin) ...[
                        if (isUserInCall)
                          Padding(
                            padding: const EdgeInsets.only(
                                top: 0, left: 16, right: 16, bottom: 8),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.red.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.call_end,
                                    color: Colors.red,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'This person is currently in a call and cannot be joined',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(
                              top: 8, left: 24, right: 24, bottom: 16),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: canActuallyJoin
                                  ? () => _handleJoinMeeting(meeting)
                                  : null,
                              icon: Icon(
                                type == 'video'
                                    ? Icons.videocam
                                    : type == 'voice'
                                        ? Icons.call
                                        : Icons.chat,
                                color: Colors.white,
                              ),
                              label: Text(isUserInCall
                                  ? 'User is in a Call'
                                  : 'Join Now'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isUserInCall
                                    ? Colors.red.shade400
                                    : Colors.green,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],

                      // If this is an incoming call request, show informational message
                      if (isCallMeeting && !isCreator) ...[
                        Padding(
                          padding: const EdgeInsets.only(
                              top: 0, left: 16, right: 16, bottom: 16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.amber.withOpacity(0.3)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline,
                                      color: Colors.amber,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Waiting for $displayName to initiate this call',
                                        style: TextStyle(
                                          color: Colors.amber,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Text(
                                //   'For voice and video calls, only the person who created the meeting can initiate the call',
                                //   style: TextStyle(
                                //     color: Colors.amber.shade700,
                                //     fontSize: 11,
                                //   ),
                                // ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              );
            });
      },
    );
  }

  Widget _buildRequestCard(FriendRequest request) {
    return Card(
      color: Colors.blueGrey.withOpacity(0.1),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            InkWell(
              onTap: () {
                if (request.requester != null) {
                  Get.to(() => UserProfileScreen(profile: request.requester!));
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accentColor, width: 2),
                ),
                child: CircleAvatar(
                  radius: 30,
                  backgroundImage: request.requester?.photos != null &&
                          request.requester!.photos!.isNotEmpty
                      ? NetworkImage(request.requester!.photos![0])
                      : null,
                  child: (request.requester?.photos == null ||
                          request.requester!.photos!.isEmpty)
                      ? const Icon(Icons.person, color: Colors.white70)
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                request.requester?.name ?? 'Unknown',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () =>
                      _showAcceptWarning(context, request.sId ?? ''),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.greenColor.withOpacity(0.1),
                    foregroundColor: AppColors.greenColor,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: const Size(80, 36),
                  ),
                  child: const Text(
                    'Accept',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      _showDeclineWarning(context, request.sId ?? ''),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.redColor.withOpacity(0.1),
                    foregroundColor: AppColors.redColor,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: const Size(80, 36),
                  ),
                  child: const Text(
                    'Decline',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSentRequestCard(FriendRequest request) {
    final receiver = request.receiver;
    if (receiver == null) return SizedBox.shrink();

    return Card(
      color: Colors.blueGrey.withOpacity(0.1),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            InkWell(
              onTap: () {
                if (receiver != null) {
                  Get.to(() => UserProfileScreen(profile: receiver));
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accentColor, width: 2),
                ),
                child: CircleAvatar(
                  radius: 30,
                  backgroundImage: receiver.photos?.isNotEmpty == true
                      ? NetworkImage(receiver.photos!.first)
                      : null,
                  child: receiver.photos?.isEmpty ?? true
                      ? const Icon(Icons.person, color: Colors.white70)
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    receiver.name ?? 'Unknown User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (receiver.location != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${receiver.location?.city ?? ''}, ${receiver.location?.state ?? ''}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                  if (request.createdAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Sent ${timeago.format(DateTime.parse(request.createdAt!))}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Pending',
                    style: TextStyle(
                      color: AppColors.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    if (request.sId != null && request.sId!.isNotEmpty) {
                      controller.deleteSentRequest(request.sId!);
                    }
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.redColor.withOpacity(0.1),
                    foregroundColor: AppColors.redColor,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: const Size(80, 36),
                  ),
                  child: const Text(
                    'Delete',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MeetingsTabView extends StatefulWidget {
  final FriendController controller;
  final Function(Map<String, dynamic>) buildMeetingCard;
  final Widget Function() buildEmptyView;

  const MeetingsTabView({
    Key? key,
    required this.controller,
    required this.buildMeetingCard,
    required this.buildEmptyView,
  }) : super(key: key);

  @override
  State<MeetingsTabView> createState() => _MeetingsTabViewState();
}

class _MeetingsTabViewState extends State<MeetingsTabView>
    with AutomaticKeepAliveClientMixin {
  final List<Map<String, dynamic>> _meetings = [];
  bool _isLoading = true;
  int _currentDisplayCount = 10; // Number of items to show initially
  static const int _loadMoreCount =
      10; // Number of items to add when loading more
  final ScrollController _scrollController = ScrollController();

  bool get _canLoadMore => _currentDisplayCount < _meetings.length;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchMeetings();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMeetings() async {
    setState(() {
      _isLoading = true;
      _currentDisplayCount = 10; // Reset to initial count
    });

    try {
      if (widget.controller.meetings.isNotEmpty) {
        _meetings.clear();
        _meetings
            .addAll(widget.controller.meetings.cast<Map<String, dynamic>>());
      }
    } catch (e) {
      print('Error fetching meetings: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(
        context); // Important: call super.build for AutomaticKeepAliveClientMixin

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_meetings.isEmpty) {
      return widget.buildEmptyView();
    }

    return RefreshIndicator(
      onRefresh: _fetchMeetings,
      child: CustomScrollView(
        controller: _scrollController, // Add scroll controller
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= _currentDisplayCount) return null;
                final meeting = _meetings[index];
                return widget.buildMeetingCard(meeting);
              },
              childCount: _currentDisplayCount.clamp(0, _meetings.length),
            ),
          ),
          if (_canLoadMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _currentDisplayCount += _loadMoreCount;
                      if (_currentDisplayCount > _meetings.length) {
                        _currentDisplayCount = _meetings.length;
                      }
                    });
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[400],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                          'Show More (${_meetings.length - _currentDisplayCount})'),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down, size: 18),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class FriendRequestsTabView extends StatefulWidget {
  final FriendController controller;
  final Function(FriendRequest) buildRequestCard;
  final Function(FriendRequest) buildSentRequestCard;

  const FriendRequestsTabView({
    Key? key,
    required this.controller,
    required this.buildRequestCard,
    required this.buildSentRequestCard,
  }) : super(key: key);

  @override
  State<FriendRequestsTabView> createState() => _FriendRequestsTabViewState();
}

class _FriendRequestsTabViewState extends State<FriendRequestsTabView>
    with AutomaticKeepAliveClientMixin {
  bool _showingReceived = true;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Obx(() {
      if (widget.controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildFilterButton(
                    text: 'Received',
                    isSelected: _showingReceived,
                    count: widget.controller.friendRequests.length,
                    onPressed: () => setState(() => _showingReceived = true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFilterButton(
                    text: 'Sent',
                    isSelected: !_showingReceived,
                    count: widget.controller.sentRequests.length,
                    onPressed: () => setState(() => _showingReceived = false),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _showingReceived
                ? widget.controller.friendRequests.isEmpty
                    ? const EmptyRequestsView()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: widget.controller.friendRequests.length,
                        itemBuilder: (context, index) {
                          final request =
                              widget.controller.friendRequests[index];
                          return widget.buildRequestCard(request);
                        },
                      )
                : widget.controller.sentRequests.isEmpty
                    ? EmptySentRequestsView()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: widget.controller.sentRequests.length,
                        itemBuilder: (context, index) {
                          final request = widget.controller.sentRequests[index];
                          return widget.buildSentRequestCard(request);
                        },
                      ),
          ),
        ],
      );
    });
  }

  Widget _buildFilterButton({
    required String text,
    required bool isSelected,
    required int count,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: isSelected ? AppColors.primaryColor : Colors.transparent,
      borderRadius: BorderRadius.circular(25),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(25),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryColor
                  : AppColors.primaryColor.withOpacity(0.5),
            ),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                text,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[400],
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.2)
                        : AppColors.primaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class InstaTalkTabView extends StatefulWidget {
  final FriendController controller;

  const InstaTalkTabView({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  State<InstaTalkTabView> createState() => _InstaTalkTabViewState();
}

class _InstaTalkTabViewState extends State<InstaTalkTabView>
    with AutomaticKeepAliveClientMixin {
  late final UserOnlineController userOnlineController;
  Timer? _onlineStatusRefreshTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    userOnlineController = Get.find<UserOnlineController>();

    // Initialize CallStatusController if it's not already registered
    if (!Get.isRegistered<CallStatusController>()) {
      Get.put(CallStatusController());
    }

    // Set up a timer to periodically refresh online status
    _setupOnlineStatusRefreshTimer();
  }

  @override
  void dispose() {
    _onlineStatusRefreshTimer?.cancel();
    super.dispose();
  }

  void _setupOnlineStatusRefreshTimer() {
    // Refresh online status every 20 seconds
    _onlineStatusRefreshTimer =
        Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) {
        setState(() {
          // This will trigger a rebuild of the InstaTalk list,
          // which will use the StreamBuilders to get fresh online status
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return RefreshIndicator(
      onRefresh: () async {
        // Clear all status cache when manually refreshing
        userOnlineController.clearAllStatusCache();
        return widget.controller.fetchInstaTalkRequests();
      },
      child: Obx(() {
        if (widget.controller.isInstaTalkLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (widget.controller.instaTalkRequests.isEmpty) {
          return Stack(
            children: [
              _buildEmptyInstaTalkView(),
              if (kDebugMode)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.orange,
                    child: const Icon(Icons.refresh),
                    onPressed: () {
                      userOnlineController.clearAllStatusCache();
                      widget.controller.fetchInstaTalkRequests();
                    },
                  ),
                ),
            ],
          );
        }

        return ListView.builder(
          key: const PageStorageKey<String>('instatalk_list'),
          padding: const EdgeInsets.symmetric(vertical: 8),
          physics: const ClampingScrollPhysics(),
          itemCount: widget.controller.instaTalkRequests.length,
          itemBuilder: (context, index) {
            final instaTalk = widget.controller.instaTalkRequests[index];
            return _buildInstaTalkCard(instaTalk);
          },
        );
      }),
    );
  }

  Widget _buildEmptyInstaTalkView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.quickreply_rounded,
              size: 48,
              color: AppColors.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No InstaTalk Requests',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'You don\'t have any InstaTalk requests at the moment. InstaTalk lets you have quick chats, calls or video calls.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstaTalkCard(Map<String, dynamic> instaTalk) {
    final bool isSender = widget.controller.isInstaTalkSender(instaTalk);
    final bool canInteract =
        widget.controller.canInteractWithRequest(instaTalk);
    final String displayName =
        widget.controller.getInstaTalkDisplayName(instaTalk);
    final String type = instaTalk['type'] ?? 'chat';
    final bool hasUsedTime = isSender
        ? instaTalk['userOneTimeUsed'] ?? false
        : instaTalk['userTwoTimeUsed'] ?? false;
    final bool isAccepted = instaTalk['acceptedByParticipant'] == true;
    final bool isExpired = widget.controller.isInstaTalkExpired(instaTalk);
    final bool isActive = !isExpired && instaTalk['status'] != 'completed';

    // Get the other user's ID for online status check
    final otherUserId =
        isSender ? instaTalk['participant']['_id'] : instaTalk['user']['_id'];

    // Use StreamBuilder instead of FutureBuilder to get real-time updates
    return StreamBuilder<bool>(
      // This stream will emit updates whenever the user's online status changes
      stream: userOnlineController.getUserStatusStream(otherUserId),
      initialData: false, // Initially assume offline until we get data
      builder: (context, onlineSnapshot) {
        final bool isOtherUserOnline = onlineSnapshot.data ?? false;

        // Add nested StreamBuilder for call status
        return StreamBuilder<Map<String, dynamic>>(
            stream: Get.find<CallStatusController>()
                .getUserCallStatusStream(otherUserId),
            initialData: {'inCall': false},
            builder: (context, callSnapshot) {
              final bool isUserInCall = callSnapshot.data?['inCall'] ?? false;
              final String? callType = callSnapshot.data?['callType'];

              final bool canJoin = isAccepted &&
                  isActive &&
                  !hasUsedTime &&
                  isOtherUserOnline &&
                  !isUserInCall;

              final DateTime createdAt =
                  DateTime.parse(instaTalk['scheduledTime']);
              final String timeAgo = timeago.format(createdAt);

              final now = DateTime.now();
              final int minutesSinceCreation =
                  now.difference(createdAt).inMinutes;
              final int minutesRemaining = 60 - minutesSinceCreation;
              final bool isNearExpiration =
                  minutesRemaining <= 10 && minutesRemaining > 0;

              IconData typeIcon;
              String typeText;
              switch (type) {
                case 'voice':
                  typeIcon = Icons.call_outlined;
                  typeText = 'Voice';
                  break;
                case 'video':
                  typeIcon = Icons.videocam_outlined;
                  typeText = 'Video';
                  break;
                default:
                  typeIcon = Icons.chat_outlined;
                  typeText = 'Chat';
              }

              Color borderColor;
              if (isExpired) {
                borderColor = Colors.grey.withOpacity(0.5);
              } else if (isAccepted) {
                borderColor = Colors.green.withOpacity(0.5);
              } else {
                borderColor = Colors.amber.withOpacity(0.5);
              }

              return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.blueGrey.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: borderColor,
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: borderColor,
                                      width: 2,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 24,
                                    backgroundImage: _getProfileImage(isSender
                                        ? instaTalk['participant']
                                        : instaTalk['user']),
                                    child: _getProfileImage(isSender
                                                ? instaTalk['participant']
                                                : instaTalk['user']) ==
                                            null
                                        ? const Icon(Icons.person,
                                            color: Colors.white70)
                                        : null,
                                  ),
                                ),
                                // Online status indicator
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: isOtherUserOnline
                                          ? Colors.green
                                          : Colors.grey,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.black,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          displayName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(
                                              isExpired, isAccepted),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _getStatusText(isExpired, isAccepted),
                                          style: TextStyle(
                                            color: _getStatusTextColor(
                                                isExpired, isAccepted),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),

                                      // Add call status tag
                                      if (!isExpired && isAccepted) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isUserInCall
                                                ? Colors.red.withOpacity(0.2)
                                                : Colors.green.withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isUserInCall
                                                  ? Colors.red.withOpacity(0.3)
                                                  : Colors.green
                                                      .withOpacity(0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            isUserInCall ? 'IN CALL' : 'IDLE',
                                            style: TextStyle(
                                              color: isUserInCall
                                                  ? Colors.red
                                                  : Colors.green,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        typeIcon,
                                        size: 16,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$typeText',
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 13,
                                        ),
                                      ),
                                      const Spacer(),
                                      // Online status text
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            isUserInCall
                                                ? '• In a ${callType ?? ""} call'
                                                : isOtherUserOnline
                                                    ? '• Online'
                                                    : '• Offline',
                                            style: TextStyle(
                                              color: isUserInCall
                                                  ? Colors.red
                                                  : isOtherUserOnline
                                                      ? Colors.green
                                                      : Colors.grey,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        timeAgo,
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                          fontWeight:
                                              isNearExpiration && !isExpired
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 12, left: 4),
                          child: Row(
                            children: [
                              Icon(
                                isSender
                                    ? Icons.arrow_outward
                                    : Icons.arrow_downward,
                                size: 14,
                                color: isSender
                                    ? Colors.blue.withOpacity(0.7)
                                    : Colors.green.withOpacity(0.7),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  isSender ? 'Sent' : 'Received',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSender
                                        ? Colors.blue.withOpacity(0.7)
                                        : Colors.green.withOpacity(0.7),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isExpired) ...[
                          if (canInteract)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton(
                                    onPressed: () =>
                                        _declineInstaTalk(instaTalk['_id']),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.grey[400],
                                      side:
                                          BorderSide(color: Colors.grey[700]!),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text('Decline'),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton(
                                    onPressed: () =>
                                        _acceptInstaTalk(instaTalk['_id']),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text('Accept'),
                                  ),
                                ],
                              ),
                            ),
                          if (isAccepted && isActive)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: SizedBox(
                                width: double.infinity,
                                // Only show join button for voice/video if user is creator, or for chat type
                                child: (type == 'voice' || type == 'video') &&
                                        !isSender
                                    ? Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: Colors.amber
                                                  .withOpacity(0.3)),
                                        ),
                                        child: Column(
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.info_outline,
                                                  color: Colors.amber,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'You will be notified when $displayName joins the call',
                                                    style: TextStyle(
                                                      color: Colors.amber,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                        ),
                                      )
                                    : hasUsedTime
                                        ? Padding(
                                            padding:
                                                const EdgeInsets.only(top: 16),
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppColors.primaryColor,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                              onPressed: () =>
                                                  _showContinueInstaTalkDialog(
                                                      instaTalk),
                                              child: Text(
                                                'Renew',
                                                style: GoogleFonts.manrope(
                                                    color: Colors.white),
                                              ),
                                            ),
                                          )
                                        : ElevatedButton.icon(
                                            onPressed: (hasUsedTime ||
                                                    !isOtherUserOnline ||
                                                    isUserInCall ||
                                                    ((type == 'voice' ||
                                                            type == 'video') &&
                                                        !isSender))
                                                ? null
                                                : () =>
                                                    _joinInstaTalk(instaTalk),
                                            icon: _getTypeIcon(type),
                                            label: Text(hasUsedTime
                                                ? 'Already Joined'
                                                : isUserInCall
                                                    ? 'User is in a Call'
                                                    : !isOtherUserOnline
                                                        ? 'Waiting for User to be Online'
                                                        : 'Join InstaTalk'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: hasUsedTime
                                                  ? Colors.grey
                                                  : isUserInCall
                                                      ? Colors.red.shade400
                                                      : !isOtherUserOnline
                                                          ? Colors.amber
                                                          : Colors.green,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 12),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                          ),
                              ),
                            ),
                        ],
                        if (hasUsedTime)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.grey.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle_outline,
                                      color: Colors.grey[400], size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'You have already joined this InstaTalk session',
                                      style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (!isOtherUserOnline &&
                            isAccepted &&
                            isActive &&
                            !hasUsedTime)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.amber.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      color: Colors.amber, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Waiting for ${displayName} to be online',
                                      style: TextStyle(
                                          color: Colors.amber, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        if (!isOtherUserOnline &&
                            !isAccepted &&
                            isActive &&
                            !hasUsedTime)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.blueAccent.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.timer_outlined,
                                      color: Colors.blueAccent, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Waiting for ${displayName} to acccept the request',
                                      style: TextStyle(
                                          color: Colors.blueAccent,
                                          fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // if (hasUsedTime)
                        //   Padding(
                        //     padding: const EdgeInsets.only(top: 16),
                        //     child: ElevatedButton(
                        //       style: ElevatedButton.styleFrom(
                        //         backgroundColor: AppColors.primaryColor,
                        //         shape: RoundedRectangleBorder(
                        //           borderRadius: BorderRadius.circular(8),
                        //         ),
                        //       ),
                        //       onPressed: () =>
                        //           _showContinueInstaTalkDialog(instaTalk),
                        //       child: Text(
                        //         'Continue Session',
                        //         style: GoogleFonts.manrope(color: Colors.white),
                        //       ),
                        //     ),
                        //   ),
                        if (isUserInCall &&
                            isAccepted &&
                            isActive &&
                            !hasUsedTime)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.red.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.call_end_rounded,
                                      color: Colors.red, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '$displayName is currently in a ${callType ?? ""} call',
                                      style: TextStyle(
                                          color: Colors.red, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ));
            });
      },
    );
  }

  Color _getStatusColor(bool isExpired, bool isAccepted) {
    if (isExpired) return Colors.grey.withOpacity(0.2);
    if (isAccepted) return Colors.green.withOpacity(0.2);
    return Colors.amber.withOpacity(0.2);
  }

  Color _getStatusTextColor(bool isExpired, bool isAccepted) {
    if (isExpired) return Colors.grey;
    if (isAccepted) return Colors.green;
    return Colors.amber;
  }

  String _getStatusText(bool isExpired, bool isAccepted) {
    if (isExpired) return 'Expired';
    if (isAccepted) return 'Accepted';
    return 'Pending';
  }

  void _declineInstaTalk(String meetingId) async {
    final bool confirm = await Get.dialog<bool>(
          AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: const Text(
              'Decline InstaTalk?',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Are you sure you want to decline this InstaTalk request?',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                onPressed: () => Get.back(result: true),
                child: const Text('Decline'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      await widget.controller.declineInstaTalk(meetingId);
    }
  }

  void _acceptInstaTalk(String meetingId) async {
    final result = await widget.controller.acceptInstaTalk(meetingId);
    if (result != null) {
      _joinInstaTalk(result);
    }
  }

  void _joinInstaTalk(Map<String, dynamic> instaTalk) async {
    try {
      final String meetingId = instaTalk['_id'] ?? '';
      final String type = instaTalk['type'] ?? 'chat';
      final bool isAccepted = instaTalk['acceptedByParticipant'] == true;
      final bool isSender = widget.controller.isInstaTalkSender(instaTalk);
      final int renewalCount = instaTalk['renewalCount'] ?? 0;
      final bool isTrial = renewalCount == 0;

      print('InstaTalk join - renewalCount: $renewalCount, isTrial: $isTrial');

      final bool hasUsedTime = isSender
          ? instaTalk['userOneTimeUsed'] ?? false
          : instaTalk['userTwoTimeUsed'] ?? false;

      if (hasUsedTime) {
        Get.snackbar(
          'Session Already Used',
          'You have already joined this InstaTalk session',
          backgroundColor: Colors.orange.withOpacity(0.8),
          colorText: Colors.white,
        );
        return;
      }

      // Get the other user's ID
      final otherUserId =
          isSender ? instaTalk['participant']['_id'] : instaTalk['user']['_id'];

      // Show loading indicator while checking online status
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(),
        ),
        barrierDismissible: false,
      );

      // Check if the other user is online before proceeding
      final userOnlineController = Get.find<UserOnlineController>();

      // Get the most up-to-date online status directly from the socket
      // This ensures we have the latest status before joining
      userOnlineController.clearUserStatusCache(otherUserId);
      final bool isOtherUserOnline =
          await userOnlineController.isUserOnline(otherUserId);

      // Close loading dialog
      Get.back();

      if (!isOtherUserOnline) {
        Get.snackbar(
          'User Offline',
          'This user is currently offline. Please try again when they are online.',
          backgroundColor: Colors.orange.withOpacity(0.8),
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      final success = await widget.controller.updateInstaTalkTimeUsage(
        meetingId: meetingId,
        isUserOne: isSender,
      );

      if (!success) {
        Get.snackbar(
          'Error',
          'Unable to start InstaTalk session',
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
        );
        return;
      }

      final participant = User.fromJson(
          isSender ? instaTalk['participant'] : instaTalk['user']);
      final liveRate = participant.earnings?.live ?? 0.0;

      switch (type) {
        case 'chat':
          await Get.to(() => ChatRoomScreen(
                profile: participant,
                isInstaTalk: true,
                isTrial: isTrial,
                duration: instaTalk['duration'] ?? 30,
                isInstaTalkSender:
                    widget.controller.isInstaTalkSender(instaTalk),
              ));
          break;

        case 'voice':
          await Get.to(() => VoiceCallLoadingScreen(
                participant: participant,
                scheduleTime: DateTime.now(),
                type: "voice",
                isInstaTalk: true,
                isTrial: isTrial,
                instaTalkDuration: instaTalk['duration'] ?? 30,
              ));
          break;

        case 'video':
          await Get.to(() => VideoCallLoadingScreen(
                participant: participant,
                scheduleTime: DateTime.now(),
                type: "video",
                isInstaTalk: true,
                isTrial: isTrial,
                instaTalkDuration: instaTalk['duration'] ?? 30,
              ));
          break;

        default:
          Get.snackbar(
            'Error',
            'Unknown InstaTalk type',
            backgroundColor: Colors.red.withOpacity(0.8),
            colorText: Colors.white,
          );
      }
    } catch (e) {
      print('Error joining InstaTalk: $e');
      Get.snackbar(
        'Error',
        'Failed to join InstaTalk',
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
  }

  void _showContinueInstaTalkDialog(Map<String, dynamic> instaTalk) async {
    try {
      // Get the user profile and their live rate
      final isSender = widget.controller.isInstaTalkSender(instaTalk);
      final userData = isSender ? instaTalk['participant'] : instaTalk['user'];
      final user = User.fromJson(userData);
      final liveRate = user.earnings?.liveRate ?? 500.0;

      final walletController = Get.find<WalletController>();
      final hasEnoughBalance = walletController.hasEnoughBalance(liveRate);

      final shouldContinue = await Get.dialog<bool>(
        AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Continue InstaTalk Session',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Continue InstaTalk session with ${user.name}?',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Text(
                'Rate: ₹${liveRate.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!hasEnoughBalance) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.5)),
                  ),
                  child: const Text(
                    'Insufficient wallet balance. Please add funds.',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: hasEnoughBalance
                  ? () => Get.back(result: true)
                  : () {
                      Get.back(result: false);
                      Get.toNamed('/wallet/topup');
                    },
              child: Text(hasEnoughBalance ? 'Continue' : 'Add Funds'),
            ),
          ],
        ),
      );

      if (shouldContinue ?? false) {
        // Show loading indicator
        Get.dialog(
          Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.secondaryBackground,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: AppColors.primaryColor,
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Processing payment...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
          barrierDismissible: false,
        );

        // Process payment
        final deductResponse = await ApiService.deductMoneyToWallet(liveRate);
        if (deductResponse.statusCode == 200) {
          // Reset the time usage flags in the backend
          final success = await widget.controller.renewInstatalk(
            meetingId: instaTalk['_id'],
            isUserOne: isSender,
          );

          // Close loading dialog
          Get.back();

          if (success) {
            // Reset usage flags locally
            final updatedInstaTalk = Map<String, dynamic>.from(instaTalk);
            if (isSender) {
              updatedInstaTalk['userOneTimeUsed'] = false;
            } else {
              updatedInstaTalk['userTwoTimeUsed'] = false;
            }

            // Update the request in the controller
            final index = widget.controller.instaTalkRequests.indexWhere(
              (req) => req['_id'] == instaTalk['_id'],
            );
            if (index != -1) {
              widget.controller.instaTalkRequests[index] = updatedInstaTalk;
            }

            // Show success message
            Get.snackbar(
              'Session Renewed',
              'You can now join the InstaTalk session with ${user.name}',
              backgroundColor: Colors.green,
              colorText: Colors.white,
              duration: const Duration(seconds: 3),
              snackPosition: SnackPosition.BOTTOM,
              margin: const EdgeInsets.all(10),
              borderRadius: 10,
            );

            // Refresh the InstaTalk list
            widget.controller.fetchInstaTalkRequests();
          } else {
            throw Exception('Failed to update InstaTalk status');
          }
        } else {
          // Close loading dialog
          Get.back();
          throw Exception('Failed to process payment');
        }
      }
    } catch (e) {
      // Close loading dialog if it's open
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      Get.snackbar(
        'Error',
        'Failed to continue session: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  ImageProvider? _getProfileImage(dynamic user) {
    if (user == null) return null;

    if (user['photos'] is List && user['photos'].isNotEmpty) {
      return NetworkImage(user['photos'][0]);
    }

    return null;
  }

  Icon _getTypeIcon(String type) {
    switch (type) {
      case 'voice':
        return const Icon(Icons.call_outlined);
      case 'video':
        return const Icon(Icons.videocam_outlined);
      default:
        return const Icon(Icons.chat_outlined);
    }
  }
}

class EmptyRequestsView extends StatelessWidget {
  const EmptyRequestsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.people_outline_rounded,
                  size: 48,
                  color: AppColors.primaryColor,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'No Friend Requests',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "You don't have any pending friend requests at the moment. When someone sends you a request, it will appear here.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              _buildPlaceholderCard(opacity: 1.0),
              const SizedBox(height: 12),
              _buildPlaceholderCard(opacity: 0.7),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderCard({required double opacity}) {
    return Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blueGrey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accentColor.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: const CircleAvatar(
                radius: 30,
                backgroundColor: Colors.black12,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 80,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Container(
                  width: 80,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.greenColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 80,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.redColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class EmptySentRequestsView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.send_rounded,
                size: 48,
                color: AppColors.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Sent Requests',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "You haven't sent any friend requests yet. Find people you'd like to connect with and send them a request!",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
