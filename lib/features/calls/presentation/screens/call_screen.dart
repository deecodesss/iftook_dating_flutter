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

class CallScreen0 extends StatefulWidget {
  final String meetingId;
  final String token;
  final String channel;
  final Function? onSessionEnd;
  final User participant;
  final bool isInstatalk;
  final bool isTrial;
  final int instaTalkDuration;
  final int initialTimer;
  final bool isIncomingCall;
  final String? callerName;
  final String? callerImage;

  const CallScreen0({
    Key? key,
    required this.meetingId,
    required this.token,
    required this.channel,
    required this.participant,
    this.initialTimer = 30,
    this.onSessionEnd,
    this.isInstatalk = false,
    this.isTrial = false,
    this.instaTalkDuration = 30,
    this.isIncomingCall = false,
    this.callerName,
    this.callerImage,
  }) : super(key: key);

  @override
  State<CallScreen0> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen0> {
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

  // Update the startTimers method to match VoiceCallScreen
  void _startTimers() {
    print("Starting timers:");
    print("Is InstaTalk: ${widget.isInstatalk}");
    print("Is Trial: ${widget.isTrial}");
    print("Initial Timer: ${widget.initialTimer}");

    setState(() {
      _timerStarted = true;
    });

    if (widget.isInstatalk) {
      if (widget.isTrial) {
        // Trial InstaTalk - 30 seconds countdown, then end call
        print("Starting TRIAL countdown timer (30 seconds)");
        _startTrialCountdownTimer();
      } else {
        // Paid InstaTalk - growing timer with auto-payment per minute
        print("Starting PAID InstaTalk growing timer with auto-payment");
        _startGrowingTimer();
        _startAutoPaymentTimer(true); // Use InstaTalk rate
      }
    } else {
      // Regular meeting - standard timer based on initialTimer parameter instead of fixed 30 minutes
      print(
          "Starting REGULAR meeting countdown timer (${widget.initialTimer} minutes)");
      _startRegularTimer();
      _startGrowingTimer(); // Also track elapsed time
      _startAutoPaymentTimer(false); // Use regular voice call rate
    }
  }

  // Update trial countdown timer
  void _startTrialCountdownTimer() {
    setState(() {
      _remainingSeconds = 30; // 30 seconds for trial
      _elapsedSeconds = 0;
    });

    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
          _elapsedSeconds++;
        } else {
          _sessionTimer?.cancel();
          // For trial, automatically end the call after 30 seconds
          _endCall();
        }
      });
    });
  }

  // Update growing timer for tracking elapsed time
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

  // Update regular timer to use initialTimer
  void _startRegularTimer() {
    setState(() {
      // Use initialTimer from widget parameter
      _remainingSeconds =
          widget.initialTimer * 60; // Convert minutes to seconds
    });

    // We use a separate timer for the countdown, not the same as _sessionTimer
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          timer.cancel();
          if (!_showingPaymentPrompt) {
            _sessionExpired = true;
            _showContinueCallPrompt();
          }
        }
      });
    });
  }

  // Update auto-payment timer to take a parameter
  void _startAutoPaymentTimer([bool isInstatalk = false]) {
    // Calculate rate per minute based on call type
    double ratePerMinute;
    if (isInstatalk) {
      // For InstaTalk, use instaTalk rate directly (already per minute)
      ratePerMinute = widget.participant.earnings?.live?.toDouble() ?? 0;
    } else {
      // For regular voice calls, divide voice rate by 30 (since it's for 30 minutes)
      final voiceRate = widget.participant.earnings?.voice ?? 300;
      ratePerMinute = voiceRate / 30;
    }

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

    // // Improved navigation - directly return to home screen
    // if (_hasRenewedSession) {
    //   Get.off(() => AddReviewScreen(
    //         userId: widget.participant.sId ?? '',
    //       ));
    // } else {
    //   // Navigate directly to home screen instead of using multiple Get.back()
    //   Get.offAllNamed('/');
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
          'End Call Warning OLDCALLSCREEN',
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
                  // Top section with enhanced call type and wallet balance
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Enhanced call type indicator with all necessary information
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: widget.isInstatalk
                                  ? [Colors.purple, Colors.deepPurple]
                                  : [Colors.blue, Colors.teal],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: widget.isInstatalk
                                    ? Colors.purple.withOpacity(0.3)
                                    : Colors.blue.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.isInstatalk ? Icons.star : Icons.event,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.isInstatalk
                                    ? widget.isTrial
                                        ? "InstaTalk Trial"
                                        : "InstaTalk"
                                    : "Voice Meeting",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Wallet Balance - Simplified
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

                  // Remove the redundant middle badge and continue with incoming/outgoing indicator
                  // Incoming/Outgoing indicator - Make it more compact
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

                  // User profile with status - more compact
                  Column(
                    children: [
                      // Profile photo - with colored border based on call type
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.isInstatalk
                                ? Colors.purple
                                : Colors.blue,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: widget.isInstatalk
                                  ? Colors.purple.withOpacity(0.2)
                                  : Colors.blue.withOpacity(0.2),
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

                  // Ultra-simplified timer display
                  _buildSimplifiedTimerDisplay(),

                  // Call controls - Improved spacing and visibility
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

  // Simplified timer display with only essential information
  Widget _buildSimplifiedTimerDisplay() {
    if (!_timerStarted) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Connecting...',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isInstatalk
              ? Colors.purple.withOpacity(0.3)
              : Colors.blue.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Timer display
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer,
                color: widget.isInstatalk ? Colors.purple : Colors.blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _formatTime(_elapsedSeconds),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),

          // Only show trial countdown if it's a trial call
          if (widget.isInstatalk && widget.isTrial)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                'Trial ends in: ${_formatTime(_remainingSeconds)}',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 13,
                ),
              ),
            ),

          // Rate display
          // Padding(
          //   padding: const EdgeInsets.only(top: 5),
          //   child: Text(
          //     widget.isInstatalk && widget.isTrial
          //         ? 'Free Trial'
          //         : '₹${_ratePerMinute.toStringAsFixed(0)}/min',
          //     style: TextStyle(
          //       color: Colors.grey[400],
          //       fontSize: 13,
          //     ),
          //   ),
          // ),
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
                  'Return to Home',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Update _purchaseCall method to fix the call to _startAutoPaymentTimer
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
          _elapsedSeconds = 0; // Reset elapsed time counter for new session

          if (widget.isInstatalk && !widget.isTrial) {
            if (_sessionTimer == null || !_sessionTimer!.isActive) {
              _startGrowingTimer();
            }
            if (_autoPaymentTimer == null || !_autoPaymentTimer!.isActive) {
              _startAutoPaymentTimer(true); // Use InstaTalk rate
            }
          } else {
            _remainingSeconds = 30 * 60; // New 30-minute session
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

    if (widget.onSessionEnd != null && !widget.isInstatalk) {
      widget.onSessionEnd!();
      return;
    }

    if (widget.participant == null) return;

    final prompt = widget.isInstatalk && widget.isTrial
        ? '30-second free voice call'
        : '${widget.initialTimer}-minute voice call session';

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
              _performEndCall();
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
}
