import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:no_screenshot/no_screenshot.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'package:iftook/features/profile/data/models/user.dart';
import 'package:iftook/features/calls/controllers/call_controller.dart';
import 'package:iftook/helpers/app_colors.dart';

class VideoCallScreen extends StatefulWidget {
  final String meetingId;
  final String token;
  final String channel;
  final Function? onSessionEnd;
  final User? participant;
  final bool isInstaTalk;
  final int instaTalkDuration;
  final int initialTimer;

  const VideoCallScreen({
    Key? key,
    required this.meetingId,
    required this.token,
    required this.channel,
    this.initialTimer = 30,
    this.onSessionEnd,
    this.participant,
    this.isInstaTalk = false,
    this.instaTalkDuration = 30,
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

  // Timer variables moved from loading screen
  Timer? _instaTimer;
  Timer? _startupDelayTimer;
  int _remainingSeconds = 0;
  bool _instaTalkExpired = false;
  bool _showingPaymentPrompt = false;
  bool _timerStarted = false;
  final CallController _callController = Get.put(CallController());

  // Get Agora app ID from environment or config
  // This should ideally be loaded from a config file or environment
  final String appId = "5da40b914dcf4a089e8bbee75a926178";

  // Timer variables
  late Timer _callTimer;
  int _timeLeft = 0; // This will store the remaining time for the call

  @override
  void initState() {
    super.initState();
    _preventScreenshots();
    _setupScreenshotDetection();
    print(
        "Initializing with token: ${widget.token}, channel: ${widget.channel}");
    _initAgora();

    // Initialize timer with the provided initialTimer value
    _timeLeft = widget.initialTimer;
    _startCallTimer();

    // Start timer if it's an InstaTalk call
    if (widget.isInstaTalk && widget.participant != null) {
      final callRate = widget.participant!.earnings?.videoRate ?? 0;
      if (!_callController.isFreeCall(callRate)) {
        _startupDelayTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) {
            _startTimer();
          }
        });
      }
    }
  }

  // Timer functions moved from loading screen
  void _startTimer() {
    if (widget.isInstaTalk) {
      _startInstaTimer();
    } else {
      _startRegularTimer();
    }
  }

  void _startRegularTimer() {
    setState(() {
      _remainingSeconds = 1800; // 30 minutes in seconds
      _timerStarted = true;
    });

    _instaTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _instaTimer?.cancel();
          if (!_showingPaymentPrompt) {
            _showContinueCallPrompt();
          }
        }
      });
    });
  }

  void _startInstaTimer() {
    setState(() {
      _remainingSeconds = widget.instaTalkDuration; // Use the provided duration
      _timerStarted = true;
    });

    _instaTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _instaTimer?.cancel();
          if (!_showingPaymentPrompt && !_instaTalkExpired) {
            _instaTalkExpired = true;
            _showContinueCallPrompt();
          }
        }
      });
    });
  }

  String _formatTimer(int seconds) {
    if (widget.isInstaTalk) {
      return '$seconds seconds remaining';
    } else {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      return '$minutes:${remainingSeconds.toString().padLeft(2, '0')} remaining';
    }
  }

  void _showContinueCallPrompt() {
    _showingPaymentPrompt = true;

    if (widget.onSessionEnd != null) {
      widget.onSessionEnd!();
      return;
    }

    if (widget.participant == null) return;

    final prompt = widget.isInstaTalk
        ? '30-second free video call'
        : '30-minute video call session';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Free Trial Ended',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your $prompt with ${widget.participant!.name ?? "User"} has ended.',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            const Text(
              'Would you like to continue this call?',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Text(
              'Rate: ₹${widget.participant!.earnings?.videoRate ?? 450} for 30 minutes',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _endCall();
            },
            child:
                const Text('End Call', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _purchaseCall();
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _purchaseCall() async {
    if (widget.participant == null) return;

    try {
      final callRate = widget.participant!.earnings?.videoRate ?? 450.0;
      final success = await _callController.purchaseCallSession(
        widget.participant!.sId!,
        callRate,
        'video',
        minutes: 30,
      );

      if (success) {
        setState(() {
          _instaTalkExpired = false;
          _timerStarted = false;
          // Restart timer
          _timeLeft = 30 * 60; // 30 minutes
          _callTimer.cancel();
          _startCallTimer();

          // Reset InstaTalk timer if needed
          if (widget.isInstaTalk) {
            _remainingSeconds = 0;
            _instaTimer?.cancel();
          }
        });

        Get.snackbar(
          'Success',
          'Video call session purchased',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        throw Exception('Failed to purchase session');
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to purchase call session',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
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
    _instaTimer?.cancel();
    _startupDelayTimer?.cancel();
    _callTimer.cancel(); // Cancel the main call timer
    Navigator.pop(context);
  }

  // New method to start the main call timer
  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _callTimer.cancel();
          // Call has ended due to time expiry
          _showTimeExpiredDialog();
        }
      });
    });
  }

  // Format the time left for display
  String _formatCallTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    }
  }

  // Show dialog when time expires
  void _showTimeExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Call Time Expired',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Your call time has ended.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _endCall();
              },
              child:
                  const Text('End Call', style: TextStyle(color: Colors.white)),
            ),
            if (widget.participant != null)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _purchaseCall();
                },
                child: const Text('Continue Call'),
              ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _leaveChannel();
    _allowScreenshots();
    _instaTimer?.cancel();
    _startupDelayTimer?.cancel();
    _callTimer.cancel(); // Cancel the main call timer
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

          // Main timer display at the top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.black.withOpacity(0.5),
              child: SafeArea(
                bottom: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.timer, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      _formatCallTime(_timeLeft),
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

          // Add Insta Talk timer if active (now below the main timer)
          if (widget.isInstaTalk && _timerStarted && !_instaTalkExpired)
            Positioned(
              top: MediaQuery.of(context).padding.top +
                  40, // Position below the main timer
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: Colors.amber.withOpacity(0.2),
                child: Row(
                  children: [
                    const Icon(Icons.timer, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(
                      'Free trial: $_remainingSeconds seconds remaining',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    LinearProgressIndicator(
                      value: _remainingSeconds / widget.instaTalkDuration,
                      backgroundColor: Colors.grey[800],
                      color: Colors.amber,
                      minHeight: 5,
                    ),
                  ],
                ),
              ),
            ),

          // Expired notice (adjust position)
          if (widget.isInstaTalk && _instaTalkExpired)
            Positioned(
              top: MediaQuery.of(context).padding.top +
                  40, // Position below the main timer
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.redAccent.withOpacity(0.3),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.white),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Free trial ended. Purchase to continue.',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                        ),
                        onPressed: () => _showContinueCallPrompt(),
                        child: const Text('Continue'),
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
