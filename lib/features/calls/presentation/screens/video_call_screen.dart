import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:no_screenshot/no_screenshot.dart';

class VideoCallScreen extends StatefulWidget {
  final String meetingId;
  final String token;
  final String channel;
  const VideoCallScreen(
      {Key? key,
      required this.meetingId,
      required this.token,
      required this.channel})
      : super(key: key);

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  int? _remoteUid; // Stores remote user ID
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  bool _localUserJoined =
      false; // Indicates if local user has joined the channel
  late RtcEngine _engine;
  final _noScreenshot = NoScreenshot.instance;

  // Get Agora app ID from environment or config
  // This should ideally be loaded from a config file or environment
  final String appId = "5da40b914dcf4a089e8bbee75a926178";

  @override
  void initState() {
    super.initState();
    _preventScreenshots();
    _setupScreenshotDetection();
    print(
        "Initializing with token: ${widget.token}, channel: ${widget.channel}");
    _initAgora();
  }

  // Prevent screenshots using the no_screenshot package
  void _preventScreenshots() async {
    await _noScreenshot.screenshotOff();
  }

  // Set up screenshot detection
  void _setupScreenshotDetection() {
    // Start listening for screenshot events
    _noScreenshot.startScreenshotListening();

    // Listen for screenshots
    _noScreenshot.screenshotStream.listen((value) {
      if (value.wasScreenshotTaken) {
        // Show alert or take action when screenshot is detected
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Screenshots are not allowed during video calls'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  // Re-enable screenshots when leaving
  void _allowScreenshots() async {
    await _noScreenshot.screenshotOn();
    await _noScreenshot.stopScreenshotListening();
  }

  // Initialize Agora SDK
  Future<void> _initAgora() async {
    try {
      await _requestPermissions();
      _engine = createAgoraRtcEngine();
      await _engine.initialize(RtcEngineContext(appId: appId));

      await _engine.enableVideo();
      _setupEventHandlers();
      debugPrint(
          "Joining channel: ${widget.channel} with token: ${widget.token}");

      // Join the channel
      await _engine.joinChannel(
        token: widget.token,
        channelId: widget.channel,
        uid: 0,
        options: const ChannelMediaOptions(
          autoSubscribeVideo: true,
          autoSubscribeAudio: true,
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (e) {
      setState(() {
        // _isLoading = false;
        // _errorMessage = "Failed to initialize Agora SDK: ${e.toString()}";
        print("error in agora: $e");
      });
    }
  }

  // Set up event handlers for Agora RTC
  void _setupEventHandlers() {
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("Local user ${connection.localUid} joined");
          setState(() => _localUserJoined = true);
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("Remote user $remoteUid joined");
          setState(() => _remoteUid = remoteUid);
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          debugPrint("Remote user $remoteUid left");
          setState(() => _remoteUid = null);
        },
      ),
    );
  }

  // Request camera and microphone permissions
  Future<void> _requestPermissions() async {
    final cameraStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();

    if (!cameraStatus.isGranted || !micStatus.isGranted) {
      _showPermissionDeniedDialog();
    }
  }

  // Show a dialog if permissions are denied
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permissions Required'),
          content: const Text(
              'Camera and microphone permissions are required for video calls. '
              'Please enable them in your device settings.'),
          actions: [
            TextButton(
              child: const Text('Open Settings'),
              onPressed: () {
                openAppSettings();
                Navigator.pop(context);
              },
            ),
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  // Toggle microphone mute
  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _engine.muteLocalAudioStream(_isMuted);
  }

  // Toggle video stream
  void _toggleVideo() {
    setState(() {
      _isVideoEnabled = !_isVideoEnabled;
    });
    _engine.muteLocalVideoStream(!_isVideoEnabled);
  }

  // Switch between front and back cameras
  void _switchCamera() {
    _engine.switchCamera();
  }

  // Leave the channel and release resources
  Future<void> _leaveChannel() async {
    await _engine.leaveChannel();
    await _engine.release();
  }

  // End the call and navigate back
  void _endCall() {
    _leaveChannel();
    _allowScreenshots();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _leaveChannel();
    _allowScreenshots();
    super.dispose();
  }

  // Build the UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(title: const Text('Agora Video Call')),
      body: Stack(
        children: [
          // Remote video
          Center(
            child: _remoteUid != null
                ? AgoraVideoView(
                    controller: VideoViewController.remote(
                      rtcEngine: _engine,
                      canvas: VideoCanvas(uid: _remoteUid),
                      connection: RtcConnection(channelId: widget.channel),
                    ),
                  )
                : const Text('Waiting for remote user to join...'),
          ),
          // Local video (only shown if video is enabled)
          if (_isVideoEnabled)
            Container(
              margin: const EdgeInsets.only(top: 40, left: 24),
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 120,
                  height: 180,
                  child: _localUserJoined
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AgoraVideoView(
                            controller: VideoViewController(
                              rtcEngine: _engine,
                              canvas: const VideoCanvas(uid: 0),
                            ),
                          ),
                        )
                      : const CircularProgressIndicator(),
                ),
              ),
            ),
          // Call controls
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Mute button
                  _buildCallButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    color: Colors.white,
                    backgroundColor: _isMuted ? Colors.red : Colors.blue,
                    onPressed: _toggleMute,
                  ),
                  const SizedBox(width: 20),
                  // Video toggle button
                  _buildCallButton(
                    icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                    color: Colors.white,
                    backgroundColor: _isVideoEnabled ? Colors.blue : Colors.red,
                    onPressed: _toggleVideo,
                  ),
                  const SizedBox(width: 20),
                  // Switch camera button
                  _buildCallButton(
                    icon: Icons.cameraswitch,
                    color: Colors.white,
                    backgroundColor: Colors.blue,
                    onPressed: _switchCamera,
                  ),
                  const SizedBox(width: 20),
                  // End call button
                  _buildCallButton(
                    icon: Icons.call_end,
                    color: Colors.white,
                    backgroundColor: Colors.red,
                    onPressed: _endCall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build call control buttons
  Widget _buildCallButton({
    required IconData icon,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onPressed,
    double size = 50,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 2),
          ],
        ),
        child: Icon(icon, color: color, size: size * 0.5),
      ),
    );
  }
}
