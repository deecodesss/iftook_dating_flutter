import 'package:iftook/features/profile/data/models/user.dart';

class Subscription {
  final String id;
  final String subscriberId;
  final String creatorId;
  final double amount;
  final String status;
  final DateTime startDate;
  final DateTime endDate;
  final String paymentId;
  final User? creator;

  Subscription({
    required this.id,
    required this.subscriberId,
    required this.creatorId,
    required this.amount,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.paymentId,
    this.creator,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['_id'] ?? '',
      subscriberId: json['subscriber'] ?? '',
      creatorId: json['creator'] is String
          ? json['creator']
          : json['creator']['_id'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      status: json['status'] ?? 'active',
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'])
          : DateTime.now(),
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'])
          : DateTime.now().add(const Duration(days: 30)),
      paymentId: json['paymentId'] ?? '',
      creator: json['creator'] is Map ? User.fromJson(json['creator']) : null,
    );
  }

  bool get isActive => status == 'active' && DateTime.now().isBefore(endDate);

  int get daysRemaining {
    final difference = endDate.difference(DateTime.now());
    return difference.inDays;
  }
}
