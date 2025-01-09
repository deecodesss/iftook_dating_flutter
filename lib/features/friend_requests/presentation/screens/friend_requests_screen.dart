import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/features/home/presentation/widgets/user_profile_screen.dart';
import 'package:iftook/helpers/app_colors.dart';
import 'package:intl/intl.dart';

class Meeting {
  final String name;
  final String imageUrl;
  final String callType;
  final DateTime meetingTime;
  final bool isLiked;

  Meeting({
    required this.name,
    required this.imageUrl,
    required this.callType,
    required this.meetingTime,
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
  late TabController _tabController;
  late Timer _timer;

  final List<Meeting> meetings = [
    Meeting(
      isLiked: true,
      name: 'Sarah Parker',
      imageUrl: 'https://images.unsplash.com/photo-1535324492437-d8dea70a38a7',
      callType: 'Video Call',
      meetingTime: DateTime.now().add(const Duration(minutes: 30)),
    ),
    Meeting(
      name: 'John Doe',
      imageUrl: 'https://images.unsplash.com/photo-1524250502761-1ac6f2e30d43',
      callType: 'Voice Call',
      meetingTime: DateTime.now().subtract(const Duration(minutes: 15)),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
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

  void _showAcceptWarning(BuildContext context) {
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
                      onPressed: () => Navigator.pop(context),
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
                Get.to(() => UserProfileScreen());
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
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildMeetingTimeIndicator(meeting.meetingTime),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: meeting.hasStarted
                      ? () {
                          // Handle join
                        }
                      : null,
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

  Widget _buildRequestCard(String name, String imageUrl) {
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
                Get.to(() => UserProfileScreen());
              },
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accentColor, width: 2),
                ),
                child: CircleAvatar(
                  radius: 30,
                  backgroundImage: NetworkImage(imageUrl),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                name,
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
                  onPressed: () => _showAcceptWarning(context),
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
                  onPressed: () {}, // Handle reject
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
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Meetings Tab
          ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: meetings.length,
            itemBuilder: (context, index) => _buildMeetingCard(meetings[index]),
          ),
          // Requests Tab
          ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: meetings.length,
            itemBuilder: (context, index) => _buildRequestCard(
              meetings[index].name,
              meetings[index].imageUrl,
            ),
          ),
        ],
      ),
    );
  }
}
