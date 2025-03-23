import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/core/services/api_service.dart';
import 'package:iftook/features/friend_requests/controller/friend_controller.dart';
import 'package:iftook/features/friend_requests/data/models/friend_request.dart';
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
        TabController(length: 3, vsync: this); // Changed from 2 to 3
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
    controller.fetchFriendRequests();
    controller.fetchSentRequests();
    controller.fetchMeetings(); // Add this
  }

  @override
  void dispose() {
    _tabController.dispose();
    _timer.cancel();
    super.dispose();
  }

  String _formatMeetingTime(DateTime meetingTime) {
    final now = DateTime.now();
    final tomorrow = DateTime.now().add(const Duration(days: 1));

    // If meeting time is within last 30 minutes
    if (now.difference(meetingTime).inMinutes <= 30 &&
        now.difference(meetingTime).inMinutes >= 0) {
      return 'Join Now';
    }

    // If meeting is coming up within next hour
    if (meetingTime.difference(now).inMinutes <= 60 &&
        meetingTime.isAfter(now)) {
      return 'In ${meetingTime.difference(now).inMinutes} min';
    }

    // If meeting is today
    if (meetingTime.year == now.year &&
        meetingTime.month == now.month &&
        meetingTime.day == now.day) {
      return 'Today, ${DateFormat('h:mm a').format(meetingTime)}';
    }

    // If meeting is tomorrow
    if (meetingTime.year == tomorrow.year &&
        meetingTime.month == tomorrow.month &&
        meetingTime.day == tomorrow.day) {
      return 'Tomorrow, ${DateFormat('h:mm a').format(meetingTime)}';
    }

    // Otherwise show full date
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
                        // Get current user ID
                        final currentUserId =
                            await SharedPrefs.getUserIdSharedPreference();
                        if (currentUserId != null) {
                          // Get friend request to find the requester ID
                          final request = controller.friendRequests.firstWhere(
                            (req) => req.sId == reqId,
                            orElse: () => FriendRequest(),
                          );

                          if (request.requester?.sId != null) {
                            // Call unfriend with both IDs
                            await controller.deleteSentRequest(
                              currentUserId,
                            );
                          }

                          // Also reject the request using the existing method
                          // controller.rejectRequest(reqId, context);
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

  // Add this helper method to convert UTC to IST
  DateTime _convertToIST(DateTime utc) {
    // Subtract 5 hours and 30 minutes to compensate for IST difference
    return utc.subtract(const Duration(hours: 5, minutes: 30));
  }

  String _getMeetingStatus(DateTime scheduledTime, String currentStatus) {
    // Convert scheduled time to correct time by subtracting IST offset
    final adjustedScheduledTime = _convertToIST(scheduledTime);
    final now = DateTime.now();
    final minutesDifference = now.difference(adjustedScheduledTime).inMinutes;

    print('Current time: ${now.toString()}');
    print('Original scheduled time: ${scheduledTime.toString()}');
    print('Adjusted scheduled time: ${adjustedScheduledTime.toString()}');
    print('Time difference in minutes: $minutesDifference');

    // Meeting is in the past (more than 30 mins past scheduled time)
    if (minutesDifference > 30) {
      if (currentStatus == 'completed') return 'Completed';
      if (currentStatus == 'cancelled') return 'Cancelled';
      return 'Expired';
    }

    // Meeting is live (within 30 mins window after scheduled time)
    if (minutesDifference >= 0 && minutesDifference <= 30) {
      if (currentStatus == 'completed') return 'Completed';
      if (currentStatus == 'cancelled') return 'Cancelled';
      return 'Join Now';
    }

    // Meeting is in the future
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
      print('Loading profile for user ID: $userId');

      Get.dialog(
        WillPopScope(
          onWillPop: () async => false, // Prevent dismissal on back press
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
        Get.back(); // Close loading dialog
        Get.to(() => UserProfileScreen(profile: userProfile));
      } else {
        throw Exception('Failed to load profile data');
      }
    } catch (e) {
      print('Failed to load profile: $e');
      Get.back(); // Close loading dialog
      Get.snackbar(
        'Error',
        'Could not load profile. Please try again.',
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }

  Widget _buildMeetingCard(Map<String, dynamic> meeting) {
    final scheduledTime = DateTime.parse(meeting['scheduledTime']);
    final participant = meeting['participant'] as Map<String, dynamic>;
    final user =
        meeting['user'] as Map<String, dynamic>; // Get the user/sender data
    final status = meeting['status'];
    final type = meeting['type'];
    final userId = user['_id'];
    final amount = (meeting['amount'] ?? 0).toDouble();

    print('Building meeting card with meeting data: $meeting');

    return FutureBuilder<String?>(
      future: SharedPrefs.getUserIdSharedPreference(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final currentUserId = snapshot.data!;
        final isCreator = userId == currentUserId;

        // Determine which name to display based on whether it's incoming or outgoing
        final displayName = isCreator
            ? participant['name'] ??
                'Unknown' // Outgoing meeting: show participant name
            : user['name'] ?? 'Unknown'; // Incoming meeting: show sender name

        return Obx(() {
          final currentStatus =
              controller.getMeetingStatus(scheduledTime, status);
          final now = controller.currentTime.value;
          final minutesDifference = now
              .difference(
                  scheduledTime.subtract(const Duration(hours: 5, minutes: 30)))
              .inMinutes;
          final canJoin = minutesDifference >= 0 && minutesDifference <= 30;

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
                // Debug Time Info (Only in Debug Mode)
                if (false) // Change to !kReleaseMode for production
                  Container(
                    padding: const EdgeInsets.all(8),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current: ${DateFormat('MMM d, h:mm:ss a').format(now)}',
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                        Text(
                          'Original scheduled time: ${DateFormat('MMM d, h:mm a').format(scheduledTime)}',
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                        Text(
                          'Adjusted (-5:30): ${DateFormat('MMM d, h:mm a').format(scheduledTime.subtract(const Duration(hours: 5, minutes: 30)))}',
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                        Text(
                          'Minutes Until/Past: ${DateTime.now().difference(scheduledTime.subtract(const Duration(hours: 5, minutes: 30))).inMinutes}',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User Info Row
                      Row(
                        children: [
                          // Profile Picture - Direct navigation approach
                          InkWell(
                            onTap: () {
                              try {
                                // Create User object with essential fields and safe fallbacks
                                final safeProfile = User(
                                  sId: participant['_id']?.toString() ?? '',
                                  name: participant['name']?.toString() ??
                                      'Unknown',
                                  email: participant['email']?.toString() ?? '',
                                  dob: participant['dob']?.toString() ?? '',
                                  gender:
                                      participant['gender']?.toString() ?? '',
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
                                  // Add other fields with safe defaults
                                  walletBalance: 0,
                                  earnings: Earnings(),
                                  isOnline: participant['isOnline'] ?? false,
                                );

                                print(
                                    'Navigating to meeting participant profile: ${safeProfile.name}');
                                Get.to(() =>
                                    UserProfileScreen(profile: safeProfile));
                              } catch (e) {
                                print(
                                    'Error navigating to meeting participant profile: $e');
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

                          // Meeting Info - Update the name display
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName, // Use our conditional name logic
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

                          // Status Badge
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

                      // Time Display
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

                      // Add Direction Indicator (Incoming/Outgoing)
                      Row(
                        children: [
                          Icon(
                            isCreator
                                ? Icons.call_made_rounded // Outgoing arrow
                                : Icons.call_received_rounded, // Incoming arrow
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

                // Join button for active meetings
                if (currentStatus == 'Join Now')
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Colors.grey[850]!,
                          width: 1,
                        ),
                      ),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Handle join meeting
                      },
                      icon: Icon(
                        type == 'video'
                            ? Icons.videocam
                            : type == 'voice'
                                ? Icons.phone
                                : Icons.chat,
                        size: 20,
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
                print("Requester: $request.requester!");
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Connections',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
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
          labelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'Meetings'),
            Tab(text: 'Requests'),
            Tab(text: 'Sent'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        // Use physics that don't interfere with inner scrolling
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Meetings Tab - Use a separate widget with keep-alive behavior
          MeetingsTabView(
            controller: controller,
            buildMeetingCard: _buildMeetingCard,
            buildEmptyView: _buildEmptyMeetingsView,
          ),

          // Requests Tab
          FriendRequestsTabView(
            controller: controller,
            buildRequestCard: _buildRequestCard,
          ),

          // Sent Requests Tab
          SentRequestsTabView(
            controller: controller,
            buildSentRequestCard: _buildSentRequestCard,
          ),
        ],
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
                print("Receiver: $receiver!");
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
                  onPressed: () =>
                      _showDeleteSentRequestWarning(context, request.sId ?? ''),
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

  // Add a new method for the delete sent request confirmation dialog
  void _showDeleteSentRequestWarning(BuildContext context, String reqId) {
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
                  Icons.delete_outline,
                  color: AppColors.redColor,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Delete Friend Request?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to delete this friend request? The person will not be notified.',
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
                        controller.deleteSentRequest(currentUserId!);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.redColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text('Delete'),
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

  String _getCallTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'video':
        return 'Video Call';
      case 'voice':
        return 'Voice Call';
      default:
        return 'Chat';
    }
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

  String _getTimeUntilMeeting(DateTime scheduledTime) {
    final now = DateTime.now();
    // Convert scheduled time to local if it's in UTC
    final localScheduledTime = scheduledTime.toLocal();
    final difference = localScheduledTime.difference(now);

    if (difference.isNegative) {
      final past = -difference.inMinutes;
      if (past < 60) {
        return '$past minutes ago';
      } else if (past < 1440) {
        // Less than 24 hours
        return '${(past / 60).round()} hours ago';
      } else {
        return '${(past / 1440).round()} days ago';
      }
    } else {
      if (difference.inMinutes < 60) {
        return 'In ${difference.inMinutes} minutes';
      } else if (difference.inHours < 24) {
        return 'In ${difference.inHours} hours';
      } else {
        return 'In ${difference.inDays} days';
      }
    }
  }

  Color _getTimeColor(int minutesDifference) {
    if (minutesDifference > 30) return Colors.red[400]!;
    if (minutesDifference >= 0) return Colors.green;
    return Colors.blue;
  }
}

// Add these new widget classes for each tab:

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
  // Store meetings in local state to avoid reactive rebuilds
  final List<Map<String, dynamic>> _meetings = [];
  bool _isLoading = true;

  // Use a GlobalKey for better persistence
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Fetch data once and store in local state
    _fetchMeetings();
  }

  Future<void> _fetchMeetings() async {
    setState(() => _isLoading = true);

    // Wait for a short delay to ensure everything is properly initialized
    await Future.delayed(Duration.zero);

    // Make a local copy of meetings to avoid reactivity issues
    if (widget.controller.meetings.isNotEmpty) {
      _meetings.clear();
      _meetings.addAll(widget.controller.meetings.cast<Map<String, dynamic>>());
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_meetings.isEmpty) {
      return widget.buildEmptyView();
    }

    // Use a more stable scrolling solution
    return RefreshIndicator(
      onRefresh: _fetchMeetings,
      child: NotificationListener<ScrollNotification>(
        // Prevent scroll notifications from propagating upwards
        onNotification: (ScrollNotification scrollInfo) => true,
        child: CustomScrollView(
          // Disable physics that might interfere
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final meeting = _meetings[index];
                    // Use stable, non-reactive build method
                    return widget.buildMeetingCard(meeting);
                  },
                  childCount: _meetings.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FriendRequestsTabView extends StatefulWidget {
  final FriendController controller;
  final Function(FriendRequest) buildRequestCard;

  const FriendRequestsTabView({
    Key? key,
    required this.controller,
    required this.buildRequestCard,
  }) : super(key: key);

  @override
  State<FriendRequestsTabView> createState() => _FriendRequestsTabViewState();
}

class _FriendRequestsTabViewState extends State<FriendRequestsTabView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Obx(() {
      if (widget.controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      return widget.controller.friendRequests.length < 1
          ? const EmptyRequestsView()
          : ListView.builder(
              key: const PageStorageKey<String>('requests_list'),
              padding: const EdgeInsets.symmetric(vertical: 8),
              physics: const ClampingScrollPhysics(),
              itemCount: widget.controller.friendRequests.length,
              itemBuilder: (context, index) {
                final request = widget.controller.friendRequests[index];
                return KeyedSubtree(
                  key: ValueKey('request_${request.sId ?? index}'),
                  child: widget.buildRequestCard(request),
                );
              },
            );
    });
  }
}

class SentRequestsTabView extends StatefulWidget {
  final FriendController controller;
  final Function(FriendRequest) buildSentRequestCard;

  const SentRequestsTabView({
    Key? key,
    required this.controller,
    required this.buildSentRequestCard,
  }) : super(key: key);

  @override
  State<SentRequestsTabView> createState() => _SentRequestsTabViewState();
}

class _SentRequestsTabViewState extends State<SentRequestsTabView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Obx(() {
      if (widget.controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      return widget.controller.sentRequests.isEmpty
          ? EmptySentRequestsView()
          : ListView.builder(
              key: const PageStorageKey<String>('sent_requests_list'),
              padding: const EdgeInsets.symmetric(vertical: 8),
              physics: const ClampingScrollPhysics(),
              itemCount: widget.controller.sentRequests.length,
              itemBuilder: (context, index) {
                final request = widget.controller.sentRequests[index];
                return KeyedSubtree(
                  key: ValueKey('sent_request_${request.sId ?? index}'),
                  child: widget.buildSentRequestCard(request),
                );
              },
            );
    });
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
              // Icon container
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

              // Title
              const Text(
                'No Friend Requests',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                "You don't have any pending friend requests at the moment. When someone sends you a request, it will appear here.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),

              // Placeholder Cards
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
            // Avatar placeholder
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

            // Text placeholders
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

            // Button placeholders
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
