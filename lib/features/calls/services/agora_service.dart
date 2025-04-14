import 'package:agora_rtc_engine/agora_rtc_engine.dart';

class AgoraService {
  static final RtcEngine _engine = createAgoraRtcEngine();
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (!_isInitialized) {
      await _engine.initialize(const RtcEngineContext(
        appId: "5da40b914dcf4a089e8bbee75a926178",
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

      await _engine.enableVideo();
      await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      _isInitialized = true;
    }
  }

  static Future<void> joinChannel(String token, String channel, int uid) async {
    if (!_isInitialized) await initialize();

    // Enable video/audio based on call type
    await _engine.enableLocalVideo(true);
    await _engine.enableLocalAudio(true);

    await _engine.joinChannel(
      token: token,
      channelId: channel,
      uid: uid,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );
  }

  static Future<void> leaveChannel() async {
    await _engine.leaveChannel();
  }
}
