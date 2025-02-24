import 'package:iftook/features/profile/data/models/user.dart';

class FriendRequest {
  String? sId;
  User? requester;
  String? receiver;
  String? status;
  String? createdAt;
  int? iV;

  FriendRequest(
      {this.sId,
      this.requester,
      this.receiver,
      this.status,
      this.createdAt,
      this.iV});

  FriendRequest.fromJson(Map<String, dynamic> json) {
    sId = json['_id'];
    requester =
        json['requester'] != null ? new User.fromJson(json['requester']) : null;
    receiver = json['receiver'];
    status = json['status'];
    createdAt = json['createdAt'];
    iV = json['__v'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['_id'] = this.sId;
    if (this.requester != null) {
      data['requester'] = this.requester!.toJson();
    }
    data['receiver'] = this.receiver;
    data['status'] = this.status;
    data['createdAt'] = this.createdAt;
    data['__v'] = this.iV;
    return data;
  }
}
