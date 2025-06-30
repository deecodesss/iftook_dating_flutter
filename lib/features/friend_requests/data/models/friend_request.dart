import 'package:iftook/features/profile/data/models/user.dart';

class FriendRequest {
  String? sId;
  User? requester;
  User? receiver;
  String? status;
  String? createdAt;
  String? updatedAt;

  FriendRequest({
    this.sId,
    this.requester,
    this.receiver,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  FriendRequest.fromJson(Map<String, dynamic> json) {
    try {
      sId = json['_id']?.toString();

      // Parse receiver from string ID
      if (json['receiver'] is String) {
        receiver = User(
          sId: json['receiver'],
          name: json['receiverName'] ??
              'Unknown', // Try to get name from additional field
          location: json['receiverLocation'] != null
              ? Location.fromJson(json['receiverLocation'])
              : null,
        );
      }
      // Parse receiver from full object
      else if (json['receiver'] is Map<String, dynamic>) {
        receiver = User.fromJson(json['receiver']);
      }

      // Parse requester as full object
      if (json['requester'] is Map<String, dynamic>) {
        requester = User.fromJson(json['requester']);
      }

      status = json['status']?.toString();
      createdAt = json['createdAt']?.toString();
      updatedAt = json['updatedAt']?.toString();

      print('Parsed request - ID: $sId');
      print('Receiver details: ${receiver?.toJson()}');
      print('Requester details: ${requester?.toJson()}');
    } catch (e, stack) {
      print('Error parsing FriendRequest: $e');
      print('Stack trace: $stack');
      print('Raw JSON: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['_id'] = this.sId;
    if (this.requester != null) {
      data['requester'] = this.requester!.toJson();
    }
    if (this.receiver != null) {
      data['receiver'] = this.receiver!.toJson();
    }
    data['status'] = this.status;
    data['createdAt'] = this.createdAt;
    data['updatedAt'] = this.updatedAt;
    return data;
  }
}
