import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/features/calls/controllers/call_controller.dart';
import 'package:iftook/features/profile/data/models/user.dart';
import 'package:iftook/features/profile/presentation/screens/add_review_screen.dart';
import 'package:iftook/helpers/app_colors.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:iftook/core/services/shared_prefs.dart';
import 'package:iftook/features/calls/services/call_duration_service.dart';
import 'package:iftook/features/friends/controllers/chat_controller.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

class VoiceCallScreen extends StatefulWidget {
  final String meetingId;
  final String token;
  final String channel;
  final Function? onSessionEnd;
  final User? participant;
  final bool isInstaTalk;
  final bool isTrial;
  final int instaTalkDuration;
  final int initialTimer;
  final bool isIncomingCall;

  const VoiceCallScreen({
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
    this.isIncomingCall = false,
  }) : super(key: key);

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  final String appId = "5da40b914dcf4a089e8bbee75a926178";
  int? _remoteUid;
  bool _isMuted = false;
  bool _localUserJoined = false;
  late RtcEngine _engine;
  bool _isEngineInitialized = false;

  RxBool isConnecting = true.obs;
  RxString connectionStatus = 'Initializing...'.obs;

  // Timer variables
  Timer? _sessionTimer;
  Timer? _autoPaymentTimer;
  Timer? _startupDelayTimer;
  Timer? _walletRefreshTimer;
  int _remainingSeconds = 0;
  int _elapsedSeconds = 0;
  bool _sessionExpired = false;
  bool _showingPaymentPrompt = false;
  bool _timerStarted = false;
  bool _hasRenewedSession = false;
  bool _isRenewing = false;
  bool _callEnded = false;
  bool _isSpeakerOn = true;

  // Payment variables
  static const int AUTO_PAYMENT_INTERVAL = 60;
  double _ratePerMinute = 0;
  bool _autoPaymentEnabled = false;

  late final CallController _callController;
  late final CallDurationService _durationService;
  late final ChatController _chatController;

  @override
  void initState() {
    super.initState();
    _callController = Get.put(CallController());
    _durationService = Get.put(CallDurationService());
    _chatController = Get.put(ChatController());
    _initializeDurationService();

    // Initialize Agora engine first
    _initializeAgora().then((_) {
      if (mounted) {
        setState(() {
          _isEngineInitialized = true;
          // Set initial speaker state after engine is initialized
          _engine.setEnableSpeakerphone(_isSpeakerOn);
        });
      }
    });

    // Fetch initial wallet balance
    _chatController.fetchWalletBalance();

    // Setup wallet refresh timer
    _walletRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _chatController.fetchWalletBalance();
      }
    });

    print("Initializing Voice Call:");
    print("Is InstaTalk: ${widget.isInstaTalk}");
    print("Is Trial: ${widget.isTrial}");
    print("Initial Timer: ${widget.initialTimer}");
    print("Token: ${widget.token}, Channel: ${widget.channel}");

    // Initialize call variables
    if (widget.participant != null) {
      _ratePerMinute = widget.participant!.earnings?.voiceRate ?? 0;
      print("Rate per minute: $_ratePerMinute");
    }

    // Start timers
    _checkPermissions();
    _setupCallController();

    // End any existing call notifications.
    // This is generally safe. If CallNotificationService handled a call that led here,
    // its ID might be different, or endCall is idempotent for non-existent IDs.
    // For outgoing calls, this ensures no stale CallKit UI.
    // For incoming calls accepted via CallKit, CallNotificationService should have already ended it.
    FlutterCallkitIncoming.endCall(widget.meetingId);
  }

  Future<void> _checkPermissions() async {
    await Permission.microphone.request();
  }

  void _setupCallController() {
    // Setup any additional call controller logic here
  }

  Future<void> _initializeDurationService() async {
    if (widget.participant != null && widget.participant!.sId != null) {
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
      print("Voice Call: Both users connected, starting timers");
      print("Local user joined: $_localUserJoined");
      print("Remote user ID: $_remoteUid");
      _startTimers();
    } else if (!_timerStarted) {
      print("Voice Call: Not starting timers yet");
      print("Timer started: $_timerStarted");
      print("Local user joined: $_localUserJoined");
      print("Remote user ID: $_remoteUid");
    }
  }

  // Initialize the timers based on call type
  void _startTimers() {
    print("Starting timers:");
    print("Is InstaTalk: ${widget.isInstaTalk}");
    print("Is Trial: ${widget.isTrial}");
    print("Initial Timer: ${widget.initialTimer}");

    setState(() {
      _timerStarted = true;
    });

    if (widget.isInstaTalk) {
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

    if (widget.onSessionEnd != null) {
      widget.onSessionEnd!();
      return;
    }

    if (widget.participant == null) return;

    final prompt = widget.isInstaTalk && widget.isTrial
        ? '30-second free voice call'
        : '30-minute voice call session';

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
              'Rate: ₹${widget.participant!.earnings?.voiceRate ?? 300} for 30 minutes',
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

  // Show dialog when main timer expires
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

  void _purchaseCall() async {
    if (widget.participant == null) return;

    setState(() => _isRenewing = true);

    try {
      final callRate = widget.participant!.earnings?.voiceRate ?? 300.0;
      final success = await _callController.purchaseCallSession(
        widget.participant!.sId!,
        callRate,
        'voice',
        minutes: 30,
      );

      if (success) {
        setState(() {
          _sessionExpired = false;
          _hasRenewedSession = true;
          _isRenewing = false;
          _showingPaymentPrompt = false;

          // Reset session for continuing call
          if (widget.isInstaTalk && !widget.isTrial) {
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
          'Voice call session purchased',
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

  // Initialize Agora SDK
  Future<void> _initializeAgora() async {
    try {
      connectionStatus('Checking permissions...');
      await _requestPermissions();

      connectionStatus('Initializing engine...');
      _engine = createAgoraRtcEngine();
      await _engine.initialize(RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      _setupEventHandlers();

      connectionStatus('Joining channel...');
      print('Joining channel: ${widget.channel} with token: ${widget.token}');

      // Join the channel - Voice specific configuration
      await _engine.joinChannel(
        token: widget.token,
        channelId: widget.channel,
        uid: 0,
        options: const ChannelMediaOptions(
          autoSubscribeAudio: true, // Auto subscribe to audio
          publishMicrophoneTrack: true, // Publish microphone audio
          publishCameraTrack: false, // Don't publish camera for voice call
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (e) {
      print("Error in voice call initialization: $e");
      connectionStatus('Failed to initialize call');
      Get.snackbar(
        'Error',
        'Failed to initialize call. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Request microphone permission
  Future<void> _requestPermissions() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
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
          title: const Text('Microphone Permission Required'),
          content:
              const Text('Microphone permission is required for voice calls. '
                  'Please enable it in your device settings.'),
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
          print("Remote user $remoteUid joined");
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

  // Toggle microphone mute
  void _toggleMute() {
    if (!_isEngineInitialized) return;

    setState(() {
      _isMuted = !_isMuted;
    });
    _engine.muteLocalAudioStream(_isMuted);
  }

  // Toggle speaker
  void _toggleSpeaker() {
    if (!_isEngineInitialized) return;

    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    _engine.setEnableSpeakerphone(_isSpeakerOn);
  }

  // End the call
  void _endCall() {
    if (_isEngineInitialized) {
      _engine.leaveChannel();
      _engine.release();
    }
    _sessionTimer?.cancel();
    _autoPaymentTimer?.cancel();
    _startupDelayTimer?.cancel();
    _walletRefreshTimer?.cancel();
    _autoPaymentEnabled = false;

    // End the call in CallKit
    FlutterCallkitIncoming.endCall(widget.meetingId);

    if (widget.onSessionEnd != null) {
      widget.onSessionEnd!();
    }

    if (_hasRenewedSession) {
      Get.off(() => AddReviewScreen(
            userId: widget.participant?.sId ?? '',
          ));
    } else {
      Get.back();
    }
  }

  @override
  void dispose() {
    if (_isEngineInitialized) {
      _engine.leaveChannel();
      _engine.release();
    }
    _sessionTimer?.cancel();
    _autoPaymentTimer?.cancel();
    _startupDelayTimer?.cancel();
    _walletRefreshTimer?.cancel();
    _autoPaymentEnabled = false;
    _durationService.reset();

    // End the call in CallKit
    FlutterCallkitIncoming.endCall(widget.meetingId);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFF1A1A1A),
          body: SafeArea(
            child: _callEnded
                ? _buildCallEndedUI()
                : Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Timer display
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 16),
                        child: _buildTimerDisplay(),
                      ),

                      // Caller details section
                      Column(
                        children: [
                          // Profile photo
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
                          // Call type and status
                          Text(
                            widget.isInstaTalk
                                ? 'InstaTalk Voice Call'
                                : 'Voice Call',
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

                      // Call controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildCallButton(
                            icon: _isMuted ? Icons.mic_off : Icons.mic,
                            color: Colors.white,
                            backgroundColor:
                                _isMuted ? Colors.red : Colors.grey[800]!,
                            onTap: _toggleMute,
                          ),
                          _buildCallButton(
                            icon: Icons.call_end,
                            color: Colors.white,
                            backgroundColor: Colors.red,
                            onTap: _endCall,
                            size: 65,
                          ),
                          _buildCallButton(
                            icon: _isSpeakerOn
                                ? Icons.volume_up
                                : Icons.volume_off,
                            color: Colors.white,
                            backgroundColor:
                                _isSpeakerOn ? Colors.grey[800]! : Colors.red,
                            onTap: _toggleSpeaker,
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
          ),
        ),
        if (_isRenewing)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
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
                Icons.call_end,
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

  Widget _buildTimerDisplay() {
    // If it's an incoming call, don't show any timer
    if (widget.isIncomingCall) {
      return const SizedBox.shrink();
    }

    if (!_timerStarted) {
      return const SizedBox.shrink();
    }

    // For paid InstaTalk, show growing timer with payment info and wallet balance
    if (widget.isInstaTalk && !widget.isTrial) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryColor.withOpacity(0.7),
              Colors.blueGrey.withOpacity(0.5),
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
            const SizedBox(height: 8),
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
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: widget.isInstaTalk
            ? Colors.amber.withOpacity(0.2)
            : Colors.blueGrey.withOpacity(0.2),
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

  Widget _buildCallButton({
    required IconData icon,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onTap,
    double size = 50,
  }) {
    return InkWell(
      onTap: onTap,
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
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          icon,
          color: color,
          size: size * 0.5,
        ),
      ),
    );
  }
}
