import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/features/calls/controllers/call_controller.dart';
import 'package:iftook/features/calls/presentation/screens/video_call_screen.dart';
import 'package:iftook/features/profile/data/models/user.dart';
import 'package:iftook/helpers/app_colors.dart';

class VideoCallLoadingScreen extends StatefulWidget {
  final User participant;
  final String type;
  final DateTime scheduleTime;
  final bool isInstatalk;
  final bool isTrial;
  final int instaTalkDuration;
  final Function? onSessionEnd;
  final String? meetingId;
  final String? token;
  final String? channel;
  final bool isFriend;

  const VideoCallLoadingScreen({
    Key? key,
    required this.participant,
    required this.type,
    required this.scheduleTime,
    this.isInstatalk = false,
    this.isTrial = false,
    this.instaTalkDuration = 30,
    this.onSessionEnd,
    this.meetingId,
    this.token,
    this.channel,
    this.isFriend = false,
  }) : super(key: key);

  @override
  State<VideoCallLoadingScreen> createState() => _VideoCallLoadingScreenState();
}

class _VideoCallLoadingScreenState extends State<VideoCallLoadingScreen> {
  late final CallController _callController;
  bool _isSpeakerOn = true;
  bool _isMuted = false;
  bool _isCameraOff = false;

  @override
  void initState() {
    super.initState();
    // Initialize CallController if not already initialized
    _callController = Get.put(CallController());

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
          print('Is InstaTalk: ${widget.isInstatalk}');
          print('Is Trial: ${widget.isTrial}');
          print('InstaTalk Duration: ${widget.instaTalkDuration}');

          // Start call rejection listener for outgoing calls
          _callController.startCallRejectionListener(widget.meetingId!);

          // Navigate directly to call screen after a short delay
          // to give the rejection listener time to initialize
          Future.delayed(Duration(milliseconds: 500), () {
            // Don't navigate if component is unmounted or call was rejected
            if (!mounted || _callController.wasCallRejected.value) return;

            print('Navigating to VideoCallScreen with:');
            print('Is InstaTalk: ${widget.isInstatalk}');
            print('Is Trial: ${widget.isTrial}');
            print('InstaTalk Duration: ${widget.instaTalkDuration}');

            // Navigate to call screen only if call hasn't been rejected
            Get.to(
                () => VideoCallScreen(
                      meetingId: widget.meetingId!,
                      channel: widget.channel!,
                      token: widget.token!,
                      initialTimer: widget.instaTalkDuration,
                      isTrial: widget.isTrial,
                      isInstatalk: widget.isInstatalk,
                      participant: widget.participant,
                      onSessionEnd: widget.onSessionEnd,
                    ),
                arguments: {'participant': widget.participant});
          });
          return;
        }

        print('Initializing video call...');
        print('Participant ID: ${widget.participant.sId}');
        print('Call Type: ${widget.type}');
        print('Schedule Time: ${widget.scheduleTime}');
        print('Is InstaTalk: ${widget.isInstatalk}');
        print('Is Trial: ${widget.isTrial}');
        print('InstaTalk Duration: ${widget.instaTalkDuration}');

        if (widget.isInstatalk) {
          _callController.initiateInstaTalkCall(
            widget.participant.sId.toString(),
            widget.type,
            widget.participant.name ?? 'Unknown',
            isTrial: widget.isTrial,
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
  }

  @override
  void dispose() {
    if (widget.meetingId != null) {
      _callController.stopCallRejectionListener();
    }
    super.dispose();
  }

  void _endCall() {
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

  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
  }

  void _toggleCamera() {
    setState(() {
      _isCameraOff = !_isCameraOff;
    });
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
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    color: Colors.white,
                    backgroundColor: _isMuted ? Colors.red : Colors.grey[800]!,
                    onTap: _toggleMute,
                  ),
                  _buildCallButton(
                    icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                    color: Colors.white,
                    backgroundColor:
                        _isCameraOff ? Colors.red : Colors.grey[800]!,
                    onTap: _toggleCamera,
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
                    icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                    color: Colors.white,
                    backgroundColor:
                        _isSpeakerOn ? Colors.grey[800]! : Colors.red,
                    onTap: _toggleSpeaker,
                  ),
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
            Icons.videocam_off,
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
