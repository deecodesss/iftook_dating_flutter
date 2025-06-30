enum MeetingType {
  video('video'),
  voice('voice'),
  chat('chat');

  final String value;
  const MeetingType(this.value);

  String toApiValue() {
    switch (this) {
      case MeetingType.video:
        return 'video';
      case MeetingType.voice:
        return 'voice';
      case MeetingType.chat:
        return 'chat'; // Fixed: Now sending 'chat' instead of 'voice'
    }
  }

  static MeetingType fromString(String value) {
    return MeetingType.values.firstWhere(
      (type) => type.value == value.toLowerCase(),
      orElse: () => MeetingType.chat,
    );
  }
}
