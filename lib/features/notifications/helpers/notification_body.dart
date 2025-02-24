class NotificationBody {
  String? title;
  String? body;
  String? id;
  String? type;
  String? image;

  NotificationBody({this.title, this.body, this.id, this.type, this.image});

  NotificationBody.fromJson(Map<String, dynamic> json) {
    title = json['title'];
    body = json['body'];
    id = json['id'];
    type = json['type'];
    image = json['image'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['title'] = title;
    data['body'] = body;
    data['id'] = id;
    data['type'] = type;
    data['image'] = image;
    return data;
  }
}
