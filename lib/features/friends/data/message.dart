class Message {
  String? sId;
  SenderId? senderId;
  String? chatRoomId;
  String? text;
  Null? media;
  String? status;
  String? createdAt;
  String? updatedAt;
  int? iV;

  Message(
      {this.sId,
      this.senderId,
      this.chatRoomId,
      this.text,
      this.media,
      this.status,
      this.createdAt,
      this.updatedAt,
      this.iV});

  Message.fromJson(Map<String, dynamic> json) {
    sId = json['_id'];
    senderId = json['senderId'] != null
        ? new SenderId.fromJson(json['senderId'])
        : null;
    chatRoomId = json['chatRoomId'];
    text = json['text'];
    media = json['media'];
    status = json['status'];
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
    iV = json['__v'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['_id'] = this.sId;
    if (this.senderId != null) {
      data['senderId'] = this.senderId!.toJson();
    }
    data['chatRoomId'] = this.chatRoomId;
    data['text'] = this.text;
    data['media'] = this.media;
    data['status'] = this.status;
    data['createdAt'] = this.createdAt;
    data['updatedAt'] = this.updatedAt;
    data['__v'] = this.iV;
    return data;
  }
}

class SenderId {
  String? sId;
  String? name;
  String? email;

  SenderId({this.sId, this.name, this.email});

  SenderId.fromJson(Map<String, dynamic> json) {
    sId = json['_id'];
    name = json['name'];
    email = json['email'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['_id'] = this.sId;
    data['name'] = this.name;
    data['email'] = this.email;
    return data;
  }
}
