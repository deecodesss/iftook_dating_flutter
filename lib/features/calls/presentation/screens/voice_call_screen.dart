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

  RxBool isConnecting = true.obs;
  RxString connectionStatus = 'Initializing...'.obs;

  // Timer variables
  Timer? _sessionTimer;
  Timer? _instaTimer;
  Timer? _startupDelayTimer;
  int _remainingSeconds = 0;
  int _timeLeft = 0; // Main call timer
  bool _sessionExpired = false;
  bool _showingPaymentPrompt = false;
  bool _timerStarted = false;
  bool _hasRenewedSession = false;
  bool _isRenewing = false;

  late final CallController _callController;
  late final CallDurationService _durationService;
  Timer? _timer;
  bool _isSpeakerOn = true;
  bool _isCallConnected = false;
  String _connectionStatus = 'Connecting...';

  @override
  void initState() {
    super.initState();
    _callController = Get.put(CallController());
    _durationService = Get.put(CallDurationService());
    _initializeDurationService();

    print(
        "Initializing Voice Call with token: ${widget.token}, channel: ${widget.channel}");
    _remainingSeconds = _durationService.getInitialTimerDuration(
      widget.isInstaTalk,
      widget.initialTimer,
    );
    _initializeTimer();
    _initializeAgora();
    _checkPermissions();
    _setupCallController();
  }

  Future<void> _checkPermissions() async {
    await Permission.microphone.request();
  }

  void _setupCallController() {
    // Setup any additional call controller logic here
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

  // Timer management methods
  void _startTimer() {
    if (widget.isInstaTalk) {
      _startInstaTimer();
    } else {
      _startRegularTimer();
    }
  }

  void _startInstaTimer() {
    setState(() {
      _remainingSeconds = widget.instaTalkDuration;
      _timerStarted = true;
    });

    _instaTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _instaTimer?.cancel();
          if (!_showingPaymentPrompt && !_sessionExpired) {
            _sessionExpired = true;
            _showContinueCallPrompt();
          }
        }
      });
    });
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

  // Main call timer
  void _startCallTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _sessionTimer?.cancel();
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

          // Reset and restart timers
          _timeLeft = 30 * 60; // 30 minutes
          _startCallTimer();

          if (widget.isInstaTalk) {
            _remainingSeconds = 0; // No need for InstaTalk timer after purchase
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

  // Toggle microphone mute
  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _engine.muteLocalAudioStream(_isMuted);
  }

  // End the call
  void _endCall() {
    _engine.leaveChannel();
    _engine.release();
    _instaTimer?.cancel();
    _sessionTimer?.cancel();
    _startupDelayTimer?.cancel();

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
    _engine.leaveChannel();
    _engine.release();
    _instaTimer?.cancel();
    _sessionTimer?.cancel();
    _startupDelayTimer?.cancel();
    _durationService.reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFF1A1A1A),
          body: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Main timer display - only show if not friends and not trial
                if (_durationService.shouldTimeCall(widget.isTrial))
                  Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    color: Colors.black.withOpacity(0.5),
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

                // Caller details section
                Column(
                  children: [
                    // Profile photo
                    CircleAvatar(
                      radius: 70,
                      backgroundImage:
                          widget.participant?.photos?.isNotEmpty == true
                              ? NetworkImage(widget.participant!.photos!.first)
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
                      icon: Icons.volume_up,
                      color: Colors.white,
                      backgroundColor: Colors.grey[800]!,
                      onTap: () {}, // Speaker toggle could be implemented here
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
