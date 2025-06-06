import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iftook/features/calls/presentation/screens/dedicatedScreens/instaTalk/ITVideoCall.dart';
import 'package:iftook/features/calls/presentation/screens/dedicatedScreens/instaTalk/ITVoiceCall.dart';
import 'package:iftook/features/calls/presentation/screens/dedicatedScreens/meetingCalls/normalVideoCall.dart';
import 'package:iftook/features/calls/presentation/screens/dedicatedScreens/meetingCalls/normalVoiceCall.dart';
import 'package:iftook/features/profile/data/models/user.dart';
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
  final String callerRating;
  final String callRate;
  final String callDuration;
  final String callerId;
  final bool isInstatalk;
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
    this.isInstatalk = false,
    this.meetingType = "regularMeeting",
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
        const platform = MethodChannel('com.application.iftook/screen');
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
        const platform = MethodChannel('com.application.iftook/audio');
        platform.invokeMethod('playRingtoneAsCall');
      } else {
        // iOS fallback
        FlutterRingtonePlayer().play(
          ios: IosSounds.glass,
          looping: true,
          volume: 0.5,
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
        const platform = MethodChannel('com.application.iftook/audio');
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

  void _acceptCall() async {
    try {
      print('Starting call acceptance process...');
      print('Token: ${widget.token}');
      print('Channel: ${widget.channelName}');
      print('Meeting ID: ${widget.meetingId}');

      if (widget.token.isEmpty) {
        throw Exception('Token is missing');
      }

      // Safe ringtone stopping
      try {
        await FlutterRingtonePlayer().stop();
      } catch (e) {
        print('Error stopping ringtone: $e');
      }

      _callTimer?.cancel();
      await WakelockPlus.enable();

      final Map<String, dynamic> callParams = {
        'meetingId': widget.meetingId,
        'channel': widget.channelName,
        'token': widget.token,
        'initialTimer': int.parse(widget.callDuration),
      };

      print('Navigating to call screen with params: $callParams');
      final User caller = User(
        sId: widget.callerId,
        name: widget.callerName,
        photos: widget.callerImage.isNotEmpty ? [widget.callerImage] : [],
      );
      if (widget.isVideo && widget.isInstatalk) {
        await Get.off(
          () => ITVideoCallScreen(
            participant: caller,
            meetingId: widget.meetingId,
            channel: widget.channelName,
            token: widget.token,
            // initialTimer: int.parse(widget.callDuration),
            isIncomingCall: true,
            // isInstatalk: widget.isInstatalk,
          ),
          transition: Transition.rightToLeftWithFade,
        );
      } else if (widget.isVideo && !widget.isInstatalk) {
        await Get.off(
          () => NormalVideoCallScreen(
            meetingId: widget.meetingId,
            channel: widget.channelName,
            token: widget.token,
            initialTimer: double.parse(widget.callDuration),
            isIncomingCall: true,
          ),
          transition: Transition.rightToLeftWithFade,
        );
      } else if (!widget.isVideo && widget.isInstatalk) {
        await Get.off(
          () => ITVoiceCallScreen(
            participant: caller,
            meetingId: widget.meetingId,
            channel: widget.channelName,
            token: widget.token,
            // initialTimer: int.parse(widget.callDuration),
            isIncomingCall: true,
            // isInstatalk: widget.isInstatalk,
          ),
          transition: Transition.rightToLeftWithFade,
        );
      } else {
        await Get.off(
          () => NormalVoiceCallScreen(
            participant: caller,
            meetingId: widget.meetingId,
            channel: widget.channelName,
            token: widget.token,
            initialTimer: double.parse(widget.callDuration),
            isIncomingCall: true,
          ),
          transition: Transition.rightToLeftWithFade,
        );
      }
    } catch (e) {
      print('Error accepting call: $e');
      Get.snackbar(
        'Error',
        'Failed to accept call: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }

  void _declineCall() {
    _stopRingtone();

    _callTimer?.cancel();

    WakelockPlus.disable();
    _sendCallRejectedNotification();

    // Return to previous screen
    Get.back();
  }

  void _sendCallRejectedNotification() {
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
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                widget.isVideo
                    ? Colors.blue.shade900.withOpacity(0.9)
                    : Colors.green.shade900.withOpacity(0.9),
                Colors.black,
              ],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                // Background circle animation
                Positioned.fill(
                  child: _buildPulsingBackground(),
                ),

                Column(
                  children: [
                    // Call type indicator
                    _buildCallTypeHeader(),

                    const Spacer(flex: 1),

                    // Caller info section
                    _buildCallerInfo(),

                    const Spacer(flex: 2),

                    // Call details
                    if (double.parse(widget.callRate) > 0) _buildCallRateInfo(),

                    const Spacer(flex: 1),

                    // Action buttons
                    _buildActionButtons(),

                    const SizedBox(height: 50),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPulsingBackground() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Center(
          child: Container(
            width: 300 * _animation.value,
            height: 300 * _animation.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (widget.isVideo ? Colors.blue : Colors.green)
                  .withOpacity(0.1 * (2 - _animation.value)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCallTypeHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.isVideo ? Icons.videocam : Icons.phone,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 8),
          Text(
            'Incoming ${widget.isVideo ? 'Video' : 'Voice'} Call',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallerInfo() {
    return Column(
      children: [
        // Caller image
        Hero(
          tag: 'caller_image',
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: (widget.isVideo ? Colors.blue : Colors.green)
                      .withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipOval(
              child: widget.callerImage.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: widget.callerImage,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => _buildPlaceholder(),
                      errorWidget: (context, url, error) => _buildPlaceholder(),
                    )
                  : _buildPlaceholder(),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Caller name
        Text(
          widget.callerName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),

        // Caller rating if available
        if (widget.callerRating != "0")
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text(
                  widget.callerRating,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCallRateInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.payment, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            '₹${widget.callRate}/30min',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        GestureDetector(
          // Wrap in GestureDetector
          onTap: _declineCall,
          child: _buildActionButton(
            icon: Icons.call_end,
            color: Colors.white,
            backgroundColor: Colors.red,
            onTap: _declineCall,
            label: 'Decline',
          ),
        ),
        GestureDetector(
          // Wrap in GestureDetector
          onTap: _acceptCall,
          child: _buildActionButton(
            icon: widget.isVideo ? Icons.videocam : Icons.call,
            color: Colors.white,
            backgroundColor: widget.isVideo ? Colors.blue : Colors.green,
            onTap: _acceptCall,
            label: 'Accept',
            animate: true,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onTap,
    required String label,
    double size = 64,
    bool animate = false,
  }) {
    Widget button = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: backgroundColor.withOpacity(0.3),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(icon, color: color, size: size * 0.4),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
          ),
        ),
      ],
    );

    if (animate) {
      return AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _animation.value,
            child: button,
          );
        },
      );
    }

    return button;
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: const Icon(Icons.person, size: 60, color: Colors.white60),
    );
  }
}
