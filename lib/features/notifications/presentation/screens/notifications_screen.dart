import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:iftook/helpers/app_colors.dart';
import 'package:intl/intl.dart';
import '../../../friends/presentation/screens/chat_room_screen.dart';
import '../../../profile/data/models/user.dart';
import '../../services/notification_storage_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationStorageService _notificationService =
      Get.find<NotificationStorageService>();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: Text(
          'Notifications',
          style: GoogleFonts.manrope(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        actions: [
          Obx(() => _notificationService.unreadCount > 0
              ? TextButton(
                  onPressed: () => _notificationService.markAllAsRead(),
                  child: Text(
                    'Mark all read',
                    style: GoogleFonts.manrope(
                      color: AppColors.primaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : const SizedBox()),
          const SizedBox(width: 8),
        ],
      ),
      body: Obx(() {
        final notifications = _notificationService.notifications;

        if (notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryBackground.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    HugeIcons.strokeRoundedNotification03,
                    size: 48,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'No notifications yet',
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    color: Colors.white.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You\'re all caught up!',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: notifications.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final notification = notifications[index];
            return _buildNotificationTile(notification);
          },
        );
      }),
    );
  }

  Widget _buildNotificationTile(StoredNotification notification) {
    return Container(
      decoration: BoxDecoration(
        color: notification.isRead
            ? AppColors.secondaryBackground.withOpacity(0.3)
            : AppColors.secondaryBackground.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: notification.isRead
            ? null
            : Border.all(
                color: AppColors.primaryColor.withOpacity(0.2),
                width: 1,
              ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleNotificationTap(notification),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getNotificationColor(notification.type)
                        .withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getNotificationIcon(notification.type),
                    color: _getNotificationColor(notification.type),
                    // size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: notification.isRead
                              ? FontWeight.w500
                              : FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.7),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatTimestamp(notification.timestamp),
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                // Unread indicator
                if (!notification.isRead)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.chat:
        return HugeIcons.strokeRoundedMessage02;
      case NotificationType.instaTalk:
        return HugeIcons.strokeRoundedVideoReplay;
      case NotificationType.callRequest:
        return HugeIcons.strokeRoundedCall;
      case NotificationType.meetingRequest:
        return HugeIcons.strokeRoundedCalendar03;
      case NotificationType.friendRequest:
        return HugeIcons.strokeRoundedUserAdd02;
      default:
        return HugeIcons.strokeRoundedNotification03;
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.chat:
        return Colors.blue;
      case NotificationType.instaTalk:
        return Colors.purple;
      case NotificationType.callRequest:
        return Colors.green;
      case NotificationType.meetingRequest:
        return Colors.orange;
      case NotificationType.friendRequest:
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }

  void _handleNotificationTap(StoredNotification notification) {
    // Mark as read
    _notificationService.markAsRead(notification.id);

    // Handle navigation based on notification type
    // switch (notification.type) {
    //   case NotificationType.chat:
    //     _handleChatNotificationTap(notification);
    //     break;
    //   case NotificationType.instaTalk:
    //     Get.snackbar(
    //       'InstaTalk',
    //       'This session is no longer available',
    //       backgroundColor: Colors.purple.withOpacity(0.8),
    //       colorText: Colors.white,
    //       snackPosition: SnackPosition.TOP,
    //     );
    //     break;
    //   case NotificationType.callRequest:
    //     Get.snackbar(
    //       'Call',
    //       'This call is no longer available',
    //       backgroundColor: Colors.green.withOpacity(0.8),
    //       colorText: Colors.white,
    //       snackPosition: SnackPosition.TOP,
    //     );
    //     break;
    //   default:
    //     break;
    // }
  }

  void _handleChatNotificationTap(StoredNotification notification) {
    final senderId = notification.data['senderId']?.toString();
    final senderName = notification.data['senderName']?.toString();
    final senderPhoto = notification.data['senderPhoto']?.toString();

    if (senderId != null) {
      final userData = User(
        sId: senderId,
        name: senderName ?? 'User',
        photos: senderPhoto != null ? [senderPhoto] : [],
      );

      Get.to(() => ChatRoomScreen(
            profile: userData,
            duration: 60,
            existingChatRoomId: notification.data['chatRoomId']?.toString(),
          ));
    }
  }
}
