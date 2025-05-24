import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/features/calls/controllers/call_controller.dart';
import 'package:iftook/features/calls/presentation/screens/call_screen.dart';
import 'package:iftook/features/calls/presentation/screens/video_call_screen.dart';
import 'package:iftook/features/calls/services/call_notification_service.dart';
import 'package:iftook/features/profile/data/models/user.dart';
import 'package:iftook/helpers/app_colors.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

/// A screen that shows an incoming call when the app is in the foreground
///
/// This provides a more attractive and feature-rich UI for incoming calls
/// compared to the snackbar or CallKit UI.
class IncomingCallScreen extends StatefulWidget {
  final String callerName;
  final String callerImage;
  final bool isVideo;
  final String meetingId;
  final String channelName;
  final String token;
  final String callerRating;
  final String callRate;
  final String callDuration;
  final String callerId;
  final bool isInstaTalk;
  final String meetingType;

  const IncomingCallScreen({
    Key? key,
    required this.callerName,
    required this.callerImage,
    required this.isVideo,
    required this.meetingId,
    required this.channelName,
    required this.token,
    this.callerRating = "0",
    this.callRate = "0",
    this.callDuration = "30",
    this.callerId = "",
    this.isInstaTalk = false,
    this.meetingType = "regularMeeting",
  }) : super(key: key);

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _showControls = true;
  Timer? _callTimer;
  int _callTimeElapsed = 0;
  final CallController _callController = Get.find<CallController>();

  @override
  void initState() {
    super.initState();

    // Start animation for the avatar
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Start countdown timer
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _callTimeElapsed++;
        // Auto-reject after 45 seconds
        if (_callTimeElapsed >= 45) {
          _rejectCall();
        }
      });
    });

    // Play ringtone
    _playRingtone();

    // Set up controller state for this incoming call
    _callController.setupIncomingCall(
        widget.meetingId, widget.channelName, widget.token);
    _callController.updateCallState(CallState.incoming);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _callTimer?.cancel();
    FlutterRingtonePlayer().stop();
    super.dispose();
  }

  void _playRingtone() async {
    try {
      await FlutterRingtonePlayer().play(
        android: AndroidSounds.ringtone,
        ios: IosSounds.electronic,
        looping: true,
        volume: 1.0,
      );
    } catch (e) {
      debugPrint('Error playing ringtone: $e');
    }
  }

  void _acceptCall() async {
    try {
      // Stop ringtone
      await FlutterRingtonePlayer().stop();

      // Update call state
      _callController.updateCallState(CallState.connecting);

      // Create User object for caller
      final caller = User(
        sId: widget.callerId,
        name: widget.callerName,
        photos: widget.callerImage.isNotEmpty ? [widget.callerImage] : [],
      );

      // Navigate to appropriate call screen
      if (widget.isVideo) {
        await Get.off(() => VideoCallScreen(
              meetingId: widget.meetingId,
              channel: widget.channelName,
              token: widget.token,
              participant: caller,
              isInstaTalk: widget.isInstaTalk,
              initialTimer: int.tryParse(widget.callDuration) ?? 30,
              isIncomingCall: true,
            ));
      } else {
        await Get.off(() => CallScreen(
              meetingId: widget.meetingId,
              channel: widget.channelName,
              token: widget.token,
              participant: caller,
              isInstaTalk: widget.isInstaTalk,
              initialTimer: int.tryParse(widget.callDuration) ?? 30,
              isIncomingCall: true,
              callerName: widget.callerName,
              callerImage: widget.callerImage,
            ));
      }
    } catch (e) {
      debugPrint('Error accepting call: $e');
      Get.back();
    }
  }

  void _rejectCall() async {
    try {
      // Stop ringtone
      await FlutterRingtonePlayer().stop();

      // Update call state
      _callController.updateCallState(CallState.rejected);

      // Reject the call via API
      await CallNotificationService().endCurrentCall();

      // Close the screen
      if (mounted) {
        Get.back();
      }
    } catch (e) {
      debugPrint('Error rejecting call: $e');
      if (mounted) {
        Get.back();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return WillPopScope(
      onWillPop: () async {
        _rejectCall();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black87,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Background image with blur effect
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.blue.shade900.withOpacity(0.7),
                    Colors.black.withOpacity(0.9),
                  ],
                ),
              ),
            ),

            // Animated wave pattern background
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: CircleWavePainter(
                      _animationController.value,
                      color: AppColors.primaryColor.withOpacity(0.3),
                    ),
                  );
                },
              ),
            ),

            // Call content
            SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Call info section
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Column(
                      children: [
                        Text(
                          widget.isInstaTalk ? 'InstaTalk' : 'Incoming Call',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              widget.isVideo ? Icons.videocam : Icons.call,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.isVideo ? 'Video Call' : 'Voice Call',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Caller info
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 1.0 + (_animationController.value * 0.05),
                        child: Column(
                          children: [
                            // Caller avatar
                            Container(
                              width: screenWidth * 0.45,
                              height: screenWidth * 0.45,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      AppColors.primaryColor.withOpacity(0.8),
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        AppColors.primaryColor.withOpacity(0.3),
                                    spreadRadius: 5,
                                    blurRadius: 15,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: widget.callerImage.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: widget.callerImage,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            const CircularProgressIndicator(),
                                        errorWidget: (context, url, error) =>
                                            const Icon(
                                          Icons.person,
                                          size: 70,
                                          color: Colors.white70,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.person,
                                        size: 70,
                                        color: Colors.white70,
                                      ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Caller name
                            Text(
                              widget.callerName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Call actions
                  Container(
                    margin: const EdgeInsets.only(bottom: 40),
                    child: AnimatedOpacity(
                      opacity: _showControls ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Decline button
                          _buildCallActionButton(
                            icon: Icons.call_end,
                            color: Colors.red,
                            onPressed: _rejectCall,
                            label: 'Decline',
                          ),
                          // Accept button
                          _buildCallActionButton(
                            icon: widget.isVideo ? Icons.videocam : Icons.call,
                            color: Colors.green,
                            onPressed: _acceptCall,
                            label: 'Accept',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Call timer
            Positioned(
              bottom: 10,
              right: 10,
              child: Text(
                '${45 - _callTimeElapsed}s',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              customBorder: const CircleBorder(),
              child: Icon(
                icon,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

/// Custom painter for creating animated wave effect
class CircleWavePainter extends CustomPainter {
  final double progress;
  final Color color;

  CircleWavePainter(this.progress, {required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final center = Offset(size.width / 2, size.height / 2.5);
    final maxRadius = size.width * 0.6;

    // Draw multiple expanding circles
    for (int i = 0; i < 4; i++) {
      final double radius = maxRadius * ((progress + i * 0.25) % 1.0);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(CircleWavePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
