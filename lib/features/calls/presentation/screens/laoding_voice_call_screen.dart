import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
  final int instaTalkDuration;

  const VoiceCallLoadingScreen({
    Key? key,
    required this.participant,
    required this.type,
    required this.scheduleTime,
    this.isInstaTalk = false,
    this.instaTalkDuration = 30,
  }) : super(key: key);

  @override
  State<VoiceCallLoadingScreen> createState() => _VoiceCallLoadingScreenState();
}

class _VoiceCallLoadingScreenState extends State<VoiceCallLoadingScreen> {
  final CallController _callController = Get.put(CallController());

  // Insta Talk timer variables
  Timer? _instaTimer;
  Timer? _startupDelayTimer;
  int _remainingSeconds = 0;
  bool _instaTalkExpired = false;
  bool _showingPaymentPrompt = false;
  bool _timerStarted = false;

  @override
  void initState() {
    super.initState();
    _callController.initiateCall(
        widget.participant.sId.toString(), widget.type, widget.scheduleTime);

    // If this is an Insta Talk call, start timer after a delay
    if (widget.isInstaTalk) {
      _startupDelayTimer = Timer(Duration(seconds: 5), () {
        if (mounted) {
          _startInstaTimer();
        }
      });
    }
  }

  void _startInstaTimer() {
    if (!widget.isInstaTalk || _timerStarted) return;

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
          if (!_showingPaymentPrompt && !_instaTalkExpired) {
            _instaTalkExpired = true;
            _showContinueCallPrompt();
          }
        }
      });
    });
  }

  void _showContinueCallPrompt() {
    _showingPaymentPrompt = true;

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
              'Your 30-second free call with ${widget.participant.name ?? "User"} has ended.',
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

  void _purchaseCall() {
    try {
      final callRate = widget.participant.earnings?.voiceRate ?? 300.0;
      final walletController = Get.find<WalletController>();

      if (!walletController.hasEnoughBalance(callRate)) {
        Get.snackbar(
          'Insufficient Balance',
          'Please add funds to your wallet to continue this call.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
          mainButton: TextButton(
            onPressed: () => Get.toNamed('/wallet'),
            child:
                const Text('Add Funds', style: TextStyle(color: Colors.white)),
          ),
        );
        return;
      }

      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      walletController
          .sendTip(widget.participant.sId!, callRate)
          .then((success) {
        Get.back();

        if (success) {
          setState(() {
            _instaTalkExpired = false;
          });

          Get.snackbar(
            'Success',
            'Call session purchased. You can continue for 30 minutes.',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
        } else {
          Get.snackbar(
            'Error',
            'Failed to purchase call session. The call will end.',
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );

          _endCall();
        }
      });
    } catch (e) {
      Get.snackbar(
        'Error',
        'An error occurred: $e',
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
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Insta Talk timer
            if (widget.isInstaTalk && _timerStarted && !_instaTalkExpired)
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: Colors.amber.withOpacity(0.2),
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

            // Expired notice
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
                  'Connecting...',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '00:00',
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
                  icon: Icons.mic_off,
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
