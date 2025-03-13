import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/features/friend_requests/controller/friend_controller.dart';
import 'package:iftook/features/friend_requests/data/models/friend_request.dart';
import 'package:iftook/features/home/presentation/widgets/user_profile_screen.dart';
import 'package:iftook/helpers/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

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
    final today = DateTime(now.year, now.month, now.day);
    final meetingDate =
        DateTime(meetingTime.year, meetingTime.month, meetingTime.day);

    if (meetingDate == today) {
      return DateFormat('h:mm a').format(meetingTime);
    } else {
      return DateFormat('MMM d, h:mm a').format(meetingTime);
    }
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
                      onPressed: () {
                        controller.rejectRequest(reqId, context);
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

  Widget _buildMeetingCard(Meeting meeting) {
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
                // Get.to(() => UserProfileScreen(profile:,));
              },
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accentColor, width: 2),
                ),
                child: CircleAvatar(
                  radius: 30,
                  backgroundImage: NetworkImage(meeting.imageUrl),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meeting.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        meeting.callType == 'Video Call'
                            ? Icons.videocam_outlined
                            : Icons.phone_outlined,
                        color: AppColors.accentColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        meeting.callType,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '₹${meeting.charges}',
                      style: TextStyle(
                        color: AppColors.primaryColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildMeetingTimeIndicator(meeting.meetingTime),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: meeting.hasStarted ? () {} : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(80, 36),
                  ),
                  child: Text(meeting.hasStarted ? 'Join' : 'Waiting'),
                ),
              ],
            ),
          ],
        ),
      ),
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
        children: [
          // Meetings Tab
          Obx(() {
            if (controller.isLoading.value) {
              return const Center(child: CircularProgressIndicator());
            }
            return controller.meetings.isEmpty
                ? _buildEmptyMeetingsView()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: controller.meetings.length,
                    itemBuilder: (context, index) {
                      final meeting = controller.meetings[index];
                      return _buildMeetingCard(
                        Meeting(
                          name: meeting['participant']['name'] ?? 'Unknown',
                          imageUrl:
                              meeting['participant']['photos']?.first ?? '',
                          callType: _getCallTypeLabel(meeting['type']),
                          meetingTime: DateTime.parse(meeting['scheduledTime']),
                          charges: (meeting['amount'] ?? '0').toString(),
                        ),
                      );
                    },
                  );
          }),
          // Requests Tab
          Obx(() {
            if (controller.isLoading.value) {
              return const Center(child: CircularProgressIndicator());
            }
            return controller.friendRequests.length < 1
                ? EmptyRequestsView()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: controller.friendRequests.length,
                    itemBuilder: (context, index) {
                      final request = controller.friendRequests[index];
                      return _buildRequestCard(request);
                    },
                  );
          }),
          // Sent Requests Tab
          Obx(() {
            if (controller.isLoading.value) {
              return const Center(child: CircularProgressIndicator());
            }
            return controller.sentRequests.isEmpty
                ? EmptySentRequestsView()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: controller.sentRequests.length,
                    itemBuilder: (context, index) {
                      final request = controller.sentRequests[index];
                      return _buildSentRequestCard(request);
                    },
                  );
          }),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          ],
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
