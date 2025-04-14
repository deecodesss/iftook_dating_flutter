import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/features/calls/controllers/call_controller.dart';
import 'package:iftook/features/profile/data/models/user.dart';

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

  Timer? _startupDelayTimer;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        print('Initializing video call...');
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
        print('Error initializing video call: $e');
        Get.snackbar(
          'Error',
          'Failed to initialize video call: ${e.toString()}',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    });

    // Add timer initialization if needed
    if (widget.isInstaTalk) {
      final callRate = widget.participant.earnings?.videoRate ?? 0;
      if (!_callController.isFreeCall(callRate)) {
        _startupDelayTimer = Timer(Duration(seconds: 5), () {
          if (mounted) {
            // _startTimer();
          }
        });
      }
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
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
