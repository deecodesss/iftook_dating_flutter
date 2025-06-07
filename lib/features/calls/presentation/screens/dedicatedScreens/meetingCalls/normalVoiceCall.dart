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

class NormalVoiceCallScreen extends StatefulWidget {
  final String meetingId;
  final String token;
  final String channel;
  final Function? onSessionEnd;
  final User participant;
  final double initialTimer;
  final bool isIncomingCall;
  final String? callerName;
  final String? callerImage;

  const NormalVoiceCallScreen({
    Key? key,
    required this.meetingId,
    required this.token,
    required this.channel,
    required this.participant,
    this.initialTimer = 30,
    this.onSessionEnd,
    this.isIncomingCall = false,
    this.callerName,
    this.callerImage,
  }) : super(key: key);

  @override
  State<NormalVoiceCallScreen> createState() => _NormalVoiceCallScreenState();
}

class _NormalVoiceCallScreenState extends State<NormalVoiceCallScreen> {
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
  bool _hasSentLastMinutePayment =
      false; // Flag to track if payment was sent for current timer cycle

  // Payment variables
  // static const int AUTO_PAYMENT_INTERVAL = 60;
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
    print(
        "CallScreen initialized with participant: ${widget.participant.name}");
    print("CallScreen initialTimer: ${widget.initialTimer}");

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

    // Print initialTimer for debugging
    print("Setting up call with initialTimer: ${widget.initialTimer} minutes");
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

  // Update the startTimers method to only start countdown from initialTimer
  void _startTimers() {
    print(
        "Starting timers for regular meeting with initialTimer: ${widget.initialTimer}");

    setState(() {
      _timerStarted = true;
    });

    // Start with the initial timer value (don't start from 0)
    print("Starting countdown timer from ${widget.initialTimer} minutes");
    _startRegularTimer();

    // Don't start auto-payment yet - we'll start it only after user continues
    // _startAutoPaymentTimer() will be called after the user chooses to continue
  }

  // Regular timer to countdown from initialTimer
  void _startRegularTimer() {
    setState(() {
      // Use initialTimer from widget parameter and convert to seconds (as int)
      _remainingSeconds =
          (widget.initialTimer * 60).toInt(); // Convert minutes to seconds
      _elapsedSeconds = 0; // Reset elapsed time
      _hasSentLastMinutePayment =
          false; // Reset payment flag when starting a new timer
    });

    // Create a timer for the countdown
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
          _elapsedSeconds++; // Also track elapsed time for billing

          // Check if we need to send last-minute payment for incoming calls
          if (widget.isIncomingCall &&
              _remainingSeconds <= 60 &&
              _remainingSeconds >=
                  59 && // Only trigger once at exactly 60 seconds remaining
              !_hasSentLastMinutePayment) {
            _sendLastMinutePayment();
            _showPaymentAnimation(); // Show animation when payment is triggered
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
              // For outgoing calls, show meeting ended popup and end call
              _showMeetingEndedPopup();
            }
          }
        }
      });
    });
  }

  // Add a new method to show meeting ended popup
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
            'Your ${widget.initialTimer.toStringAsFixed(1)}-minute voice call session with ${widget.participant.name ?? "User"} has ended.',
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
                _performEndCall();
              },
              child: const Text('End Call'),
            ),
          ]),
    );

    // Insert the overlay entry
    // overlayState.insert(overlayEntry);
  }

  // Add new method to show payment animation
  void _showPaymentAnimation() {
    // Create an overlay that shows a payment animation
    OverlayState? overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: TweenAnimationBuilder(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 700),
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: 1.0 + (0.3 * (value < 0.5 ? value : 1.0 - value) * 2),
                  child: Opacity(
                    opacity: value < 0.8 ? value * 1.25 : (1.0 - value) * 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primaryColor,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.isIncomingCall
                                    ? Icons.call_received
                                    : Icons.call_made,
                                color: widget.isIncomingCall
                                    ? Colors.green
                                    : Colors.red,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                widget.isIncomingCall
                                    ? "Payment Received"
                                    : "Payment Sent",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Show the coin animation
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.currency_rupee,
                                color: Colors.amber,
                                size: 20,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.participant.earnings?.voice.toString() ??
                                    "300",
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              onEnd: () {
                overlayEntry.remove();
              },
            ),
          ),
        ),
      ),
    );

    // Insert the overlay entry
    overlayState.insert(overlayEntry);
  }

  // Add new method to send payment when timer hits last minute
  void _sendLastMinutePayment() async {
    if (!widget.isIncomingCall) return;

    try {
      // Mark as paid to prevent duplicate payments
      _hasSentLastMinutePayment = true;

      // Get the call rate
      final voiceRate = widget.participant.earnings?.voice ?? 300.0;

      print('Sending last-minute payment to participant: ₹$voiceRate');

      // Call sendMoney method from chat controller
      final success = await _chatController.sendMoney(
        widget.participant.sId!, // Recipient ID
        voiceRate.toDouble(), // Amount to send
      );

      if (success) {
        print('Last minute payment sent successfully');
        // Payment notification now handled by animation
      } else {
        print('Failed to send last minute payment');
        // Still show a snackbar for errors
        Get.snackbar(
          'Payment Failed',
          'Failed to send payment. Please check your balance.',
          backgroundColor: Colors.red.withOpacity(0.7),
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      print('Error sending last minute payment: $e');
    }
  }

  // Update restart timer method to reset payment flag
  void _restartTimerForIncomingCall() {
    print("Restarting timer for incoming call without payment");
    setState(() {
      _sessionExpired = false;
      _elapsedSeconds = 0;
      _remainingSeconds =
          (widget.initialTimer * 60).toInt(); // Convert to int properly
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

  // Update auto-payment timer without InstaTalk parameter
  void _startAutoPaymentTimer() {
    // For regular voice calls, divide voice rate by 30 (since it's for 30 minutes)
    final voiceRate = widget.participant.earnings?.voice ?? 300;
    double ratePerMinute = voiceRate / 30;

    // Update the stored rate
    _ratePerMinute = ratePerMinute;

    if (_ratePerMinute <= 0) return;

    _autoPaymentEnabled = true;
    const paymentIntervalSeconds = 60; // Charge every minute

    _autoPaymentTimer = Timer.periodic(
        Duration(seconds: paymentIntervalSeconds), (timer) async {
      if (!_autoPaymentEnabled) return;

      try {
        // Calculate cost for one minute
        final cost = _ratePerMinute;

        await _chatController.fetchWalletBalance();
        if (_chatController.userWalletBalance.value < cost) {
          // Stop timer and show insufficient balance message
          _autoPaymentTimer?.cancel();
          _showInsufficientBalanceDialog();
          return;
        }

        // Process payment for one minute
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

  // End the call
  void _endCall() {
    // For incoming calls, show a warning popup before ending
    if (widget.isIncomingCall && !_callEnded && _remoteUid != null) {
      _showEndCallWarningDialog();
      return;
    }

    _performEndCall();
  }

  void _performEndCall() {
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

    // Call session end callback if provided
    if (widget.onSessionEnd != null) {
      widget.onSessionEnd!();
    }
    Get.back(); // Navigate back to previous screen

    // Improved navigation - directly return to home screen
    // if (_hasRenewedSession) {
    //   Get.off(() => AddReviewScreen(
    //         userId: widget.participant.sId ?? '',
    //       ));
    // } else {
    //   // Navigate directly to home screen instead of using multiple Get.back()
    //   Get.offAllNamed('/');
    //   // Get.off(());
    // }
  }

  // New method to show warning dialog for incoming calls
  void _showEndCallWarningDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'End Call Warning',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'If you end this call now, you will not receive payment for this session. Are you sure you want to end the call?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _performEndCall();
            },
            child: const Text('End Call'),
          ),
        ],
      ),
    );
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
                  // Top section with call type and wallet balance
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Call type indicator
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.blue, Colors.teal],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.event,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.isIncomingCall
                                    ? "Voice Call"
                                    : "Voice Call",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Show wallet balance only for outgoing calls
                        Obx(() => Text(
                              '₹${_chatController.userWalletBalance.value.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            )),
                      ],
                    ),
                  ),

                  // Incoming/Outgoing indicator
                  Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
                    decoration: BoxDecoration(
                      color: widget.isIncomingCall
                          ? Colors.green.withOpacity(0.15)
                          : Colors.blue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.isIncomingCall
                              ? Icons.call_received
                              : Icons.call_made,
                          color: widget.isIncomingCall
                              ? Colors.green
                              : Colors.blue,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.isIncomingCall ? "Incoming" : "Outgoing",
                          style: TextStyle(
                            color: widget.isIncomingCall
                                ? Colors.green
                                : Colors.blue,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // User profile with status
                  Column(
                    children: [
                      // Profile photo
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.blue,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.2),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: widget.participant.photos?.isNotEmpty == true
                            ? CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.grey[800],
                                backgroundImage: NetworkImage(
                                    widget.participant.photos!.first),
                                onBackgroundImageError: (_, __) {},
                              )
                            : CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.grey[800],
                                child: const Icon(Icons.person,
                                    size: 60, color: Colors.white54),
                              ),
                      ),
                      const SizedBox(height: 16),

                      // Caller name and status
                      Text(
                        widget.participant.name ?? 'Unknown User',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Connection status with colored indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: _isConnecting
                              ? Colors.amber.withOpacity(0.2)
                              : Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _connectionStatus,
                          style: TextStyle(
                            fontSize: 14,
                            color: _isConnecting ? Colors.amber : Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Timer display
                  _buildSimplifiedTimerDisplay(),

                  // Call controls
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Row(
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
                          icon:
                              _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                          color: Colors.white,
                          backgroundColor:
                              _isSpeakerOn ? Colors.grey[800]! : Colors.red,
                          onTap: _toggleSpeaker,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // Simplified timer display that shows countdown remaining
  Widget _buildSimplifiedTimerDisplay() {
    if (!_timerStarted) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Connecting...',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      );
    }

    // Calculate progress percentage for visual indicator
    final totalSeconds = widget.initialTimer * 60;
    final progressPercentage =
        (_remainingSeconds / totalSeconds).clamp(0.0, 1.0);

    // Calculate per-minute rate
    final voiceRate = widget.participant.earnings?.voice ?? 300;
    final perMinuteRate = voiceRate / 30;

    return Center(
      child: Container(
        width: 180, // Set fixed width to make it more compact
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.blue.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Keep column tight
          children: [
            // Timer display (remaining time)
            Row(
              mainAxisAlignment: MainAxisAlignment.center, // Center the time
              children: [
                const Icon(
                  Icons.timer,
                  color: Colors.blue,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatTime(_remainingSeconds),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Progress indicator
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progressPercentage,
                backgroundColor: Colors.grey[800],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                minHeight: 6,
              ),
            ),

            // Rate display - always show per-minute rate
            // Padding(
            //   padding: const EdgeInsets.only(top: 6),
            //   child: Text(
            //     '₹${perMinuteRate.toStringAsFixed(2)}/min',
            //     style: TextStyle(
            //       color: Colors.grey[400],
            //       fontSize: 12,
            //     ),
            //   ),
            // ),
          ],
        ),
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

  // Improved call ended UI
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
            '${widget.participant.name ?? 'User'} has disconnected',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[400],
            ),
          ),

          const SizedBox(height: 50),

          // Return to home button with improved visuals
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

              // Navigate to home
              // Get.offAllNamed('/');
              Get.back(); // Navigate back to previous screen

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
              elevation: 4,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.home, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Exit',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Replace the _showContinueCallPrompt method to use the meeting ended popup
  void _showContinueCallPrompt() {
    // This is now replaced with the simple meeting ended popup
    _showMeetingEndedPopup();
  }

  // Remove _purchaseCall functionality - comment it out or replace with stub
  void _purchaseCall() {
    // Simply end the call instead of renewing
    _performEndCall();
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
}
