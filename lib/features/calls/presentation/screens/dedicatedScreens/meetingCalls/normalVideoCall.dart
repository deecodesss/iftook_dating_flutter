import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:iftook/features/profile/presentation/screens/add_review_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:no_screenshot/no_screenshot.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'package:iftook/features/profile/data/models/user.dart';
import 'package:iftook/features/calls/controllers/call_controller.dart';
import 'package:iftook/helpers/app_colors.dart';
import 'package:iftook/core/services/shared_prefs.dart';
import 'package:iftook/features/calls/services/call_duration_service.dart';
import 'package:iftook/features/friends/controllers/chat_controller.dart';

class NormalVideoCallScreen extends StatefulWidget {
  final String meetingId;
  final String token;
  final String channel;
  final Function? onSessionEnd;
  final User? participant;
  final double initialTimer;
  final bool fromChat;
  final bool isIncomingCall;

  const NormalVideoCallScreen({
    Key? key, // Add Key? key here
    required this.meetingId,
    required this.token,
    required this.channel,
    this.onSessionEnd,
    this.participant,
    required this.initialTimer,
    this.fromChat = false,
    this.isIncomingCall = false,
  }) : super(key: key); // Pass key to super

  @override
  State<NormalVideoCallScreen> createState() => _NormalVideoCallScreenState();
}

class _NormalVideoCallScreenState extends State<NormalVideoCallScreen> {
  int? _remoteUid; // Stores remote user ID
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  bool _localUserJoined =
      false; // Indicates if local user has joined the channel
  late RtcEngine _engine;
  final _noScreenshot = NoScreenshot.instance;
  RxBool isConnecting = true.obs;
  RxString connectionStatus = 'Initializing...'.obs;

  // Timer variables
  Timer? _sessionTimer;
  Timer? _autoPaymentTimer;
  int _remainingSeconds = 0;
  int _elapsedSeconds = 0; // For growing timer in InstaTalk
  bool _isCallConnected = false;
  bool _sessionExpired = false;
  bool _showingPaymentPrompt = false;
  bool _timerStarted = false;
  bool _hasRenewedSession = false;
  bool _isRenewing = false;
  bool _callEnded = false; // To track if call has been ended by remote user

  // Payment variables
  static const int AUTO_PAYMENT_INTERVAL = 60; // Seconds between auto payments
  double _ratePerMinute = 0;
  bool _autoPaymentEnabled = false;

  late final CallController _callController;
  late final CallDurationService _durationService;

  // Add ChatController for wallet balance
  late final ChatController _chatController;
  Timer? _walletRefreshTimer; // Timer for refreshing wallet balance

  // Get Agora app ID from environment or config
  final String appId = "5da40b914dcf4a089e8bbee75a926178";

  // Add these variables for last-minute payment and draggable timer
  bool _hasSentLastMinutePayment = false;
  Offset _timerPosition = Offset(20, 80); // Default position for floating timer
  bool _isDraggingTimer = false;

  @override
  void initState() {
    super.initState();
    // Get or create CallController instance
    _callController = Get.put(CallController());
    _durationService = Get.put(CallDurationService());
    _chatController = Get.put(ChatController());
    _initializeDurationService();

    // Fetch initial wallet balance
    _chatController.fetchWalletBalance();

    // Setup wallet refresh timer (every 30 seconds)
    _walletRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _chatController.fetchWalletBalance();
      }
    });

    _preventScreenshots();
    _setupScreenshotDetection();
    print(
        "Initializing with token: ${widget.token}, channel: ${widget.channel}");

    // Initialize call variables
    if (widget.participant != null) {
      _ratePerMinute = widget.participant!.earnings?.videoRate ?? 0;
    }

    _initializeCall();
  }

  Future<void> _initializeDurationService() async {
    if (widget.participant != null) {
      await _durationService.initialize(widget.participant!.sId!);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Don't start timers for incoming calls
    if (widget.isIncomingCall) {
      return;
    }

    // Start appropriate timer once we're connected
    if (!_timerStarted && _localUserJoined && _remoteUid != null) {
      print("Video Call: Both users connected, starting timers");
      print("Local user joined: $_localUserJoined");
      print("Remote user ID: $_remoteUid");
      _startTimers();
    } else if (!_timerStarted) {
      print("Video Call: Not starting timers yet");
      print("Timer started: $_timerStarted");
      print("Local user joined: $_localUserJoined");
      print("Remote user ID: $_remoteUid");
    }
  }

  // Initialize the timers based on call type
  void _startTimers() {
    print("Starting video call timers:");
    print("Initial Timer: ${widget.initialTimer}");

    setState(() {
      _timerStarted = true;
    });

    print(
        "Starting REGULAR meeting countdown timer (${widget.initialTimer} minutes)");
    _startRegularTimer();
  }

  void _startRegularTimer() {
    setState(() {
      _remainingSeconds = (widget.initialTimer * 60)
          .toInt(); // Convert minutes to seconds and ensure int type
      _hasSentLastMinutePayment = false; // Reset payment flag
    });

    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;

          // Check if we need to send last-minute payment for incoming calls
          if (widget.isIncomingCall &&
              _remainingSeconds <= 60 &&
              _remainingSeconds >=
                  59 && // Only trigger once at exactly 60 seconds remaining
              !_hasSentLastMinutePayment) {
            _sendLastMinutePayment();
          }
        } else {
          timer.cancel();
          if (!_showingPaymentPrompt) {
            _sessionExpired = true;

            // Handle differently based on incoming or outgoing call
            if (widget.isIncomingCall) {
              // For incoming calls, just restart the timer without payment
              _restartTimerForIncomingCall();
            } else {
              // For outgoing calls, show meeting ended popup
              _showMeetingEndedPopup();
            }
          }
        }
      });
    });
  }

  // Add method to send payment at the last minute
  void _sendLastMinutePayment() async {
    if (!widget.isIncomingCall || widget.participant == null) return;

    try {
      // Mark as paid to prevent duplicate payments
      _hasSentLastMinutePayment = true;

      // Get the call rate
      final videoRate = widget.participant!.earnings?.video ?? 500.0;

      print('Sending last-minute payment to participant: ₹$videoRate');

      // Call sendMoney method from chat controller
      final success = await _chatController.sendMoney(
        widget.participant!.sId!, // Recipient ID
        videoRate.toDouble(), // Amount to send
      );

      if (success) {
        print('Last minute payment sent successfully');
        Get.snackbar(
          'Payment Sent',
          'Call payment of ₹${videoRate.toStringAsFixed(0)} sent to ${widget.participant!.name}',
          backgroundColor: Colors.green.withOpacity(0.7),
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
      } else {
        print('Failed to send last-minute payment');
      }
    } catch (e) {
      print('Error sending last-minute payment: $e');
    }
  }

  // Add method to restart timer for incoming calls
  void _restartTimerForIncomingCall() {
    print("Restarting timer for incoming call without payment");
    setState(() {
      _sessionExpired = false;
      _remainingSeconds = (widget.initialTimer * 60)
          .toInt(); // Reset to initial timer value with proper conversion
      _hasSentLastMinutePayment = false; // Reset payment flag for next cycle
    });

    // Start the timer again
    _startRegularTimer();

    // Show a brief notification
    Get.snackbar(
      'Call Extended',
      'Your call has been automatically extended',
      backgroundColor: Colors.green.withOpacity(0.7),
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  // Replace existing showContinueCallPrompt with a simpler version that just ends the call
  void _showMeetingEndedPopup() {
    _showingPaymentPrompt = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Meeting Time Ended',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Your ${widget.initialTimer.toStringAsFixed(1)}-minute video call session with ${widget.participant?.name ?? "User"} has ended.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _endCall();
            },
            child: const Text('End Call'),
          ),
        ],
      ),
    );
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
        _engine = createAgoraRtcEngine();
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

            // Start timers when remote user joins
            if (!_timerStarted) {
              _startTimers();
            }
          });
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          print("Remote user $remoteUid left channel");
          setState(() {
            _remoteUid = null;
            connectionStatus('Call Ended');
            _callEnded = true;

            // Cancel timers when remote user disconnects
            _sessionTimer?.cancel();
            _autoPaymentTimer?.cancel();
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
    _sessionTimer?.cancel();
    _autoPaymentTimer?.cancel();
    _walletRefreshTimer?.cancel();
    _autoPaymentEnabled = false;

    if (widget.onSessionEnd != null) {
      widget.onSessionEnd!();
    }
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _leaveChannel();
    _allowScreenshots();
    _sessionTimer?.cancel();
    _autoPaymentTimer?.cancel();
    _walletRefreshTimer?.cancel();
    _autoPaymentEnabled = false;
    _durationService.reset();
    super.dispose();
  }

  // Build the UI with fullscreen video
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full screen remote video or waiting UI
          if (_callEnded)
            _buildCallEndedUI()
          else
            _remoteUid != null
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
                            'Video Call',
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

          // Local video preview
          if (_isVideoEnabled && !_callEnded)
            Container(
              margin: const EdgeInsets.only(top: 40, right: 16),
              child: Align(
                alignment: Alignment.topRight,
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
                      : Container(),
                ),
              ),
            ),

          // Participant name
          if (!_callEnded && _remoteUid != null)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.participant?.name ?? 'Unknown User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Incoming/outgoing indicator
          if (!_callEnded)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.isIncomingCall
                      ? Colors.green.withOpacity(0.6)
                      : Colors.blue.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.isIncomingCall
                          ? Icons.call_received
                          : Icons.call_made,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.isIncomingCall ? 'Incoming' : 'Outgoing',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Draggable floating timer
          if (_timerStarted && !_callEnded) _buildDraggableTimer(),

          // Call controls
          if (!_callEnded)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildCallButton(
                      icon: _isMuted ? Icons.mic_off : Icons.mic,
                      color: Colors.white,
                      backgroundColor:
                          _isMuted ? Colors.red : Colors.grey[800]!,
                      onPressed: _toggleMute,
                    ),
                    _buildCallButton(
                      icon:
                          _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                      color: Colors.white,
                      backgroundColor:
                          _isVideoEnabled ? Colors.grey[800]! : Colors.red,
                      onPressed: _toggleVideo,
                    ),
                    _buildCallButton(
                      icon: Icons.call_end,
                      color: Colors.white,
                      backgroundColor: Colors.red,
                      onPressed: _endCall,
                      size: 65,
                    ),
                    _buildCallButton(
                      icon: Icons.cameraswitch,
                      color: Colors.white,
                      backgroundColor: Colors.grey[800]!,
                      onPressed: _switchCamera,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Add draggable timer widget
  Widget _buildDraggableTimer() {
    // Calculate progress percentage for visual indicator
    final totalSeconds = widget.initialTimer * 60;
    final progressPercentage =
        (_remainingSeconds / totalSeconds).clamp(0.0, 1.0);

    // Calculate per-minute rate
    final videoRate = widget.participant?.earnings?.video ?? 500;
    // final perMinuteRate = videoRate / 30;
    final perMinuteRate = videoRate;

    return Positioned(
      left: _timerPosition.dx,
      top: _timerPosition.dy,
      child: GestureDetector(
        onPanStart: (details) {
          setState(() {
            _isDraggingTimer = true;
          });
        },
        onPanUpdate: (details) {
          setState(() {
            _timerPosition = Offset(
              (_timerPosition.dx + details.delta.dx)
                  .clamp(0, MediaQuery.of(context).size.width - 130),
              (_timerPosition.dy + details.delta.dy)
                  .clamp(50, MediaQuery.of(context).size.height - 100),
            );
          });
        },
        onPanEnd: (details) {
          setState(() {
            _isDraggingTimer = false;
          });
        },
        child: Container(
          width: 130,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isDraggingTimer
                  ? Colors.blue.withOpacity(0.8)
                  : Colors.blue.withOpacity(0.3),
              width: _isDraggingTimer ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Timer display
              Text(
                _formatTime(_remainingSeconds),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),

              const SizedBox(height: 4),

              // Progress indicator
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progressPercentage,
                  backgroundColor: Colors.grey[800],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  minHeight: 4,
                ),
              ),

              // Rate display
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '₹${perMinuteRate.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
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

  // New method to build UI when call has ended
  Widget _buildCallEndedUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Profile image with "call ended" icon overlay
          Stack(
            alignment: Alignment.center,
            children: [
              CircleAvatar(
                radius: 80,
                backgroundImage: widget.participant?.photos?.isNotEmpty == true
                    ? NetworkImage(widget.participant!.photos!.first)
                    : null,
                child: widget.participant?.photos?.isEmpty ?? true
                    ? const Icon(Icons.person, size: 70, color: Colors.white54)
                    : null,
              ),
              Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.5),
                ),
              ),
              const Icon(
                Icons.videocam_off,
                color: Colors.red,
                size: 50,
              ),
            ],
          ),
          const SizedBox(height: 30),

          // Call ended text
          const Text(
            'Call Ended',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // User disconnected message
          Text(
            '${widget.participant?.name ?? 'User'} has disconnected',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[400],
            ),
          ),

          const SizedBox(height: 50),

          // Return to home button
          ElevatedButton(
            // onPressed: () => Get.back(),
            onPressed: () => Get.off(() => AddReviewScreen(
                  userId: widget.participant!.sId ?? '',
                )),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'Return to Home',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  // Format time for display (MM:SS format)
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _showInsufficientBalanceDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Insufficient Balance',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Your wallet balance is too low to continue this call. Please add funds to your wallet.',
          style: TextStyle(color: Colors.white70),
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
              Get.toNamed('/wallet/topup');
              _endCall();
            },
            child: const Text('Top Up Wallet'),
          ),
        ],
      ),
    );
  }

  void _showPaymentErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Payment Error',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'There was an error processing your payment. The call will end now.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _endCall();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
