import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/core/services/shared_prefs.dart';
import 'package:iftook/features/friend_requests/controller/friend_controller.dart';
import 'package:iftook/features/home/presentation/widgets/user_profile_screen.dart';
import 'package:iftook/features/profile/data/models/user.dart';
import 'package:iftook/helpers/app_colors.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FriendController controller = Get.find<FriendController>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    controller.fetchMeetings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshHistory() async {
    await controller.fetchMeetings();
  }

  // --- NEW, IMPROVED HELPER WIDGET for Call Status ---
  Widget _buildCallTypeIndicator(
      String type, String status, String callLength, bool wasOutgoing) {
    IconData typeIcon;
    Color statusColor;
    String statusText = status.capitalizeFirst ?? status;

    // 1. Determine the icon for the call TYPE
    switch (type) {
      case 'voice':
        typeIcon = Icons.call_outlined;
        break;
      case 'video':
        typeIcon = Icons.videocam_outlined;
        break;
      default: // chat
        typeIcon = Icons.chat_bubble_outline_rounded;
    }

    // 2. Determine the color for the call STATUS
    switch (status.toLowerCase()) {
      case 'completed':
        statusColor = AppColors.greenColor;
        break;
      case 'missed':
      case 'expired':
        statusColor = AppColors.redColor;
        break;
      case 'cancelled':
      case 'declined':
        statusColor = Colors.orange.shade700;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Row(
      children: [
        // 3. Icon for call DIRECTION (Sent/Received)
        Icon(
          wasOutgoing ? Icons.call_made_rounded : Icons.call_received_rounded,
          color: wasOutgoing ? AppColors.accentColor : AppColors.greenColor,
          size: 18,
        ),
        const SizedBox(width: 6),
        // 4. Icon for call TYPE (Voice/Video/Chat)
        Icon(typeIcon, color: Colors.grey[400], size: 16),
        const SizedBox(width: 8),
        // 5. Rich text for STATUS and DURATION
        Expanded(
          child: Text(
            callLength.isNotEmpty ? "$statusText ($callLength)" : statusText,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> call) {
    return FutureBuilder<String?>(
      future: SharedPrefs.getUserIdSharedPreference(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final currentUserId = snapshot.data!;
        final initiator = call['user'] as Map<String, dynamic>;
        final participant = call['participant'] as Map<String, dynamic>;

        final bool wasOutgoing = initiator['_id'] == currentUserId;
        final otherUser = wasOutgoing ? participant : initiator;

        final String name = otherUser['name'] ?? 'Unknown User';
        final List<String> photos = otherUser['photos'] != null
            ? List<String>.from(otherUser['photos'])
            : [];
        final String imageUrl = photos.isNotEmpty
            ? photos.first
            : 'https://i.stack.imgur.com/l60Hf.png';

        // final String status = call['status'] ?? 'Expired';
        final String status = '';
        final callTime =
            DateTime.tryParse(call['scheduledTime'] ?? '') ?? DateTime.now();
        final String timestamp =
            DateFormat('MMM d, h:mm a').format(callTime.toLocal());
        final double amount = (call['amount'] ?? 0).toDouble();
        final String type = call['type'] ?? 'unknown';

        final int durationInSeconds = call['actualDurationInSeconds'] ?? 0;
        String callLength = '';
        if (durationInSeconds > 0) {
          final duration = Duration(seconds: durationInSeconds);
          final minutes = duration.inMinutes;
          final seconds = duration.inSeconds % 60;
          callLength = '${minutes}m ${seconds}s';
        }

        return Card(
          color: Colors.grey[900]?.withOpacity(0.5),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: Colors.grey[800]!, width: 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: () {
              try {
                final userProfile = User.fromJson(otherUser);
                Get.to(() => UserProfileScreen(profile: userProfile));
              } catch (e) {
                Get.snackbar('Error', 'Could not load profile details.');
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                      radius: 28, backgroundImage: NetworkImage(imageUrl)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        // REPLACED with the new helper widget
                        _buildCallTypeIndicator(
                            type, status, callLength, wasOutgoing),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(timestamp,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12)),
                      const SizedBox(height: 8),
                      if (amount > 0)
                        Text(
                          '₹${amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: AppColors.primaryColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off_rounded,
                size: 60, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text(
              'No history items found.',
              style:
                  TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refreshHistory,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: items.length,
        itemBuilder: (context, index) => _buildHistoryCard(items[index]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('History',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryColor,
          indicatorWeight: 3,
          dividerColor: Colors.transparent,
          labelColor: AppColors.primaryColor,
          unselectedLabelColor: Colors.white.withOpacity(0.6),
          labelStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Calls'),
            Tab(text: 'Video'),
            Tab(text: 'Chat'),
          ],
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryColor));
        }
        return TabBarView(
          controller: _tabController,
          children: [
            _buildHistoryList(controller.historicalItems),
            _buildHistoryList(controller.historicalItems
                .where((item) => item['type'] == 'voice')
                .toList()),
            _buildHistoryList(controller.historicalItems
                .where((item) => item['type'] == 'video')
                .toList()),
            _buildHistoryList(controller.historicalItems
                .where((item) => item['type'] == 'chat')
                .toList()),
          ],
        );
      }),
    );
  }
}
