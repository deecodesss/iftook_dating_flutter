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
import 'package:iftook/features/friends/controllers/chat_controller.dart';

class VideoCallScreen0 extends StatefulWidget {
  final String meetingId;
  final String token;
  final String channel;
  final Function? onSessionEnd;
  final User? participant;
  final bool isInstatalk;
  final bool isTrial;
  final int instaTalkDuration;
  final int initialTimer;
  final bool fromChat;
  final bool isIncomingCall;

  const VideoCallScreen0({
    Key? key, // Add Key? key here
    required this.meetingId,
    required this.token,
    required this.channel,
    this.onSessionEnd,
    this.participant,
    this.isInstatalk = false,
    this.isTrial = false,
    this.instaTalkDuration = 30, // Default value if not provided
    required this.initialTimer,
    this.fromChat = false,
    this.isIncomingCall = false,
  }) : super(key: key); // Pass key to super

  @override
  State<VideoCallScreen0> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen0> {
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
    print("Is InstaTalk: ${widget.isInstatalk}");
    print("Is Trial: ${widget.isTrial}");
    print("Initial Timer: ${widget.initialTimer}");

    setState(() {
      _timerStarted = true;
    });

    if (widget.isInstatalk) {
      if (widget.isTrial) {
        // Trial InstaTalk - 30 seconds countdown
        print("Starting TRIAL countdown timer (30 seconds)");
        _startTrialCountdownTimer();
      } else {
        // Paid InstaTalk - growing timer with auto-payment
        print("Starting PAID InstaTalk growing timer with auto-payment");
        _startGrowingTimer();
        _startAutoPaymentTimer();
      }
    } else {
      // Regular meeting - standard timer based on session duration
      print(
          "Starting REGULAR meeting countdown timer (${widget.initialTimer} minutes)");
      _startRegularTimer();
    }
  }

  // Trial countdown timer (30 seconds)
  void _startTrialCountdownTimer() {
    setState(() {
      _remainingSeconds = 30; // 30 seconds for trial
    });

    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _sessionTimer?.cancel();
          if (!_showingPaymentPrompt) {
            _sessionExpired = true;
            _showContinueCallPrompt();
          }
        }
      });
    });
  }

  // Growing timer for paid InstaTalk
  void _startGrowingTimer() {
    setState(() {
      _elapsedSeconds = 0;
    });

    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedSeconds++;
      });
    });
  }

  // Auto-payment timer for paid InstaTalk
  void _startAutoPaymentTimer() {
    if (_ratePerMinute <= 0) return;

    _autoPaymentEnabled = true;
    const paymentIntervalSeconds = AUTO_PAYMENT_INTERVAL;

    _autoPaymentTimer = Timer.periodic(
        Duration(seconds: paymentIntervalSeconds), (timer) async {
      if (!_autoPaymentEnabled) return;

      try {
        // Calculate cost for the interval
        final minutesFraction = paymentIntervalSeconds / 60;
        final cost = _ratePerMinute * minutesFraction;

        // Get chat controller to process payment
        final chatController = Get.find<ChatController>();

        // Check if user has enough balance
        await chatController.fetchWalletBalance();
        if (chatController.userWalletBalance.value < cost) {
          // Stop timer and show insufficient balance message
          _autoPaymentTimer?.cancel();
          _showInsufficientBalanceDialog();
          return;
        }

        // Silently process payment
        final success = await chatController.purchaseChatSession(
            widget.participant!.sId!, cost,
            minutes: 1, silent: true);

        if (!success) {
          throw Exception('Payment failed');
        }
      } catch (e) {
        print('Auto-payment error: $e');
        _autoPaymentTimer?.cancel();
        _showPaymentErrorDialog();
      }
    });
  }

  // Regular countdown timer for scheduled meetings
  void _startRegularTimer() {
    setState(() {
      _remainingSeconds =
          widget.initialTimer * 60; // Convert minutes to seconds
    });

    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _sessionTimer?.cancel();
          if (!_showingPaymentPrompt) {
            _sessionExpired = true;
            _showContinueCallPrompt();
          }
        }
      });
    });
  }

  // Format time for display
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

  void _showContinueCallPrompt() {
    _showingPaymentPrompt = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Session Ended',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.isInstatalk && widget.isTrial
                  ? 'Your 30-second free video call has ended.'
                  : 'Your video call session has ended.',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            const Text(
              'Would you like to continue this call?',
              style: TextStyle(color: Colors.white70),
            ),
            if (widget.participant != null) ...[
              const SizedBox(height: 16),
              Text(
                'Rate: ₹${widget.participant!.earnings?.videoRate ?? 500} per minute',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
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

    setState(() => _isRenewing = true);

    try {
      final callRate = widget.participant!.earnings?.videoRate ?? 500.0;
      final success = await _callController.purchaseCallSession(
        widget.participant!.sId!,
        callRate,
        'video',
        minutes: 30,
      );

      if (success) {
        setState(() {
          _sessionExpired = false;
          _hasRenewedSession = true;
          _isRenewing = false;
          _showingPaymentPrompt = false;

          // Reset session for continuing call
          if (widget.isInstatalk && !widget.isTrial) {
            // For paid InstaTalk, continue growing timer
            // Don't reset _elapsedSeconds, just continue
            if (_sessionTimer == null || !_sessionTimer!.isActive) {
              _startGrowingTimer();
            }
            if (_autoPaymentTimer == null || !_autoPaymentTimer!.isActive) {
              _startAutoPaymentTimer();
            }
          } else {
            // For regular call or trial that got converted to paid
            _remainingSeconds = 30 * 60; // 30 minutes
            if (_sessionTimer == null || !_sessionTimer!.isActive) {
              _startRegularTimer();
            }
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
      setState(() => _isRenewing = false);
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

  // Build the UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Show call ended UI when the remote user disconnects
          if (_callEnded)
            _buildCallEndedUI()
          else
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
                              widget.isInstatalk
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

          // Local video (only shown if video is enabled and call is active)
          if (_isVideoEnabled && !_callEnded)
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

          // Timer display at the top (only shown when call is active)
          if (_timerStarted && !_callEnded)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: Colors.black.withOpacity(0.7),
                child: SafeArea(
                  bottom: false,
                  child: _buildTimerDisplay(),
                ),
              ),
            ),

          // Call controls (only shown when call is active)
          if (!_callEnded)
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
                      icon:
                          _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                      color: Colors.white,
                      backgroundColor:
                          _isVideoEnabled ? Colors.blue : Colors.red,
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

          // Renewal loading overlay
          if (_isRenewing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimerDisplay() {
    // If it's an incoming call, don't show any timer
    if (widget.isIncomingCall) {
      return const SizedBox.shrink();
    }

    // For paid InstaTalk, show growing timer with payment info and wallet balance
    if (widget.isInstatalk && !widget.isTrial) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryColor.withOpacity(0.8),
              Colors.black.withOpacity(0.6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer, color: Colors.white, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        _formatTime(_elapsedSeconds),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.attach_money,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '₹${_ratePerMinute.toStringAsFixed(2)}/min',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Obx(() => Row(
                      children: [
                        const Icon(Icons.account_balance_wallet,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Balance: ₹${_chatController.userWalletBalance.value.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    )),
              ],
            ),
          ],
        ),
      );
    }

    // For countdown timers (trial InstaTalk or regular meetings)
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: widget.isInstatalk
            ? Colors.amber.withOpacity(0.3)
            : Colors.blueGrey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            _formatTime(_remainingSeconds),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'remaining',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
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
            onPressed: () => Get.back(),
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
}
