import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NotificationType {
  chat,
  meetingRequest,
  friendRequest,
  instaTalk,
  callRequest,
  general
}

class StoredNotification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final bool isRead;

  StoredNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.data,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type.toString(),
        'data': data,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
      };

  factory StoredNotification.fromJson(Map<String, dynamic> json) =>
      StoredNotification(
        id: json['id'],
        title: json['title'],
        body: json['body'],
        type: NotificationType.values.firstWhere(
          (e) => e.toString() == json['type'],
          orElse: () => NotificationType.general,
        ),
        data: Map<String, dynamic>.from(json['data']),
        timestamp: DateTime.parse(json['timestamp']),
        isRead: json['isRead'] ?? false,
      );

  StoredNotification copyWith({bool? isRead}) => StoredNotification(
        id: id,
        title: title,
        body: body,
        type: type,
        data: data,
        timestamp: timestamp,
        isRead: isRead ?? this.isRead,
      );
}

class NotificationStorageService extends GetxService {
  static const String _storageKey = 'stored_notifications';
  static const int _maxNotifications = 100; // Limit stored notifications

  final RxList<StoredNotification> _notifications = <StoredNotification>[].obs;
  final RxInt _unreadCount = 0.obs;
  final RxInt _chatUnreadCount = 0.obs;
  final RxInt _requestsUnreadCount = 0.obs;

  List<StoredNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount.value;
  int get chatUnreadCount => _chatUnreadCount.value;
  int get requestsUnreadCount => _requestsUnreadCount.value;

  @override
  Future<void> onInit() async {
    super.onInit();
    await _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? notificationsJson = prefs.getString(_storageKey);

      if (notificationsJson != null) {
        final List<dynamic> notificationsList = jsonDecode(notificationsJson);
        _notifications.value = notificationsList
            .map((json) => StoredNotification.fromJson(json))
            .toList();

        // Sort by timestamp (newest first)
        _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        _updateUnreadCounts();
      }
    } catch (e) {
      print('Error loading notifications: $e');
    }
  }

  Future<void> _saveNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String notificationsJson = jsonEncode(
        _notifications.map((notification) => notification.toJson()).toList(),
      );
      await prefs.setString(_storageKey, notificationsJson);
    } catch (e) {
      print('Error saving notifications: $e');
    }
  }

  void _updateUnreadCounts() {
    final unreadNotifications = _notifications.where((n) => !n.isRead).toList();

    _unreadCount.value = unreadNotifications.length;

    _chatUnreadCount.value = unreadNotifications
        .where((n) => n.type == NotificationType.chat)
        .length;

    _requestsUnreadCount.value = unreadNotifications
        .where((n) =>
            n.type == NotificationType.meetingRequest ||
            n.type == NotificationType.friendRequest ||
            n.type == NotificationType.instaTalk ||
            n.type == NotificationType.callRequest)
        .length;
  }

  NotificationType _categorizeNotification(Map<String, dynamic> data) {
    final String? type = data['type']?.toString().toLowerCase();

    switch (type) {
      case 'chat':
        return NotificationType.chat;
      case 'instatalk':
        return NotificationType.instaTalk;
      case 'voice':
      case 'video':
        if (data['action'] != 'renewal') {
          return NotificationType.callRequest;
        }
        return NotificationType.general;
      case 'meeting':
      case 'meeting_request':
        return NotificationType.meetingRequest;
      case 'friend_request':
        return NotificationType.friendRequest;
      default:
        return NotificationType.general;
    }
  }

  Future<void> storeNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      final notificationType = _categorizeNotification(data);

      final notification = StoredNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        body: body,
        type: notificationType,
        data: data,
        timestamp: DateTime.now(),
      );

      _notifications.insert(0, notification);

      // Limit the number of stored notifications
      if (_notifications.length > _maxNotifications) {
        _notifications.removeRange(_maxNotifications, _notifications.length);
      }

      _updateUnreadCounts();
      await _saveNotifications();

      print('Stored notification: $title (Type: $notificationType)');
    } catch (e) {
      print('Error storing notification: $e');
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        _updateUnreadCounts();
        await _saveNotifications();
      }
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      for (int i = 0; i < _notifications.length; i++) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
      _updateUnreadCounts();
      await _saveNotifications();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  Future<void> clearNotification(String notificationId) async {
    try {
      _notifications.removeWhere((n) => n.id == notificationId);
      _updateUnreadCounts();
      await _saveNotifications();
    } catch (e) {
      print('Error clearing notification: $e');
    }
  }

  Future<void> clearAllNotifications() async {
    try {
      _notifications.clear();
      _updateUnreadCounts();
      await _saveNotifications();
    } catch (e) {
      print('Error clearing all notifications: $e');
    }
  }

  List<StoredNotification> getNotificationsByType(NotificationType type) {
    return _notifications.where((n) => n.type == type).toList();
  }

  List<StoredNotification> getUnreadNotifications() {
    return _notifications.where((n) => !n.isRead).toList();
  }
}
