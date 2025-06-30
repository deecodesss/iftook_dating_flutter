class NotificationBody {
  String? title;
  String? body;
  String? type; // Add InstaTalk as a type
  String? image;
  String? senderId;
  String? meetingId;
  String? channelName;
  String? token;
  String? requestType; // chat, voice, video for InstaTalk

  NotificationBody({
    this.title,
    this.body,
    this.type,
    this.image,
    this.senderId,
    this.meetingId,
    this.channelName,
    this.token,
    this.requestType,
  });

  NotificationBody copyWith({
    String? title,
    String? body,
    String? type,
    String? image,
    String? senderId,
    String? meetingId,
    String? channelName,
    String? token,
    String? requestType,
  }) {
    return NotificationBody(
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      image: image ?? this.image,
      senderId: senderId ?? this.senderId,
      meetingId: meetingId ?? this.meetingId,
      channelName: channelName ?? this.channelName,
      token: token ?? this.token,
      requestType: requestType ?? this.requestType,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['title'] = title;
    data['body'] = body;
    data['type'] = type;
    data['image'] = image;
    data['senderId'] = senderId;
    data['meetingId'] = meetingId;
    data['channelName'] = channelName;
    data['token'] = token;
    data['requestType'] = requestType;
    return data;
  }

  factory NotificationBody.fromJson(Map<String, dynamic> json) {
    return NotificationBody(
      title: json['title'],
      body: json['body'],
      type: json['type'],
      image: json['image'],
      senderId: json['senderId'],
      meetingId: json['meetingId'],
      channelName: json['channelName'],
      token: json['token'],
      requestType: json['requestType'],
    );
  }
}
