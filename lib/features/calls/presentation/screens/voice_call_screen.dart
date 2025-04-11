import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/features/calls/controllers/call_controller.dart';
import 'package:iftook/features/profile/data/models/user.dart';
import 'package:iftook/features/profile/presentation/screens/add_review_screen.dart';
import 'package:iftook/helpers/app_colors.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceCallScreen extends StatefulWidget {
  final String meetingId;
  final String token;
  final String channel;
  final Function? onSessionEnd;
  final User? participant;
  final bool isInstaTalk;
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

  final CallController _callController = Get.put(CallController());

  @override
  void initState() {
    super.initState();
    print(
        "Initializing Voice Call with token: ${widget.token}, channel: ${widget.channel}");
    _initAgora();

    // Initialize timer with the provided initialTimer value
    _timeLeft = widget.initialTimer;
    _startCallTimer();

    // Start InstaTalk timer if needed
    if (widget.isInstaTalk && widget.participant != null) {
      final callRate = widget.participant!.earnings?.voiceRate ?? 0;
      if (!_callController.isFreeCall(callRate)) {
        _startupDelayTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) {
            _startTimer();
          }
        });
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
  Future<void> _initAgora() async {
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
                // Main timer display
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

                // InstaTalk timer if active
                if (widget.isInstaTalk && _timerStarted && !_sessionExpired)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    color: Colors.amber.withOpacity(0.2),
                    child: Row(
                      children: [
                        const Icon(Icons.timer, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Free trial: ${_formatTimer(_remainingSeconds)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 100,
                          child: LinearProgressIndicator(
                            value: _remainingSeconds / widget.instaTalkDuration,
                            backgroundColor: Colors.grey[800],
                            color: Colors.amber,
                            minHeight: 5,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Expired notice
                if (widget.isInstaTalk && _sessionExpired)
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.redAccent.withOpacity(0.3),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber, color: Colors.white),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Free trial ended. Purchase to continue.',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
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

                const SizedBox(height: 40),
                const CircleAvatar(
                  radius: 70,
                  backgroundImage: NetworkImage('https://i.pravatar.cc/300'),
                ),
                Column(
                  children: [
                    Obx(() => Text(
                          connectionStatus.value,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        )),
                    const SizedBox(height: 8),
                    if (_remoteUid != null)
                      const Text(
                        'Call in progress',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
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
