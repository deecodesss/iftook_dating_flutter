import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/features/calls/controllers/call_controller.dart';
import 'package:iftook/features/profile/data/models/user.dart';
import 'dart:async';

import '../../../../helpers/app_colors.dart';
import '../../../wallet/controllers/wallet_controller.dart';

class VideoCallLoadingScreen extends StatefulWidget {
  final User participant;
  final String type;
  final DateTime scheduleTime;
  final bool isInstaTalk;
  final int instaTalkDuration;
  final Function? onSessionEnd;

  const VideoCallLoadingScreen({
    Key? key,
    required this.participant,
    required this.type,
    required this.scheduleTime,
    this.isInstaTalk = false,
    this.instaTalkDuration = 30,
    this.onSessionEnd,
  }) : super(key: key);

  @override
  State<VideoCallLoadingScreen> createState() => _VideoCallLoadingScreenState();
}

class _VideoCallLoadingScreenState extends State<VideoCallLoadingScreen> {
  final CallController _callController = Get.put(CallController());

  // Insta Talk timer variables
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

    if (widget.isInstaTalk) {
      final callRate = widget.participant.earnings?.videoRate ?? 0;
      if (!_callController.isFreeCall(callRate)) {
        _startupDelayTimer = Timer(Duration(seconds: 5), () {
          if (mounted) {
            _startTimer();
          }
        });
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    });
  }

  void _showContinueCallPrompt() {
    _showingPaymentPrompt = true;

    if (widget.onSessionEnd != null) {
      widget.onSessionEnd!();
      return;
    }

    final prompt = widget.isInstaTalk
        ? '30-second free video call'
        : '30-minute video call session';

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
              'Rate: ₹${widget.participant.earnings?.videoRate ?? 450} for 30 minutes',
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
      final callRate = widget.participant.earnings?.videoRate ?? 450.0;
      final success = await _callController.purchaseCallSession(
        widget.participant.sId!,
        callRate,
        'video',
        minutes: 30,
      );

      if (success) {
        setState(() {
          _instaTalkExpired = false;
          _timerStarted = false;
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
      Get.snackbar(
        'Error',
        'Failed to purchase call session',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _endCall() {
    try {
      // _callController.endCall();
    } catch (e) {
      print('Error ending call: $e');
    }
    Get.back();
  }

  @override
  void dispose() {
    _instaTimer?.cancel();
    _startupDelayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const SizedBox(height: 40),
                CircleAvatar(
                  radius: 70,
                  backgroundImage: widget.participant.photos?.isNotEmpty == true
                      ? NetworkImage(widget.participant.photos!.first)
                      : null,
                  child: widget.participant.photos?.isEmpty ?? true
                      ? const Icon(Icons.person,
                          size: 70, color: Colors.white54)
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
                      'Connecting...',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatTimer(_remainingSeconds),
                      style: const TextStyle(
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
                      icon: Icons.mic_off,
                      color: Colors.white,
                      backgroundColor: Colors.grey[800]!,
                    ),
                    _buildCallButton(
                      icon: Icons.videocam_off,
                      color: Colors.white,
                      backgroundColor: Colors.grey[800]!,
                    ),
                    _buildCallButton(
                      icon: Icons.call_end,
                      color: Colors.white,
                      backgroundColor: Colors.red,
                      size: 65,
                      onTap: _endCall,
                    ),
                    _buildCallButton(
                      icon: Icons.switch_camera,
                      color: Colors.white,
                      backgroundColor: Colors.grey[800]!,
                    ),
                    _buildCallButton(
                      icon: Icons.volume_up,
                      color: Colors.white,
                      backgroundColor: Colors.grey[800]!,
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),

          // Add Insta Talk timer if active
          if (widget.isInstaTalk && _timerStarted && !_instaTalkExpired)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: Colors.amber.withOpacity(0.2),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      const Icon(Icons.timer, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text(
                        'Free trial: $_remainingSeconds seconds remaining',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      LinearProgressIndicator(
                        value: _remainingSeconds / widget.instaTalkDuration,
                        backgroundColor: Colors.grey[800],
                        color: Colors.amber,
                        minHeight: 5,
                        // constraints: const BoxConstraints(maxWidth: 100),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Expired notice
          if (widget.isInstaTalk && _instaTalkExpired)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.redAccent.withOpacity(0.3),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.white),
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
