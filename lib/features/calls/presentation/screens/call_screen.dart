import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
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
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

class CallScreen extends StatefulWidget {
  final String meetingId;
  final String token;
  final String channel;
  final Function? onSessionEnd;
  final User participant;
  final bool isInstaTalk;
  final bool isTrial;
  final int instaTalkDuration;
  final int initialTimer;
  final bool isIncomingCall;
  final String? callerName;
  final String? callerImage;

  const CallScreen({
    Key? key,
    required this.meetingId,
    required this.token,
    required this.channel,
    required this.participant,
    this.initialTimer = 30,
    this.onSessionEnd,
    this.isInstaTalk = false,
    this.isTrial = false,
    this.instaTalkDuration = 30,
    this.isIncomingCall = false,
    this.callerName,
    this.callerImage,
  }) : super(key: key);

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final String appId = "5da40b914dcf4a089e8bbee75a926178";
  int? _remoteUid;
  bool _isMuted = false;
  bool _localUserJoined = false;
  late RtcEngine _engine;
  bool _isEngineInitialized = false;
  bool _isSpeakerOn = true;
  bool _isConnecting = true;
  String _connectionStatus = 'Initializing...';

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

    // Initialize Agora engine
    _initializeAgora().then((_) {
      if (mounted) {
        setState(() {
          _isEngineInitialized = true;
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

    // Initialize call variables
    // if (widget.participant != null) { // participant is non-nullable
    _ratePerMinute = widget.participant.earnings?.voiceRate ?? 0;
    // }

    // Start timers and setup
    _checkPermissions(); // This requests microphone, which is fine.
    // _setupCallController(); // This was empty, can be removed if not used.

    // For incoming calls, stop the ringtone as CallNotificationService should have started it.
    // The CallKit UI should have already been dismissed by CallNotificationService.
    if (widget.isIncomingCall) {
      _stopCallRingtone();
      // No need to call FlutterCallkitIncoming.endCall here if CallNotificationService._handleCallAccept does it.
    }
  }

  Future<void> _playCallRingtone() async {
    try {
      // Ensure any previous ringtone is stopped before playing a new one.
      await FlutterRingtonePlayer().stop();
      await FlutterRingtonePlayer().play(
        android: AndroidSounds.ringtone,
        ios: IosSounds.electronic,
        looping: true,
        volume: 1.0,
        asAlarm: true,
      );
    } catch (e) {
      debugPrint('Error playing call ringtone: $e');
    }
  }

  Future<void> _stopCallRingtone() async {
    try {
      await FlutterRingtonePlayer().stop();
    } catch (e) {
      debugPrint('Error stopping call ringtone: $e');
    }
  }

  Future<void> _initializeAgora() async {
    try {
      _connectionStatus = 'Checking permissions...';
      // await _requestPermissions(); // Permissions are requested in _checkPermissions

      _connectionStatus = 'Initializing engine...';
      _engine = createAgoraRtcEngine();
      await _engine.initialize(RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      _setupEventHandlers();

      _connectionStatus = 'Joining channel...';
      await _engine.joinChannel(
        token: widget.token,
        channelId: widget.channel,
        uid: 0,
        options: const ChannelMediaOptions(
          autoSubscribeAudio: true,
          publishMicrophoneTrack: true,
          publishCameraTrack: false,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (e) {
      print("Error in voice call initialization: $e");
      _connectionStatus = 'Failed to initialize call';
      Get.snackbar(
        'Error',
        'Failed to initialize call. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _setupEventHandlers() {
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          print("Local user ${connection.localUid} joined successfully");
          setState(() {
            _localUserJoined = true;
            _connectionStatus = 'Waiting for other participant...';
          });
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          print("Remote user $remoteUid joined");
          setState(() {
            _remoteUid = remoteUid;
            _isConnecting = false;
            _connectionStatus = 'Connected';
            // Stop ringtone and end CallKit UI when remote user joins and call is established
            // This is a good place to ensure CallKit is dismissed if not already.
            // CallNotificationService._handleCallAccept should have already called endCall.
            // _stopCallRingtone(); // Already called in initState if isIncomingCall
            // FlutterCallkitIncoming.endCall(widget.meetingId); // Redundant if CallNotificationService handled it

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
            _connectionStatus = 'Call Ended';
            _callEnded = true;
            _sessionTimer?.cancel();
            _autoPaymentTimer?.cancel();
          });
        },
        onError: (ErrorCodeType err, String msg) {
          print("Agora error: $err - $msg");
          _connectionStatus = 'Connection error: $err';
        },
      ),
    );
  }

  void _startTimers() {
    setState(() {
      _timerStarted = true;
    });

    if (widget.isInstaTalk) {
      if (widget.isTrial) {
        _startTrialCountdownTimer();
      } else {
        _startGrowingTimer();
        _startAutoPaymentTimer();
      }
    } else {
      _startRegularTimer();
    }
  }

  void _startTrialCountdownTimer() {
    setState(() {
      _remainingSeconds = 30;
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

  void _startRegularTimer() {
    setState(() {
      _remainingSeconds = widget.initialTimer * 60;
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

  void _startAutoPaymentTimer() {
    if (_ratePerMinute <= 0) return;

    _autoPaymentEnabled = true;
    _autoPaymentTimer =
        Timer.periodic(Duration(seconds: AUTO_PAYMENT_INTERVAL), (timer) async {
      if (!_autoPaymentEnabled) return;

      try {
        final minutesFraction = AUTO_PAYMENT_INTERVAL / 60;
        final cost = _ratePerMinute * minutesFraction;

        await _chatController.fetchWalletBalance();
        if (_chatController.userWalletBalance.value < cost) {
          _autoPaymentTimer?.cancel();
          _showInsufficientBalanceDialog();
          return;
        }

        final success = await _chatController.purchaseChatSession(
            widget.participant.sId!, cost,
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

  void _toggleMute() {
    if (!_isEngineInitialized) return;

    setState(() {
      _isMuted = !_isMuted;
    });
    _engine.muteLocalAudioStream(_isMuted);
  }

  void _toggleSpeaker() {
    if (!_isEngineInitialized) return;

    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    _engine.setEnableSpeakerphone(_isSpeakerOn);
  }

  void _endCall() async {
    if (_isEngineInitialized) {
      await _engine.leaveChannel();
      await _engine.release();
    }
    _sessionTimer?.cancel();
    _autoPaymentTimer?.cancel();
    _startupDelayTimer?.cancel();
    _walletRefreshTimer?.cancel();
    _autoPaymentEnabled = false;

    await _stopCallRingtone();
    // Ensure CallKit UI is dismissed. CallNotificationService should handle this primarily.
    // However, a safeguard here might be okay.
    await FlutterCallkitIncoming.endCall(widget.meetingId);

    if (widget.onSessionEnd != null) {
      widget.onSessionEnd!();
    }
    Get.back();

    if (_hasRenewedSession) {
      Get.off(() => AddReviewScreen(
            userId: widget.participant.sId ?? '',
          ));
    } else {
      Get.back();
    }
  }

  Future<void> _checkPermissions() async {
    await Permission.microphone.request();
  }

  Future<void> _initializeDurationService() async {
    // if (widget.participant != null) { // participant is non-nullable
    await _durationService.initialize(widget.participant.sId!);
    // }
  }

  // void _setupCallController() { // Empty method, can be removed
  //   // Setup any additional call controller logic here
  // }

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

    _stopCallRingtone();
    // Ensure CallKit UI is dismissed on dispose as well.
    FlutterCallkitIncoming.endCall(widget.meetingId);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: _callEnded
            ? _buildCallEndedUI()
            : Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Timer display
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: _buildTimerDisplay(),
                  ),

                  // Caller details section
                  Column(
                    children: [
                      CircleAvatar(
                        radius: 70,
                        backgroundImage:
                            widget.participant.photos?.isNotEmpty == true
                                ? NetworkImage(widget.participant.photos!.first)
                                : null,
                        child: widget.participant.photos?.isEmpty ?? true
                            ? const Icon(Icons.person,
                                size: 70, color: Colors.white54)
                            : null,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.participant.name ?? 'Unknown User',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
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
                      Text(
                        _connectionStatus,
                        style: TextStyle(
                          fontSize: 16,
                          color: _isConnecting ? Colors.amber : Colors.green,
                        ),
                      ),
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
                        icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
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
    );
  }

  Widget _buildCallEndedUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              CircleAvatar(
                radius: 80,
                backgroundImage: widget.participant.photos?.isNotEmpty == true
                    ? NetworkImage(widget.participant.photos!.first)
                    : null,
                child: widget.participant.photos?.isEmpty ?? true
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
          const Text(
            'Call Ended',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${widget.participant.name ?? 'User'} has disconnected',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 50),

          // Return to home button - Fix navigation
          ElevatedButton(
            onPressed: () {
              debugPrint('Return to Home button pressed in CallScreen');

              // Ensure we end the call properly first
              if (_isEngineInitialized) {
                _engine.leaveChannel();
                _engine.release();
              }

              // End any call notifications
              FlutterCallkitIncoming.endAllCalls();

              // Navigate to home - use both methods for reliability
              Get.offAllNamed('/');

              // Alternative if the above doesn't work
              if (Get.currentRoute != '/') {
                Get.until((route) => route.isFirst);
              }
            },
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
    // For incoming calls that are not yet connected, or if timer hasn't started,
    // show nothing or a connecting indicator, not a timer.
    // The existing logic for _timerStarted handles this.
    // if (widget.isIncomingCall && !_timerStarted) { // Modified this condition
    //   return const SizedBox.shrink(); // Or a "Connecting..." text
    // }

    if (!_timerStarted) {
      return const SizedBox.shrink();
    }

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
              'Your $prompt with ${widget.participant.name ?? "User"} has ended.',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            const Text(
              'Would you like to continue this call?',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Text(
              'Rate: ₹${widget.participant.earnings?.voiceRate ?? 300} for 30 minutes',
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

    setState(() => _isRenewing = true);

    try {
      final callRate = widget.participant.earnings?.voiceRate ?? 300.0;
      final success = await _callController.purchaseCallSession(
        widget.participant.sId!,
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

          if (widget.isInstaTalk && !widget.isTrial) {
            if (_sessionTimer == null || !_sessionTimer!.isActive) {
              _startGrowingTimer();
            }
            if (_autoPaymentTimer == null || !_autoPaymentTimer!.isActive) {
              _startAutoPaymentTimer();
            }
          } else {
            _remainingSeconds = 30 * 60;
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
}
