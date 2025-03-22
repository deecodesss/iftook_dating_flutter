import 'package:iftook/features/profile/data/models/user.dart';

class Viewer {
  final String id;
  final String userId;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final User? user;

  Viewer({
    required this.id,
    required this.userId,
    required this.joinedAt,
    this.leftAt,
    this.user,
  });

  factory Viewer.fromJson(Map<String, dynamic> json) {
    return Viewer(
      id: json['_id'] ?? '',
      userId: json['user'] ?? '',
      joinedAt: json['joinedAt'] != null
          ? DateTime.parse(json['joinedAt'])
          : DateTime.now(),
      leftAt: json['leftAt'] != null ? DateTime.parse(json['leftAt']) : null,
      user: json['user'] is Map ? User.fromJson(json['user']) : null,
    );
  }
}

class LiveStream {
  final String id;
  final String broadcasterId;
  final String title;
  final String description;
  final String status;
  final DateTime startTime;
  final DateTime? endTime;
  final List<Viewer> viewers;
  final String channelName;
  final String agoraToken;
  final List<String> tags;
  final int maxDuration;
  final User? broadcaster;

  LiveStream({
    required this.id,
    required this.broadcasterId,
    required this.title,
    required this.description,
    required this.status,
    required this.startTime,
    this.endTime,
    required this.viewers,
    required this.channelName,
    required this.agoraToken,
    required this.tags,
    required this.maxDuration,
    this.broadcaster,
  });

  factory LiveStream.fromJson(Map<String, dynamic> json) {
    // Safely handle viewers list
    List<Viewer> viewers = [];
    if (json['viewers'] != null && json['viewers'] is List) {
      viewers = List<Viewer>.from(
          (json['viewers'] as List).map((x) => Viewer.fromJson(x)));
    }

    // Safely handle tags list
    List<String> tags = [];
    if (json['tags'] != null) {
      if (json['tags'] is List) {
        tags = List<String>.from(json['tags'].map((x) => x.toString()));
      }
    }

    // Extract broadcaster ID safely
    String broadcasterId = '';
    if (json['broadcaster'] != null) {
      if (json['broadcaster'] is String) {
        broadcasterId = json['broadcaster'];
      } else if (json['broadcaster'] is Map) {
        broadcasterId = json['broadcaster']['_id'] ?? '';
      }
    }

    return LiveStream(
      id: json['_id'] ?? '',
      broadcasterId: broadcasterId,
      title: json['title'] ?? 'Live Stream',
      description: json['description'] ?? '',
      status: json['status'] ?? 'active',
      startTime: json['startTime'] != null
          ? DateTime.parse(json['startTime'])
          : DateTime.now(),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      viewers: viewers,
      channelName: json['channelName'] ?? '',
      agoraToken: json['agoraToken'] ?? '',
      tags: tags, // Use our safely created tags list
      maxDuration: json['maxDuration'] ?? 3600,
      broadcaster: json['broadcaster'] is Map
          ? User.fromJson(json['broadcaster'])
          : null,
    );
  }

  bool get isActive => status == 'active';
  int get viewerCount => viewers.where((v) => v.leftAt == null).length;
}
