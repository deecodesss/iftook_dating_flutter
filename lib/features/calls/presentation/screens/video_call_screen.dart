import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:no_screenshot/no_screenshot.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'package:iftook/features/profile/data/models/user.dart';
import 'package:iftook/features/calls/controllers/call_controller.dart';
import 'package:iftook/helpers/app_colors.dart';
import 'package:iftook/core/services/shared_prefs.dart';
import 'package:iftook/features/calls/services/call_duration_service.dart';

class VideoCallScreen extends StatefulWidget {
  final String meetingId;
  final String token;
  final String channel;
  final Function? onSessionEnd;
  final User? participant;
  final bool isInstaTalk;
  final bool isTrial;
  final int instaTalkDuration;
  final int initialTimer;
  final bool fromChat;

  const VideoCallScreen({
    Key? key,
    required this.meetingId,
    required this.token,
    required this.channel,
    this.initialTimer = 30,
    this.onSessionEnd,
    this.participant,
    this.isInstaTalk = false,
    this.isTrial = false,
    this.instaTalkDuration = 30,
    this.fromChat = false,
  }) : super(key: key);

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
  RxBool isConnecting = true.obs;
  RxString connectionStatus = 'Initializing...'.obs;
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _isCallConnected = false;
  late final CallController _callController;
  late final CallDurationService _durationService;

  // Get Agora app ID from environment or config
  final String appId = "5da40b914dcf4a089e8bbee75a926178";

  @override
  void initState() {
    super.initState();
    // Get or create CallController instance
    _callController = Get.put(CallController());
    _durationService = Get.put(CallDurationService());
    _initializeDurationService();

    _preventScreenshots();
    _setupScreenshotDetection();
    print(
        "Initializing with token: ${widget.token}, channel: ${widget.channel}");
    _remainingSeconds = _durationService.getInitialTimerDuration(
      widget.isInstaTalk,
      widget.initialTimer,
    );
    _initializeTimer();
    _initializeCall();
  }

  Future<void> _initializeDurationService() async {
    if (widget.participant != null) {
      await _durationService.initialize(widget.participant!.sId!);
    }
  }

  void _initializeTimer() async {
    if (!_durationService.shouldTimeCall(widget.isTrial)) {
      return; // Don't start timer for friends or trial calls
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer?.cancel();
        _endCall();
      }
    });

    // Start call timer if needed
    if (widget.isInstaTalk && widget.participant != null && !widget.isTrial) {
      final currentUserId = await SharedPrefs.getUserIdSharedPreference();
      if (currentUserId != null) {
        _callController.startCallTimerIfNeeded(
          userId1: currentUserId,
          userId2: widget.participant!.sId!,
          durationInMinutes: widget.instaTalkDuration,
          isTrial: widget.isTrial,
          isInstaTalk: widget.isInstaTalk,
        );
      }
    }
  }

  String _formatTimer(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')} remaining';
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
  Future<void> _initializeCall() async {
    try {
      if (widget.fromChat) {
        // Use direct initialization for chat calls
        await _engine.initialize(RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ));

        await _engine.enableVideo();
        await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

        await _engine.joinChannel(
          token: widget.token,
          channelId: widget.channel,
          uid: 0,
          options: const ChannelMediaOptions(
            clientRoleType: ClientRoleType.clientRoleBroadcaster,
            publishCameraTrack: true,
            publishMicrophoneTrack: true,
          ),
        );
      } else {
        // Use existing InstaTalk initialization
        connectionStatus('Checking permissions...');
        await _requestPermissions();

        connectionStatus('Initializing engine...');
        _engine = createAgoraRtcEngine();
        await _engine.initialize(RtcEngineContext(appId: appId));

        connectionStatus('Setting up video...');
        await _engine.enableVideo();
        _setupEventHandlers();

        print('Joining channel: ${widget.channel} with token: ${widget.token}');
        connectionStatus('Joining channel...');

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
      }
    } catch (e) {
      print("Error in video call: $e");
      connectionStatus('Failed to initialize');
      Get.snackbar(
        'Error',
        'Failed to initialize video call',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Set up event handlers for Agora RTC
  void _setupEventHandlers() {
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          print("Local user ${connection.localUid} joined successfully");
          setState(() {
            _localUserJoined = true;
            connectionStatus('Waiting for other participant...');
          });
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          print("Remote user $remoteUid joined successfully");
          setState(() {
            _remoteUid = remoteUid;
            isConnecting.value = false;
            connectionStatus('Connected');
          });
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          print("Remote user $remoteUid left channel");
          setState(() {
            _remoteUid = null;
            connectionStatus('User disconnected');
          });
        },
        onError: (ErrorCodeType err, String msg) {
          print("Agora error: $err - $msg");
          connectionStatus('Connection error: $err');
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
    if (widget.onSessionEnd != null) {
      widget.onSessionEnd!();
    }
    _timer?.cancel();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _leaveChannel();
    _allowScreenshots();
    _timer?.cancel();
    _durationService.reset();
    super.dispose();
  }

  // Build the UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                : Container(
                    color: Colors.black,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Caller photo
                          CircleAvatar(
                            radius: 70,
                            backgroundImage:
                                widget.participant?.photos?.isNotEmpty == true
                                    ? NetworkImage(
                                        widget.participant!.photos!.first)
                                    : null,
                            child: widget.participant?.photos?.isEmpty ?? true
                                ? const Icon(Icons.person,
                                    size: 70, color: Colors.white54)
                                : null,
                          ),
                          const SizedBox(height: 20),
                          // Caller name
                          Text(
                            widget.participant?.name ?? 'Unknown User',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Call type
                          Text(
                            widget.isInstaTalk
                                ? 'InstaTalk Video Call'
                                : 'Video Call',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[400],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Connection status
                          Obx(() => Text(
                                connectionStatus.value,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isConnecting.value
                                      ? Colors.amber
                                      : Colors.green,
                                ),
                              )),
                        ],
                      ),
                    ),
                  ),
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

          // Main timer display at the top - only show if not friends and not trial
          if (_durationService.shouldTimeCall(widget.isTrial))
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: Colors.black.withOpacity(0.5),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimer(_remainingSeconds),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
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
