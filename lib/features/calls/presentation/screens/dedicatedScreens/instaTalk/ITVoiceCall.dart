import 'dart:async';
import 'dart:convert';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:get/get.dart';
import 'package:iftook/core/services/shared_prefs.dart';
import 'package:iftook/features/calls/controllers/call_controller.dart';
import 'package:iftook/features/calls/controllers/call_status_controller.dart';
import 'package:iftook/features/profile/data/models/user.dart';
import 'package:iftook/features/profile/presentation/screens/add_review_screen.dart';
import 'package:iftook/helpers/app_colors.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:iftook/features/calls/services/call_duration_service.dart';
import 'package:iftook/features/friends/controllers/chat_controller.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:iftook/core/services/api_service.dart';

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

class _ITVoiceCallScreenState extends State<ITVoiceCallScreen>
    with TickerProviderStateMixin {
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
  Timer? _healthCheckTimer; // Add health check timer
  int _remainingSeconds = 0;
  int _elapsedSeconds = 0;
  bool _timerStarted = false;
  bool _callEnded = false;

  // Payment variables
  double _ratePerMinute = 0;
  bool _autoPaymentEnabled = false;

  // late final CallController _callController;
  late final CallDurationService _durationService;
  late final ChatController _chatController;

  // Add variables for fetched user data
  User? _fetchedParticipant;
  bool _isLoadingUserData = true;

  // Add animation variables for payment indication
  late AnimationController _paymentAnimationController;
  late Animation<double> _paymentFadeAnimation;
  late Animation<Offset> _paymentSlideAnimation;
  String _lastPaymentAmount = '';
  bool _showPaymentAnimation = false;

  @override
  void initState() {
    super.initState();
    // _callController = Get.put(CallController());
    _durationService = Get.put(CallDurationService());
    _chatController = Get.put(ChatController());
    _initializeDurationService();

    // Fetch complete user data from backend
    _fetchParticipantData();
    CallStatusController.to.userEnteredCallScreen();

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
    _walletRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        _chatController.fetchWalletBalance();
      }
    });

    _checkPermissions();
    if (widget.isIncomingCall) {
      _stopCallRingtone();
    }

    // Initialize payment animation controller
    _paymentAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _paymentFadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _paymentAnimationController,
      curve: Curves.easeOut,
    ));

    _paymentSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -1),
    ).animate(CurvedAnimation(
      parent: _paymentAnimationController,
      curve: Curves.easeOut,
    ));

    // Start health check timer to verify all variables every 10 seconds
    _startHealthCheckTimer();
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
      _connectionStatus = 'Initializing call...';
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
    print("Starting InstaTalk timers:");
    print("Is Trial: ${widget.isTrial}");
    print("InstaTalk Duration: ${widget.instaTalkDuration}");

    setState(() {
      _timerStarted = true;
    });

    if (widget.isTrial) {
      print("Starting TRIAL countdown timer (30 seconds)");
      _startTrialCountdownTimer();
    } else {
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

  // Add health check timer to verify all variables and data loading
  void _startHealthCheckTimer() {
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _performHealthCheck();
    });
  }

  // Comprehensive health check function
  void _performHealthCheck() {
    print("=== VOICE CALL HEALTH CHECK ===");
    print("Health Check - _isLoadingUserData: $_isLoadingUserData");
    print("Health Check - _fetchedParticipant: $_fetchedParticipant");
    print("Health Check - _ratePerMinute: $_ratePerMinute");
    print("Health Check - _timerStarted: $_timerStarted");
    print("Health Check - _autoPaymentEnabled: $_autoPaymentEnabled");
    print(
        "Health Check - _autoPaymentTimer active: ${_autoPaymentTimer?.isActive ?? false}");
    print("Health Check - _callEnded: $_callEnded");
    print("Health Check - _remoteUid: $_remoteUid");

    // If call ended, stop health check
    if (_callEnded) {
      print("Health Check - Call ended, stopping health check");
      _healthCheckTimer?.cancel();
      return;
    }

    // Check 1: If user data is still loading after reasonable time, retry fetching
    if (_isLoadingUserData) {
      print("Health Check - User data still loading, retrying fetch");
      _fetchParticipantData();
      return;
    }

    // Check 2: If user data loaded but no rate, try direct rate extraction
    if (_fetchedParticipant == null && !_isLoadingUserData) {
      print(
          "Health Check - No fetched participant but not loading, retrying fetch");
      _fetchParticipantData();
      return;
    }

    // Check 3: If we have participant data but rate is still 0, recalculate
    if (_fetchedParticipant != null && _ratePerMinute <= 0) {
      final newRate = _fetchedParticipant?.earnings?.live?.toDouble() ?? 0.0;
      print("Health Check - Recalculating rate: $newRate");
      if (newRate > 0) {
        setState(() {
          _ratePerMinute = newRate;
        });
      }
    }

    // Check 4: If timer started and connected but auto-payment not enabled for paid calls
    if (_timerStarted &&
        !widget.isTrial &&
        _remoteUid != null &&
        !_autoPaymentEnabled &&
        _ratePerMinute > 0) {
      print(
          "Health Check - Auto-payment should be enabled but isn't, starting");
      _startAutoPaymentTimer();
    }

    // Check 5: If auto-payment should be running but timer is not active
    if (!widget.isTrial &&
        _autoPaymentEnabled &&
        _ratePerMinute > 0 &&
        (_autoPaymentTimer == null || !_autoPaymentTimer!.isActive)) {
      print("Health Check - Auto-payment timer not active, restarting");
      _startAutoPaymentTimer();
    }

    // Check 6: If we're in a paid call but timers not started and both users connected
    if (!widget.isTrial &&
        !_timerStarted &&
        _localUserJoined &&
        _remoteUid != null) {
      print(
          "Health Check - Paid call connected but timers not started, starting");
      _startTimers();
    }

    print("=== END VOICE CALL HEALTH CHECK ===");
  }

  // Modified _startAutoPaymentTimer with better error handling and logging
  void _startAutoPaymentTimer() {
    print("=== VOICE CALL AUTO PAYMENT TIMER START ===");
    print("Voice call _isLoadingUserData: $_isLoadingUserData");
    print("Voice call _ratePerMinute: $_ratePerMinute");
    print("Voice call _fetchedParticipant: $_fetchedParticipant");
    print("Voice call isIncomingCall: ${widget.isIncomingCall}");

    // Cancel existing timer if any
    _autoPaymentTimer?.cancel();

    // Wait for user data to be loaded
    if (_isLoadingUserData) {
      print(
          "Voice call User data still loading, retrying auto-payment setup in 2 seconds");
      Timer(const Duration(seconds: 2), _startAutoPaymentTimer);
      return;
    }

    // Use the fetched rate with multiple fallbacks
    double actualRatePerMinute = 0.0;

    // Try fetched participant first
    if (_fetchedParticipant?.earnings?.live != null) {
      actualRatePerMinute = _fetchedParticipant!.earnings!.live!.toDouble();
      print(
          "Voice call Got rate from fetched participant: $actualRatePerMinute");
    }
    // Fallback to stored rate
    else if (_ratePerMinute > 0) {
      actualRatePerMinute = _ratePerMinute;
      print("Voice call Using stored rate: $actualRatePerMinute");
    }
    // Last resort: try original participant
    else if (widget.participant.earnings?.live != null) {
      actualRatePerMinute = widget.participant.earnings!.live!.toDouble();
      print("Voice call Using original participant rate: $actualRatePerMinute");
    }

    print("=== VOICE CALL AUTO PAYMENT TIMER SETUP ===");
    print("Voice call Final rate per minute: $actualRatePerMinute");

    if (actualRatePerMinute <= 0) {
      print(
          "Voice call Rate per minute is 0 or negative, skipping auto-payment setup");
      return;
    }

    print(
        "Voice call Setting up auto-payment with rate: ₹$actualRatePerMinute/min");

    _autoPaymentEnabled = true;
    const paymentIntervalSeconds = 60;

    _autoPaymentTimer = Timer.periodic(
        const Duration(seconds: paymentIntervalSeconds), (timer) async {
      if (!_autoPaymentEnabled) return;

      try {
        final cost = actualRatePerMinute;

        // Always refresh wallet balance
        await _chatController.fetchWalletBalance();

        if (widget.isIncomingCall) {
          // For incoming calls: Just refresh wallet balance, no payment deduction
          print(
              "Voice call Incoming - wallet balance refreshed, no payment deduction");
          // Show earning animation for incoming calls
          _showPaymentNotification(cost);
          print(
              "Voice call Incoming call - showing earning notification: +₹$cost");
        } else {
          // For outgoing calls: Check balance and deduct money
          if (_chatController.userWalletBalance.value < cost) {
            _autoPaymentTimer?.cancel();
            _showInsufficientBalanceDialog();
            return;
          }

          // Deduct money for outgoing calls
          final success = await _chatController.sendCallMoney(
            widget.participant.sId!,
            cost,
          );

          if (!success) {
            throw Exception('Payment failed');
          } else {
            // Show payment animation when successful
            _showPaymentNotification(cost);
            print("Voice call Outgoing call - payment successful: -₹$cost");
          }
        }
      } catch (e) {
        print('Voice call Auto-payment error: $e');
        _autoPaymentTimer?.cancel();
        if (!widget.isIncomingCall) {
          // Only show payment error for outgoing calls
          _showPaymentErrorDialog();
        }
      }
    });

    print("Voice call Auto-payment timer started successfully");
  }

  // Add method to show animated payment notification
  void _showPaymentNotification(double amount) {
    setState(() {
      _lastPaymentAmount = '₹${amount.toStringAsFixed(0)}';
      _showPaymentAnimation = true;
    });

    _paymentAnimationController.reset();
    _paymentAnimationController.forward().then((_) {
      setState(() {
        _showPaymentAnimation = false;
      });
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

  void _endCall() {
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

    FlutterCallkitIncoming.endCall(widget.meetingId);

    // if (widget.onSessionEnd != null) {
    //   widget.onSessionEnd!();
    // }
    Get.off(() => AddReviewScreen(
          userId: widget.participant.sId ?? '',
        ));
    // Get.back();
  }

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
    await _durationService.initialize(widget.participant.sId!);
  }

  // Fetch participant data for outgoing calls, own data for incoming calls
  Future<void> _fetchParticipantData() async {
    try {
      print("=== FETCHING PARTICIPANT DATA (VOICE) ===");

      String userId;
      if (widget.isIncomingCall) {
        // For incoming calls, fetch own profile data
        final currentUserId = await SharedPrefs.getUserIdSharedPreference();
        userId = currentUserId ?? '';
        print("Incoming call - fetching own profile: $userId");
      } else {
        // For outgoing calls, fetch participant profile data
        userId = widget.participant.sId ?? '';
        print("Outgoing call - fetching participant profile: $userId");
      }

      if (userId.isEmpty) {
        print("Voice call - No user ID available");
        setState(() {
          _isLoadingUserData = false;
        });
        return;
      }

      final response = await ApiService.getUserById(userId);
      print("Voice call API response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body) as Map<String, dynamic>;
        print("Voice call Full response body: $responseBody");

        if (responseBody['success'] == true && responseBody['user'] != null) {
          final userData = responseBody['user'] as Map<String, dynamic>;
          print("Voice call User data: $userData");
          print("Voice call Earnings from response: ${userData['earnings']}");

          try {
            _fetchedParticipant = User.fromJson(userData);
            print("Voice call User.fromJson successful");
          } catch (e) {
            print("Voice call User.fromJson failed: $e");
            _fetchedParticipant = null;
          }

          _ratePerMinute = _fetchedParticipant?.earnings?.live?.toDouble() ?? 0;

          print(
              "Voice call Fetched participant earnings: ${_fetchedParticipant?.earnings}");
          print("Voice call Fetched rate per minute: $_ratePerMinute");

          // Also try direct access to earnings
          final earningsData = userData['earnings'] as Map<String, dynamic>?;
          if (earningsData != null) {
            final liveRate = earningsData['live'];
            print(
                "Voice call Direct live rate access: $liveRate (type: ${liveRate.runtimeType})");
            if (liveRate != null) {
              _ratePerMinute = (liveRate as num).toDouble();
              print(
                  "Voice call Updated rate per minute from direct access: $_ratePerMinute");
            }
          } else {
            print("Voice call Earnings data is null in response");
          }

          setState(() {
            _isLoadingUserData = false;
          });

          print("Voice call Data loading completed successfully");
        } else {
          print("Voice call API response success=false or user=null");
          print("Voice call Success: ${responseBody['success']}");
          print("Voice call User: ${responseBody['user']}");
          _ratePerMinute = 0;
          setState(() {
            _isLoadingUserData = false;
          });
        }
      } else {
        print("Voice call Failed to fetch user data: ${response.statusCode}");
        print("Voice call Response body: ${response.body}");
        _ratePerMinute = 0;
        setState(() {
          _isLoadingUserData = false;
        });
      }
    } catch (e) {
      print("Voice call Error fetching participant data: $e");
      print("Voice call Error stack trace: ${StackTrace.current}");
      _ratePerMinute = 0;
      setState(() {
        _isLoadingUserData = false;
      });
    }
    print("=== END FETCHING PARTICIPANT DATA (VOICE) ===");
    print("Voice call Final loading state: $_isLoadingUserData");
    print("Voice call Final rate: $_ratePerMinute");
  }

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

    _healthCheckTimer?.cancel();
    _paymentAnimationController.dispose();
    CallStatusController.to.userLeftCallScreen();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            _callEnded
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
                        padding: const EdgeInsets.symmetric(
                            vertical: 5, horizontal: 12),
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
                                color:
                                    _isConnecting ? Colors.amber : Colors.green,
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
                      ),
                    ],
                  ),

            // Animated payment notification overlay
            if (_showPaymentAnimation)
              Positioned(
                top: MediaQuery.of(context).size.height * 0.4,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _paymentAnimationController,
                  builder: (context, child) {
                    return SlideTransition(
                      position: _paymentSlideAnimation,
                      child: FadeTransition(
                        opacity: _paymentFadeAnimation,
                        child: Container(
                          alignment: Alignment.center,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: widget.isIncomingCall
                                  ? Colors.green.withOpacity(0.9)
                                  : Colors.red.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  widget.isIncomingCall
                                      ? Icons.add
                                      : Icons.remove,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${widget.isIncomingCall ? '+' : '-'}$_lastPaymentAmount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
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
        child: Text(
          _isLoadingUserData ? 'Loading user data...' : 'Connecting...',
          style: const TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    // Use fetched participant data for rate display
    final perMinuteRate =
        _fetchedParticipant?.earnings?.live?.toDouble() ?? 0.0;

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

          // Rate display with +/- sign based on call direction
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              widget.isTrial
                  ? 'Free Trial'
                  : _isLoadingUserData
                      ? 'Loading rate...'
                      : perMinuteRate > 0
                          ? '${widget.isIncomingCall ? '+' : '-'}₹${perMinuteRate.toStringAsFixed(0)}/min'
                          : 'Rate: N/A',
              style: TextStyle(
                color: widget.isTrial
                    ? Colors.grey[400]
                    : perMinuteRate > 0
                        ? (widget.isIncomingCall
                            ? Colors.green[400]
                            : Colors.red[400])
                        : Colors.grey[400],
                fontSize: 13,
                fontWeight: FontWeight.w500,
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
              // Get.offAllNamed('/');
              Get.off(() => AddReviewScreen(
                    userId: widget.participant.sId ?? '',
                  ));
              // Get.back();

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
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.home, size: 20),
                SizedBox(width: 8),
                Text(
                  'Return to Home',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
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
}
