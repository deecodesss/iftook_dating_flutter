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

class ITVoiceCallScreen extends StatefulWidget {
  final String meetingId;
  final String token;
  final String channel;
  final Function? onSessionEnd;
  final User participant;
  final bool isTrial;
  final int instaTalkDuration;
  final bool isIncomingCall;
  final String? callerName;
  final String? callerImage;

  const ITVoiceCallScreen({
    Key? key,
    required this.meetingId,
    required this.token,
    required this.channel,
    required this.participant,
    this.onSessionEnd,
    this.isTrial = false,
    this.instaTalkDuration = 30,
    this.isIncomingCall = false,
    this.callerName,
    this.callerImage,
  }) : super(key: key);

  @override
  State<ITVoiceCallScreen> createState() => _ITVoiceCallScreenState();
}

class _ITVoiceCallScreenState extends State<ITVoiceCallScreen> {
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
        "InstaTalk Voice Call initialized with participant: ${widget.participant.name}");
    print("InstaTalk Trial: ${widget.isTrial}");

    // Fetch initial wallet balance
    _chatController.fetchWalletBalance();

    // Setup wallet refresh timer
    _walletRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _chatController.fetchWalletBalance();
      }
    });

    // Initialize call variables
    _ratePerMinute = widget.participant.earnings?.live?.toDouble() ?? 0;

    // Start timers and setup
    _checkPermissions();

    // For incoming calls, stop the ringtone
    if (widget.isIncomingCall) {
      _stopCallRingtone();
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

  // Update the startTimers method to focus only on InstaTalk
  void _startTimers() {
    print("Starting InstaTalk timers:");
    print("Is Trial: ${widget.isTrial}");
    print("InstaTalk Duration: ${widget.instaTalkDuration}");

    setState(() {
      _timerStarted = true;
    });

    if (widget.isTrial) {
      // Trial InstaTalk - 30 seconds countdown, then end call
      print("Starting TRIAL countdown timer (30 seconds)");
      _startTrialCountdownTimer();
    } else {
      // Paid InstaTalk - growing timer with auto-payment per minute
      print("Starting PAID InstaTalk growing timer with auto-payment");
      _startGrowingTimer();
      _startAutoPaymentTimer();
    }
  }

  // Trial countdown timer
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

  // Growing timer for tracking elapsed time
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

  // Auto-payment timer specifically for InstaTalk
  void _startAutoPaymentTimer() {
    // For InstaTalk, use instaTalk rate directly (already per minute)
    _ratePerMinute = widget.participant.earnings?.live?.toDouble() ?? 0;

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
    _walletRefreshTimer?.cancel();
    _autoPaymentEnabled = false;

    // End the call in CallKit
    FlutterCallkitIncoming.endCall(widget.meetingId);

    // Call session end callback if provided
    if (widget.onSessionEnd != null) {
      widget.onSessionEnd!();
    }

    // Improved navigation - directly return to home screen
    if (_hasRenewedSession) {
      Get.off(() => AddReviewScreen(
            userId: widget.participant.sId ?? '',
          ));
    } else {
      // Navigate directly to home screen instead of using multiple Get.back()
      Get.offAllNamed('/');
    }
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
                        // InstaTalk call type indicator
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.purple, Colors.deepPurple],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.purple.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.isTrial
                                    ? "InstaTalk Trial"
                                    : "InstaTalk",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Wallet Balance
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
                      // Profile photo with purple border for InstaTalk
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.purple,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.withOpacity(0.2),
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

                      // Caller name
                      Text(
                        widget.participant.name ?? 'Unknown User',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Connection status
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
                  _buildInstaTalkTimerDisplay(),

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

  // InstaTalk-specific timer display
  Widget _buildInstaTalkTimerDisplay() {
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
          color: Colors.purple.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Timer display
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.timer,
                color: Colors.purple,
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

          // Trial countdown if applicable
          if (widget.isTrial)
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
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              widget.isTrial
                  ? 'Free Trial'
                  : '₹${_ratePerMinute.toStringAsFixed(0)}/min',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 13,
              ),
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
    setState(() => _isRenewing = true);

    try {
      final instaTalkRate = widget.participant.earnings?.live?.toDouble() ?? 0;
      // Purchase for InstaTalk session at the live rate
      final success = await _callController.purchaseCallSession(
        widget.participant.sId!,
        instaTalkRate * widget.instaTalkDuration, // Rate * duration
        'voice',
        minutes: widget.instaTalkDuration,
      );

      if (success) {
        setState(() {
          _sessionExpired = false;
          _hasRenewedSession = true;
          _isRenewing = false;
          _showingPaymentPrompt = false;
          _elapsedSeconds = 0; // Reset elapsed time for new session

          if (_sessionTimer == null || !_sessionTimer!.isActive) {
            _startGrowingTimer();
          }
          if (_autoPaymentTimer == null || !_autoPaymentTimer!.isActive) {
            _startAutoPaymentTimer();
          }
        });

        Get.snackbar(
          'Success',
          'InstaTalk session purchased',
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
        'Failed to purchase InstaTalk session',
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

    if (widget.onSessionEnd != null) {
      widget.onSessionEnd!();
      return;
    }

    final prompt = widget.isTrial
        ? '30-second free InstaTalk trial'
        : '${widget.instaTalkDuration}-minute InstaTalk session';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'InstaTalk Session Ended',
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
              'Would you like to continue this InstaTalk call?',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Text(
              'Rate: ₹${widget.participant.earnings?.live?.toStringAsFixed(0) ?? "0"}/minute',
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
