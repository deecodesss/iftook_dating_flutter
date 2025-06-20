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

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NotificationStorageService _notificationService = Get.find<NotificationStorageService>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.manrope(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primaryBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              switch (value) {
                case 'mark_all_read':
                  _notificationService.markAllAsRead();
                  break;
                case 'clear_all':
                  _showClearAllDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    Icon(Icons.mark_email_read, color: Colors.white70),
                    SizedBox(width: 12),
                    Text('Mark all as read'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, color: Colors.white70),
                    SizedBox(width: 12),
                    Text('Clear all'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('All'),
                  const SizedBox(width: 4),
                  Obx(() => _notificationService.unreadCount > 0
                      ? Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryColor,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '${_notificationService.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : const SizedBox()),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Chats'),
                  const SizedBox(width: 4),
                  Obx(() => _notificationService.chatUnreadCount > 0
                      ? Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryColor,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '${_notificationService.chatUnreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : const SizedBox()),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Requests'),
                  const SizedBox(width: 4),
                  Obx(() => _notificationService.requestsUnreadCount > 0
                      ? Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryColor,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '${_notificationService.requestsUnreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : const SizedBox()),
                ],
              ),
            ),
          ],
          indicatorColor: AppColors.primaryColor,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllNotifications(),
          _buildChatNotifications(),
          _buildRequestNotifications(),
        ],
      ),
    );
  }

  Widget _buildAllNotifications() {
    return Obx(() {
      final notifications = _notificationService.notifications;
      return _buildNotificationsList(notifications);
    });
  }

  Widget _buildChatNotifications() {
    return Obx(() {
      final notifications = _notificationService.getNotificationsByType(NotificationType.chat);
      return _buildNotificationsList(notifications);
    });
  }

  Widget _buildRequestNotifications() {
    return Obx(() {
      final notifications = _notificationService.notifications
          .where((n) => 
              n.type == NotificationType.meetingRequest ||
              n.type == NotificationType.friendRequest ||
              n.type == NotificationType.instaTalk ||
              n.type == NotificationType.callRequest)
          .toList();
      return _buildNotificationsList(notifications);
    });
  }

  Widget _buildNotificationsList(List<StoredNotification> notifications) {
    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              HugeIcons.strokeRoundedNotification03,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: GoogleFonts.manrope(
                fontSize: 18,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return _buildNotificationTile(notification);
      },
    );
  }

  Widget _buildNotificationTile(StoredNotification notification) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: notification.isRead 
            ? AppColors.secondaryBackground.withOpacity(0.5)
            : AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: notification.isRead 
            ? null 
            : Border.all(color: AppColors.primaryColor.withOpacity(0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _getNotificationIcon(notification.type),
        title: Text(
          notification.title,
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w600,
            color: Colors.white,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification.body,
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatTimestamp(notification.timestamp),
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: Colors.white54,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white70),
          onSelected: (value) {
            switch (value) {
              case 'mark_read':
                _notificationService.markAsRead(notification.id);
                break;
              case 'delete':
                _notificationService.clearNotification(notification.id);
                break;
            }
          },
          itemBuilder: (context) => [
            if (!notification.isRead)
              const PopupMenuItem(
                value: 'mark_read',
                child: Row(
                  children: [
                    Icon(Icons.mark_email_read, color: Colors.white70),
                    SizedBox(width: 12),
                    Text('Mark as read'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 12),
                  Text('Delete'),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _handleNotificationTap(notification),
      ),
    );
  }

  Widget _getNotificationIcon(NotificationType type) {
    IconData iconData;
    Color iconColor;

    switch (type) {
      case NotificationType.chat:
        iconData = HugeIcons.strokeRoundedMessage02;
        iconColor = Colors.blue;
        break;
      case NotificationType.instaTalk:
        iconData = HugeIcons.strokeRoundedVideoReplay;
        iconColor = Colors.purple;
        break;
      case NotificationType.callRequest:
        iconData = HugeIcons.strokeRoundedCall;
        iconColor = Colors.green;
        break;
      case NotificationType.meetingRequest:
        iconData = HugeIcons.strokeRoundedCalendar03;
        iconColor = Colors.orange;
        break;
      case NotificationType.friendRequest:
        iconData = HugeIcons.strokeRoundedUserAdd02;
        iconColor = Colors.pink;
        break;
      default:
        iconData = HugeIcons.strokeRoundedNotification03;
        iconColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 24,
      ),
    );
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
      return DateFormat('MMM d, yyyy').format(timestamp);
    }
  }

  void _handleNotificationTap(StoredNotification notification) {
    // Mark as read
    _notificationService.markAsRead(notification.id);

    // Handle navigation based on notification type
    switch (notification.type) {
      case NotificationType.chat:
        _handleChatNotificationTap(notification);
        break;
      case NotificationType.instaTalk:
        // Handle InstaTalk notification
        Get.snackbar(
          'InstaTalk',
          'InstaTalk session has ended or is no longer available',
          backgroundColor: Colors.purple.withOpacity(0.8),
          colorText: Colors.white,
        );
        break;
      case NotificationType.callRequest:
        // Handle call notification
        Get.snackbar(
          'Call',
          'Call session has ended or is no longer available',
          backgroundColor: Colors.green.withOpacity(0.8),
          colorText: Colors.white,
        );
        break;
      default:
        // General notification tap handling
        break;
    }
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

  void _showClearAllDialog() {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.secondaryBackground,
        title: const Text(
          'Clear All Notifications',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to clear all notifications? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _notificationService.clearAllNotifications();
              Get.back();
            },
            child: const Text(
              'Clear All',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
