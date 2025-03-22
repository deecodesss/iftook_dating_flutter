import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/core/services/shared_prefs.dart';
import 'package:iftook/features/live/controllers/live_controller.dart';
import 'package:iftook/features/live/models/live_stream.dart';
import 'package:iftook/features/live/widgets/agora_live_chat_widget.dart';
import 'package:iftook/features/live/widgets/live_info_widget.dart';
import 'package:iftook/helpers/app_colors.dart';
import 'package:iftook/helpers/constant.dart';
import 'package:permission_handler/permission_handler.dart';

class BroadcasterScreen extends StatefulWidget {
  final LiveStream liveStream;

  const BroadcasterScreen({
    Key? key,
    required this.liveStream,
  }) : super(key: key);

  @override
  State<BroadcasterScreen> createState() => _BroadcasterScreenState();
}

class _BroadcasterScreenState extends State<BroadcasterScreen> {
  final LiveController _liveController = Get.find<LiveController>();

  final RtcEngine _engine = createAgoraRtcEngine();
  bool _isInitialized = false;
  bool _isMuted = false;
  bool _isCameraFlipped = false;
  bool _isLoading = true;
  String _errorMessage = '';
  int _viewerCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeAgora();
  }

  Future<void> _initializeAgora() async {
    setState(() => _isLoading = true);

    try {
      // Request permissions
      await [Permission.camera, Permission.microphone].request();

      // Initialize Agora engine
      await _engine.initialize(RtcEngineContext(
        appId: Constants.agoraAppId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

      // Setup event handlers
      _engine.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          print("Broadcaster joined channel ${connection.channelId}");
          setState(() => _isInitialized = true);
        },
        onUserJoined: (connection, uid, elapsed) {
          print("New viewer joined: $uid");
          setState(() => _viewerCount++);
        },
        onUserOffline: (connection, uid, reason) {
          print("Viewer left: $uid");
          setState(
              () => _viewerCount = _viewerCount > 0 ? _viewerCount - 1 : 0);
        },
        onError: (err, msg) {
          print("Error: $err - $msg");
          setState(() => _errorMessage = 'Error: $msg');
        },
      ));

      // Set broadcaster role
      await _engine.setClientRole(
        role: ClientRoleType.clientRoleBroadcaster,
      );

      // Enable video
      await _engine.enableVideo();
      await _engine.startPreview();

      // Set video encoding config
      await _engine.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 1280, height: 720),
          frameRate: 30,
          bitrate: 3500,
        ),
      );

      // Join channel with token
      await _engine.joinChannel(
        token: widget.liveStream.agoraToken,
        channelId: widget.liveStream.channelName,
        uid: 0, // Broadcaster always uses 0
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishMicrophoneTrack: true,
          publishCameraTrack: true,
        ),
      );
    } catch (e) {
      setState(() => _errorMessage = 'Failed to initialize: $e');
      print("Error initializing Agora: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _endBroadcast();
    super.dispose();
  }

  Future<void> _endBroadcast() async {
    try {
      await _engine.leaveChannel();
      await _engine.release();
      await _liveController.endLiveStream(widget.liveStream.id);
    } catch (e) {
      print("Error ending broadcast: $e");
    }
  }

  void _toggleMute() async {
    setState(() => _isMuted = !_isMuted);
    await _engine.muteLocalAudioStream(_isMuted);
  }

  void _flipCamera() async {
    setState(() => _isCameraFlipped = !_isCameraFlipped);
    await _engine.switchCamera();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        bool confirm = await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: const Color(0xFF1A1A1A),
                title: const Text(
                  'End Live Stream?',
                  style: TextStyle(color: Colors.white),
                ),
                content: const Text(
                  'Are you sure you want to end your live stream?',
                  style: TextStyle(color: Colors.white70),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('No'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('End Stream'),
                  ),
                ],
              ),
            ) ??
            false;

        if (confirm) {
          await _endBroadcast();
          return true;
        }
        return false;
      },
      child: Scaffold(
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => Get.back(),
                          child: const Text('Go Back'),
                        ),
                      ],
                    ),
                  )
                : Stack(
                    children: [
                      // Video view
                      _isInitialized
                          ? AgoraVideoView(
                              controller: VideoViewController(
                                rtcEngine: _engine,
                                canvas: const VideoCanvas(uid: 0),
                              ),
                            )
                          : const Center(
                              child: CircularProgressIndicator(),
                            ),

                      // Overlay controls
                      SafeArea(
                        child: Column(
                          children: [
                            // Top bar with info and viewer count
                            LiveInfoWidget(
                              title: widget.liveStream.title,
                              viewerCount: _viewerCount,
                              isLive: true,
                            ),

                            const Spacer(),

                            // Chat area
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: AgoraLiveChatWidget(
                                liveStreamId: widget.liveStream.id,
                                channelName: widget.liveStream.channelName,
                                engine: _engine, // Pass the engine reference
                              ),
                            ),

                            // Bottom controls
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildControlButton(
                                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                                    label: _isMuted ? 'Unmute' : 'Mute',
                                    onPressed: _toggleMute,
                                  ),
                                  _buildControlButton(
                                    icon: Icons.flip_camera_ios,
                                    label: 'Flip',
                                    onPressed: _flipCamera,
                                  ),
                                  _buildControlButton(
                                    icon: Icons.stop_circle_outlined,
                                    label: 'End',
                                    onPressed: () async {
                                      bool confirm = await showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              backgroundColor:
                                                  const Color(0xFF1A1A1A),
                                              title: const Text(
                                                'End Live Stream?',
                                                style: TextStyle(
                                                    color: Colors.white),
                                              ),
                                              content: const Text(
                                                'Are you sure you want to end your live stream?',
                                                style: TextStyle(
                                                    color: Colors.white70),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, false),
                                                  child: const Text('No'),
                                                ),
                                                ElevatedButton(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.red,
                                                  ),
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, true),
                                                  child:
                                                      const Text('End Stream'),
                                                ),
                                              ],
                                            ),
                                          ) ??
                                          false;

                                      if (confirm) {
                                        await _endBroadcast();
                                        Get.back();
                                      }
                                    },
                                    color: Colors.red,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color color = AppColors.primaryColor,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
