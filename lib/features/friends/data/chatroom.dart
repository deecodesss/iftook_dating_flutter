class Chatroom {
  String? sId;
  List<Participants>? participants;
  bool? isPaid;
  String? paymentStatus;
  String? createdAt;
  String? updatedAt;
  int? iV;

  Chatroom(
      {this.sId,
      this.participants,
      this.isPaid,
      this.paymentStatus,
      this.createdAt,
      this.updatedAt,
      this.iV});

  Chatroom.fromJson(Map<String, dynamic> json) {
    sId = json['_id'];
    if (json['participants'] != null) {
      participants = <Participants>[];
      json['participants'].forEach((v) {
        participants!.add(new Participants.fromJson(v));
      });
    }
    isPaid = json['isPaid'];
    paymentStatus = json['paymentStatus'];
    createdAt = json['createdAt'];
    updatedAt = json['updatedAt'];
    iV = json['__v'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['_id'] = this.sId;
    if (this.participants != null) {
      data['participants'] = this.participants!.map((v) => v.toJson()).toList();
    }
    data['isPaid'] = this.isPaid;
    data['paymentStatus'] = this.paymentStatus;
    data['createdAt'] = this.createdAt;
    data['updatedAt'] = this.updatedAt;
    data['__v'] = this.iV;
    return data;
  }
}

class Participants {
  String? sId;
  String? name;
  String? email;

  Participants({this.sId, this.name, this.email});

  Participants.fromJson(Map<String, dynamic> json) {
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
