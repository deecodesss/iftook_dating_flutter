import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/features/calls/presentation/screens/voice_call_screen.dart';
import 'dart:async';

import '../../../../helpers/app_colors.dart';
import '../../../profile/data/models/user.dart';
import '../../controllers/call_controller.dart';
import '../../../wallet/controllers/wallet_controller.dart';

class VoiceCallLoadingScreen extends StatefulWidget {
  final User participant;
  final String type;
  final DateTime scheduleTime;
  final bool isInstaTalk;
  final bool isTrial;
  final int instaTalkDuration;
  final Function? onSessionEnd;
  final String? meetingId;
  final String? token;
  final String? channel;

  const VoiceCallLoadingScreen({
    Key? key,
    required this.participant,
    required this.type,
    required this.scheduleTime,
    this.isInstaTalk = false,
    this.isTrial = false,
    this.instaTalkDuration = 30,
    this.onSessionEnd,
    this.meetingId,
    this.token,
    this.channel,
  }) : super(key: key);

  @override
  State<VoiceCallLoadingScreen> createState() => _VoiceCallLoadingScreenState();
}

class _VoiceCallLoadingScreenState extends State<VoiceCallLoadingScreen> {
  late final CallController _callController;

  Timer? _instaTimer;
  Timer? _startupDelayTimer;
  int _remainingSeconds = 0;
  bool _instaTalkExpired = false;
  bool _showingPaymentPrompt = false;
  bool _timerStarted = false;

  void _startTimer() {
    if (widget.isInstaTalk) {
      _startInstaTimer();
    } else {
      _startRegularTimer();
    }
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

  void _startInstaTimer() {
    setState(() {
      _remainingSeconds = 30; // 30 seconds
      _timerStarted = true;
    });

    _instaTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _instaTimer?.cancel();
          if (!_showingPaymentPrompt && !_instaTalkExpired) {
            _instaTalkExpired = true;
            _showContinueCallPrompt();
          }
        }
      });
    });
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

  @override
  void initState() {
    super.initState();
    // Initialize CallController if not already initialized
    _callController = Get.put(CallController());

    if (widget.isInstaTalk) {
      final callRate = widget.participant.earnings?.voiceRate ?? 0;
      if (!_callController.isFreeCall(callRate)) {
        _startupDelayTimer = Timer(Duration(seconds: 5), () {
          if (mounted) {
            _startTimer();
          }
        });
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // If we already have meeting details, skip API call
        if (widget.meetingId != null &&
            widget.token != null &&
            widget.channel != null) {
          print('Using provided meeting details:');
          print('Meeting ID: ${widget.meetingId}');
          print('Channel: ${widget.channel}');
          print('Token: ${widget.token}');

          // Start call rejection listener for outgoing calls
          _callController.startCallRejectionListener(widget.meetingId!);

          // Navigate directly to call screen after a short delay
          // to give the rejection listener time to initialize
          Future.delayed(Duration(milliseconds: 500), () {
            // Don't navigate if component is unmounted or call was rejected
            if (!mounted || _callController.wasCallRejected.value) return;

            // Navigate to call screen only if call hasn't been rejected
            Get.to(
                () => VoiceCallScreen(
                      meetingId: widget.meetingId!,
                      channel: widget.channel!,
                      token: widget.token!,
                      initialTimer: widget.instaTalkDuration,
                      isTrial: widget.isTrial,
                      isInstaTalk: widget.isInstaTalk,
                      participant: widget.participant,
                    ),
                arguments: {'participant': widget.participant});
          });
          return;
        }

        // Otherwise proceed with normal initialization
        print('Initializing voice call...');
        print('Participant ID: ${widget.participant.sId}');
        print('Call Type: ${widget.type}');
        print('Schedule Time: ${widget.scheduleTime}');

        if (widget.isInstaTalk) {
          _callController.initiateInstaTalkCall(
            widget.participant.sId.toString(),
            widget.type,
          );
        } else {
          _callController.initiateMeetingCall(
            widget.participant.sId.toString(),
            widget.type,
            widget.scheduleTime,
          );
        }
      } catch (e) {
        print('Error initializing voice call: $e');
        Get.snackbar(
          'Error',
          'Failed to initialize voice call: ${e.toString()}',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    });
  }

  void _showContinueCallPrompt() {
    _showingPaymentPrompt = true;

    if (widget.onSessionEnd != null) {
      widget.onSessionEnd!();
      return;
    }

    final prompt = widget.isInstaTalk
        ? '30-second free voice call'
        : '30-minute voice call session';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Free Trial Ended',
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
          _instaTalkExpired = false;
          _timerStarted = false;
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
      Get.snackbar(
        'Error',
        'Failed to purchase call session',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _endCall() {
    // Cancel timers
    _instaTimer?.cancel();
    _startupDelayTimer?.cancel();

    try {
      // Explicitly reject the call when user cancels
      if (widget.meetingId != null) {
        _callController.rejectCall();
      }
    } catch (e) {
      print('Error ending call: $e');
    }

    Get.back();
  }

  @override
  void dispose() {
    _instaTimer?.cancel();
    _startupDelayTimer?.cancel();
    if (widget.meetingId != null) {
      _callController.stopCallRejectionListener();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: Obx(() {
          // Show rejection UI if call has been rejected
          if (_callController.wasCallRejected.value) {
            return _buildRejectionUI();
          }

          // Otherwise show regular loading UI
          return Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (_timerStarted && !_instaTalkExpired)
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  color: widget.isInstaTalk
                      ? Colors.amber.withOpacity(0.2)
                      : Colors.blue.withOpacity(0.2),
                  child: Row(
                    children: [
                      Icon(Icons.timer,
                          color:
                              widget.isInstaTalk ? Colors.amber : Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        widget.isInstaTalk
                            ? 'Free trial: ${_formatTimer(_remainingSeconds)}'
                            : _formatTimer(_remainingSeconds),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      LinearProgressIndicator(
                        value: _remainingSeconds / widget.instaTalkDuration,
                        backgroundColor: Colors.grey[800],
                        color: widget.isInstaTalk ? Colors.amber : Colors.blue,
                        minHeight: 5,
                      ),
                    ],
                  ),
                ),
              if (widget.isInstaTalk && _instaTalkExpired)
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.redAccent.withOpacity(0.2),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.redAccent),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Free trial ended. Purchase to continue.',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
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
              CircleAvatar(
                radius: 70,
                backgroundImage: widget.participant.photos?.isNotEmpty == true
                    ? NetworkImage(widget.participant.photos!.first)
                    : null,
                child: widget.participant.photos?.isEmpty ?? true
                    ? const Icon(Icons.person, size: 70, color: Colors.white54)
                    : null,
              ),
              Column(
                children: [
                  Text(
                    widget.participant.name ?? 'User',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Calling...',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // const Text(
                  //   '00:00',
                  //   style: TextStyle(
                  //     fontSize: 16,
                  //     color: Colors.grey,
                  //   ),
                  // ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // _buildCallButton(
                  //   icon: Icons.mic_off,
                  //   color: Colors.white,
                  //   backgroundColor: Colors.grey[800]!,
                  // ),
                  _buildCallButton(
                    icon: Icons.call_end,
                    color: Colors.white,
                    backgroundColor: Colors.red,
                    size: 65,
                    onTap: _endCall,
                  ),
                  // _buildCallButton(
                  //   icon: Icons.volume_up,
                  //   color: Colors.white,
                  //   backgroundColor: Colors.grey[800]!,
                  // ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          );
        }),
      ),
    );
  }

  // New method to build UI when call is rejected
  Widget _buildRejectionUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: widget.participant.photos?.isNotEmpty == true
                ? NetworkImage(widget.participant.photos!.first)
                : null,
            child: widget.participant.photos?.isEmpty ?? true
                ? const Icon(Icons.person, size: 50, color: Colors.white54)
                : null,
          ),
          const SizedBox(height: 30),
          const Icon(
            Icons.call_end,
            color: Colors.red,
            size: 50,
          ),
          const SizedBox(height: 20),
          Text(
            "${widget.participant.name} declined the call",
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              minimumSize: const Size(200, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            onPressed: () => Get.back(),
            child: const Text(
              "Go Back",
              style: TextStyle(fontSize: 18),
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
    double size = 50,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
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
