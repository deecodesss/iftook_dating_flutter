// import 'package:agora_rtm/agora_rtm.dart';
//
// class AgoraRtmService {
//   late AgoraRtmClient _client;
//   late AgoraRtmChannel _channel;
//   String? _userId;
//
//   // Initialize Agora RTM Client
//   Future<void> initialize(String appId) async {
//     _client = await AgoraRtmClient.createInstance(appId);
//   }
//
//   // Login to Agora RTM
//   Future<void> login(String token, String userId) async {
//     _userId = userId;
//     await _client.login(token, userId);
//   }
//
//   // Join a channel
//   Future<void> joinChannel(String channelId) async {
//     _channel = await _client.createChannel(channelId);
//     await _channel.join();
//   }
//
//   // Send a message to the channel
//   Future<void> sendMessage(String message) async {
//     if (_channel != null) {
//       await _channel.sendMessage(AgoraRtmMessage.fromText(message));
//     }
//   }
//
//   // Listen for incoming messages
//   void onMessageReceived(Function(String message, String userId) callback) {
//     _channel.onMessageReceived = (AgoraRtmMessage message, String userId) {
//       callback(message.text, userId);
//     };
//   }
//
//   // Logout from Agora RTM
//   Future<void> logout() async {
//     await _client.logout();
//   }
//
//   // Leave the channel
//   Future<void> leaveChannel() async {
//     await _channel.leave();
//   }
// }
