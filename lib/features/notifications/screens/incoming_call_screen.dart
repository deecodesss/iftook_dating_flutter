import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iftook/helpers/app_colors.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../calls/presentation/screens/video_call_screen.dart';
import '../../calls/presentation/screens/voice_call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callerName;
  final String callerImage;
  final bool isVideo;
  final String meetingId;
  final String channelName;
  final String token;

  const IncomingCallScreen({
    Key? key,
    required this.callerName,
    required this.callerImage,
    required this.isVideo,
    required this.meetingId,
    required this.channelName,
    required this.token,
  }) : super(key: key);

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  Timer? _callTimer;
  int _ringSeconds = 0;
  final int _maxRingTime = 30; // Maximum ring time in seconds
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // Make sure screen turns on and stays on during call
    _wakeDeviceAndKeepScreenOn();

    // Play ringtone at full volume
    _playLoudRingtone();

    // Start the timer for auto-decline
    _startCallTimer();

    // Set up pulsating animation for answer button
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  void _wakeDeviceAndKeepScreenOn() async {
    try {
      // Turn on the screen and keep it on for a call
      await WakelockPlus.enable();

      // On Android, also ensure we're showing over lock screen
      if (Platform.isAndroid) {
        const platform = MethodChannel('com.yourcompany.iftook/screen');
        await platform.invokeMethod('wakeUpDevice');
      }
    } catch (e) {
      debugPrint('Error setting wakelock: $e');
    }
  }

  void _playLoudRingtone() {
    try {
      // Use platform-specific methods for better volume control
      if (Platform.isAndroid) {
        const platform = MethodChannel('com.yourcompany.iftook/audio');
        platform.invokeMethod('playRingtoneAsCall');
      } else {
        // iOS fallback
        FlutterRingtonePlayer().play(
          ios: IosSounds.glass,
          looping: true,
          volume: 1.0,
          asAlarm: true,
        );
      }
    } catch (e) {
      debugPrint('Error playing ringtone: $e');
      // Fallback to basic ringtone player
      FlutterRingtonePlayer().play(
        android: AndroidSounds.ringtone,
        ios: IosSounds.glass,
        looping: true,
        volume: 1.0,
        asAlarm: true,
      );
    }
  }

  void _stopRingtone() {
    try {
      FlutterRingtonePlayer().stop();

      if (Platform.isAndroid) {
        const platform = MethodChannel('com.yourcompany.iftook/audio');
        platform.invokeMethod('stopRingtone');
      }
    } catch (e) {
      debugPrint('Error stopping ringtone: $e');
    }
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _ringSeconds++;
        if (_ringSeconds >= _maxRingTime) {
          // Auto-decline after max ring time
          _declineCall();
        }
      });
    });
  }

  void _acceptCall() {
    // Stop ringtone
    _stopRingtone();

    // Cancel timer
    _callTimer?.cancel();

    // Allow screen to turn off again but only after navigating to call screen
    // WakelockPlus.disable();

    // Navigate to appropriate call screen
    if (widget.isVideo) {
      Get.off(() => VideoCallScreen(
            meetingId: widget.meetingId,
            channel: widget.channelName,
            token: widget.token,
          ));
    } else {
      Get.off(() => VoiceCallScreen(
            meetingId: widget.meetingId,
            channel: widget.channelName,
            token: widget.token,
          ));
    }
  }

  void _declineCall() {
    // Stop ringtone
    _stopRingtone();

    // Cancel timer
    _callTimer?.cancel();

    // Allow screen to turn off again
    WakelockPlus.disable();

    // TODO: Send a notification to caller that call was rejected
    // Use an API call to inform caller about rejection
    _sendCallRejectedNotification();

    // Return to previous screen
    Get.back();
  }

  void _sendCallRejectedNotification() {
    // Implement API call to notify caller the call was rejected
    // This is a placeholder for the implementation
    try {
      // Example API call (to be implemented)
      // ApiService.rejectCall(widget.meetingId);
    } catch (e) {
      debugPrint('Error sending rejection notification: $e');
    }
  }

  @override
  void dispose() {
    // Clean up resources
    _callTimer?.cancel();
    _stopRingtone();
    _animationController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _declineCall();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  widget.isVideo ? Colors.blue.shade900 : Colors.green.shade900,
                  Colors.black,
                ],
              ),
            ),
            child: Column(
              children: [
                // Status bar with call type and timer
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            widget.isVideo ? Icons.videocam : Icons.call,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.isVideo ? 'Video Call' : 'Voice Call',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '0:${_ringSeconds.toString().padLeft(2, '0')}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 1),

                // Caller image
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.5), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: (widget.isVideo ? Colors.blue : Colors.green)
                            .withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: widget.callerImage.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.callerImage,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[800],
                              child: const Icon(Icons.person,
                                  size: 80, color: Colors.white60),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[800],
                              child: const Icon(Icons.person,
                                  size: 80, color: Colors.white60),
                            ),
                          )
                        : Container(
                            color: Colors.grey[800],
                            child: const Icon(Icons.person,
                                size: 80, color: Colors.white60),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                // Caller name
                Text(
                  widget.callerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                // Call status text
                Text(
                  'Incoming ${widget.isVideo ? 'video' : 'voice'} call...',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7), fontSize: 16),
                ),

                const Spacer(flex: 2),

                // Call action buttons
                Padding(
                  padding: const EdgeInsets.only(bottom: 60),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Decline button
                      GestureDetector(
                        onTap: _declineCall,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.call_end,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),

                      // Accept button with animation
                      GestureDetector(
                        onTap: _acceptCall,
                        child: AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _animation.value,
                                child: Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    color: widget.isVideo
                                        ? Colors.blue
                                        : Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    widget.isVideo
                                        ? Icons.videocam
                                        : Icons.call,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                              );
                            }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
