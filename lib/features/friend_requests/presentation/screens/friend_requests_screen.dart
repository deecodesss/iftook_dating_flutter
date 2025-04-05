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
import 'package:iftook/helpers/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

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
    // Convert to IST (UTC+5:30)
    final meetingTime =
        meetingTimeUtc.add(const Duration(hours: 5, minutes: 30));

    final now = DateTime.now().add(const Duration(hours: 5, minutes: 30));
    final tomorrow = now.add(const Duration(days: 1));

    if (now.difference(meetingTime).inMinutes <= 30 &&
        now.difference(meetingTime).inMinutes >= 0) {
      return 'Join Now';
    }

    if (meetingTime.difference(now).inMinutes <= 60 &&
        meetingTime.isAfter(now)) {
      return 'In ${meetingTime.difference(now).inMinutes} min';
    }

    if (meetingTime.year == now.year &&
        meetingTime.month == now.month &&
        meetingTime.day == now.day) {
      return 'Today, ${DateFormat('h:mm a').format(meetingTime)}';
    }

    if (meetingTime.year == tomorrow.year &&
        meetingTime.month == tomorrow.month &&
        meetingTime.day == tomorrow.day) {
      return 'Tomorrow, ${DateFormat('h:mm a').format(meetingTime)}';
    }

    return DateFormat('MMM d, h:mm a').format(meetingTime);
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

  void _handleInstaTalkJoin(Map<String, dynamic> meeting) async {
    final participantData = meeting['participant'];
    final type = meeting['type'];
    final amount = (meeting['amount'] ?? 0).toDouble();

    final participant = User(
      sId: participantData['_id'],
      name: participantData['name'],
      photos: participantData['photos'] is List
          ? List<String>.from(participantData['photos'])
          : [],
    );

    try {
      switch (type) {
        case 'chat':
          await Get.to(() => ChatRoomScreen(
                profile: participant,
                isInstaTalk: true,
                instaTalkDuration: 30, // 30 seconds for InstaTalk
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
                instaTalkDuration: 30, // 30 seconds for InstaTalk
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
                instaTalkDuration: 30, // 30 seconds for InstaTalk
                onSessionEnd: () =>
                    _showContinueSessionDialog(participant, amount, type),
              ));
          break;
      }
    } catch (e) {
      print('Navigation error: $e');
      // Handle any navigation errors here
    }
  }

  void _handleMeetingJoin(Map<String, dynamic> meeting) async {
    final participantData = meeting['participant'];
    final type = meeting['type'];
    final amount = (meeting['amount'] ?? 0).toDouble();

    final participant = User(
      sId: participantData['_id'],
      name: participantData['name'],
      photos: participantData['photos'] is List
          ? List<String>.from(participantData['photos'])
          : [],
    );

    try {
      switch (type) {
        case 'chat':
          await Get.to(() => ChatRoomScreen(
                profile: participant,
                isInstaTalk: false,
                instaTalkDuration: 1800, // 30 minutes in seconds
                onSessionEnd: () =>
                    _showContinueSessionDialog(participant, amount, type),
              ));
          break;

        case 'voice':
          await Get.to(() => VoiceCallLoadingScreen(
                participant: participant,
                scheduleTime: DateTime.now(),
                type: "voice",
                isInstaTalk: false,
                instaTalkDuration: 1800, // 30 minutes in seconds
                onSessionEnd: () =>
                    _showContinueSessionDialog(participant, amount, type),
              ));
          break;

        case 'video':
          await Get.to(() => VideoCallLoadingScreen(
                participant: participant,
                scheduleTime: DateTime.now(),
                type: "video",
                isInstaTalk: false,
                instaTalkDuration: 1800, // 30 minutes in seconds
                onSessionEnd: () =>
                    _showContinueSessionDialog(participant, amount, type),
              ));
          break;
      }
    } catch (e) {
      print('Navigation error: $e');
      // Handle any navigation errors here
    }
  }

  void _handleJoinMeeting(Map<String, dynamic> meeting) async {
    final isInstaTalk =
        meeting['isInstaTalk'] ?? false; // Add this flag in your meeting data

    if (isInstaTalk) {
      _handleInstaTalkJoin(meeting);
    } else {
      _handleMeetingJoin(meeting);
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
          Get.off(() => ChatRoomScreen(
                profile: participant,
                isInstaTalk: true,
                instaTalkDuration: 30,
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
                                email: participant['email']?.toString() ?? '',
                                dob: participant['dob']?.toString() ?? '',
                                gender: participant['gender']?.toString() ?? '',
                                profession:
                                    participant['profession']?.toString() ??
                                        'Not specified',
                                about: participant['about']?.toString() ??
                                    'No information available',
                                interestedIn:
                                    participant['interestedIn']?.toString() ??
                                        '',
                                photos: participant['photos'] is List
                                    ? List<String>.from(participant['photos'])
                                    : [],
                                location: participant['location'] is Map
                                    ? Location(
                                        city: participant['location']['city']
                                                ?.toString() ??
                                            'Unknown',
                                        state: participant['location']['state']
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
                                isOnline: participant['isOnline'] ?? false,
                              );

                              Get.to(() =>
                                  UserProfileScreen(profile: safeProfile));
                            } catch (e) {
                              Get.snackbar(
                                'Error',
                                'Could not open profile details',
                                backgroundColor: Colors.red.withOpacity(0.7),
                                colorText: Colors.white,
                              );
                            }
                          },
                          child: CircleAvatar(
                            radius: 30,
                            backgroundImage: participant['photos'] != null &&
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
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color:
                                _getStatusColor(currentStatus).withOpacity(0.2),
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
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        _formatMeetingTime(scheduledTime),
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Row(
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
                          isCreator
                              ? 'You requested meeting with ${participant['name'] ?? "them"}'
                              : 'Meeting request from ${user['name'] ?? "someone"}',
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
                  ],
                ),
              ),
              if (canJoin)
                Padding(
                  padding: const EdgeInsets.only(
                      top: 8, left: 24, right: 24, bottom: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _handleJoinMeeting(meeting),
                      icon: Icon(
                        type == 'video'
                            ? Icons.videocam
                            : type == 'voice'
                                ? Icons.call
                                : Icons.chat,
                        color: Colors.white,
                      ),
                      label: const Text('Join Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
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
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return RefreshIndicator(
      onRefresh: () async {
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
    final bool canJoin = isAccepted && isActive && !hasUsedTime;

    final DateTime createdAt = DateTime.parse(instaTalk['scheduledTime']);
    final String timeAgo = timeago.format(createdAt);

    final now = DateTime.now();
    final int minutesSinceCreation = now.difference(createdAt).inMinutes;
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        ? const Icon(Icons.person, color: Colors.white70)
                        : null,
                  ),
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
                              color: _getStatusColor(isExpired, isAccepted),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getStatusText(isExpired, isAccepted),
                              style: TextStyle(
                                color:
                                    _getStatusTextColor(isExpired, isAccepted),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
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
                            '$typeText InstaTalk',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            isNearExpiration && !isExpired
                                ? 'Expires in ${minutesRemaining}m'
                                : timeAgo,
                            style: TextStyle(
                              color: isNearExpiration && !isExpired
                                  ? Colors.orange
                                  : Colors.grey[500],
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              fontWeight: isNearExpiration && !isExpired
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
                    isSender ? Icons.arrow_outward : Icons.arrow_downward,
                    size: 14,
                    color: isSender
                        ? Colors.blue.withOpacity(0.7)
                        : Colors.green.withOpacity(0.7),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      isSender
                          ? 'You sent a quick $type InstaTalk to $displayName'
                          : '$displayName sent you a quick $type InstaTalk request',
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
                        onPressed: () => _declineInstaTalk(instaTalk['_id']),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[400],
                          side: BorderSide(color: Colors.grey[700]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Decline'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () => _acceptInstaTalk(instaTalk['_id']),
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
              if (canJoin)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          hasUsedTime ? null : () => _joinInstaTalk(instaTalk),
                      icon: _getTypeIcon(type),
                      label: Text(
                          hasUsedTime ? 'Already Joined' : 'Join InstaTalk'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            hasUsedTime ? Colors.grey : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
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
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          color: Colors.grey[400], size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You have already joined this InstaTalk session',
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (isExpired)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer_off_outlined,
                        color: Colors.grey[400],
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This InstaTalk request has expired',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
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
    final String meetingId = instaTalk['_id'] ?? '';
    final String type = instaTalk['type'] ?? 'chat';
    final bool isAccepted = instaTalk['acceptedByParticipant'] == true;
    final bool isSender = widget.controller.isInstaTalkSender(instaTalk);

    final bool hasUsedTime = isSender
        ? instaTalk['userOneTimeUsed'] ?? false
        : instaTalk['userTwoTimeUsed'] ?? false;

    if (hasUsedTime) {
      Get.snackbar(
        'Already Used',
        'You have already joined this InstaTalk session',
        backgroundColor: Colors.orange.withOpacity(0.8),
        colorText: Colors.white,
      );
      return;
    }

    try {
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

      switch (type) {
        case 'chat':
          Get.to(() => ChatRoomScreen(
                profile: participant,
                isInstaTalk: true,
                instaTalkDuration: 30,
              ));
          break;

        case 'voice':
          Get.to(() => VoiceCallLoadingScreen(
                participant: participant,
                scheduleTime: DateTime.now(),
                type: "voice",
                isInstaTalk: true,
                instaTalkDuration: 30,
              ));
          break;

        case 'video':
          Get.to(() => VideoCallLoadingScreen(
                participant: participant,
                scheduleTime: DateTime.now(),
                type: "video",
                isInstaTalk: true,
                instaTalkDuration: 30,
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
