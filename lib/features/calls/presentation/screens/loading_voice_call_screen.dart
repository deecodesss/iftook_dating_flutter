import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/features/calls/presentation/screens/dedicatedScreens/instaTalk/ITVoiceCall.dart';
import 'package:iftook/features/calls/presentation/screens/dedicatedScreens/meetingCalls/normalVoiceCall.dart';
import 'package:iftook/features/calls/presentation/screens/voice_call_screen.dart';
import 'package:iftook/features/calls/services/ringtone_service.dart'; // Import the new service
import 'dart:async';

import '../../../../helpers/app_colors.dart';
import '../../../profile/data/models/user.dart';
import '../../controllers/call_controller.dart';
import '../../../wallet/controllers/wallet_controller.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

class VoiceCallLoadingScreen extends StatefulWidget {
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
  final double? remainingTime;

  const VoiceCallLoadingScreen({
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
    this.remainingTime,
  }) : super(key: key);

  @override
  State<VoiceCallLoadingScreen> createState() => _VoiceCallLoadingScreenState();
}

class _VoiceCallLoadingScreenState extends State<VoiceCallLoadingScreen> {
  late final CallController _callController;
  late final RingtoneService _ringtoneService; // Add ringtone service
  bool _isSpeakerOn = true;
  bool _isMuted = false;

  // Replace static message with reactive state
  final RxString loadingStateMessage = 'Calling...'.obs;

  // Add timer to automatically go back if call setup takes too long
  Timer? _callTimeoutTimer;

  @override
  void initState() {
    super.initState();
    // Initialize CallController if not already initialized
    _callController = Get.put(CallController());

    // Initialize the ringtone service
    _ringtoneService = RingtoneService();

    // Listen to the call controller's state changes
    ever(_callController.currentCallState, _handleCallStateChange);
    ever(_callController.callStatusMessage, (message) {
      if (message.isNotEmpty) {
        loadingStateMessage.value = message;
      }
    });

    // Set a timeout to automatically go back if call setup takes too long
    // _callTimeoutTimer = Timer(const Duration(seconds: 45), () {
    //   if (mounted && !_callController.hasRemoteUserJoined.value) {
    //     loadingStateMessage.value = 'Call timed out';
    //     // Show UI for timeout/no answer for a moment before going back
    //     Future.delayed(const Duration(seconds: 2), () {
    //       if (mounted) Get.back();
    //     });
    //   }
    // });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
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

          _callController.updateCallState(CallState.outgoing);

          _callController.startCallRejectionListener(widget.meetingId!);

          // End any existing call notifications
          await FlutterCallkitIncoming.endCall(widget.meetingId!);

          Future.delayed(const Duration(milliseconds: 500), () {
            if (!mounted) return;

            if (_callController.wasCallRejected.value ||
                _callController.wasCallBusy.value ||
                _callController.wasCallFailed.value) {
              return;
            }

            print('Navigating to VoiceCallScreen with:');
            print('Is InstaTalk: ${widget.isInstatalk}');
            print('Is Trial: ${widget.isTrial}');
            print('InstaTalk Duration: ${widget.instaTalkDuration}');

            if (widget.isInstatalk) {
              Get.to(
                  () => ITVoiceCallScreen(
                        meetingId: widget.meetingId!,
                        channel: widget.channel!,
                        token: widget.token!,
                        // initialTimer: widget.instaTalkDuration,
                        isTrial: widget.isTrial,
                        // isInstatalk: widget.isInstatalk,
                        participant: widget.participant,
                        onSessionEnd: widget.onSessionEnd,
                      ),
                  arguments: {'participant': widget.participant});
            } else {
              Get.to(
                  () => NormalVoiceCallScreen(
                        meetingId: widget.meetingId!,
                        channel: widget.channel!,
                        token: widget.token!,
                        initialTimer: widget.remainingTime! ?? 30,
                        participant: widget.participant,
                        onSessionEnd: widget.onSessionEnd,
                      ),
                  arguments: {'participant': widget.participant});
            }
          });
          return;
        }

        // Otherwise proceed with normal initialization
        print('Initializing voice call...');
        print('Participant ID: ${widget.participant.sId}');
        print('Call Type: ${widget.type}');
        print('Schedule Time: ${widget.scheduleTime}');
        print('Is InstaTalk: ${widget.isInstatalk}');
        print('Is Trial: ${widget.isTrial}');
        print('InstaTalk Duration: ${widget.instaTalkDuration}');

        loadingStateMessage.value = 'Setting up call...';

        if (widget.isInstatalk) {
          loadingStateMessage.value = 'Starting InstaTalk call...';
          await _callController.initiateInstaTalkCall(
            widget.participant.sId.toString(),
            widget.type,
            widget.participant.name ?? 'Unknown',
            isTrial: widget.isTrial,
          );
        } else {
          loadingStateMessage.value = 'Calling ${widget.participant.name}...';
          await _callController.initiateMeetingCall(
            widget.participant.sId.toString(),
            widget.type,
            widget.scheduleTime,
          );
        }
      } catch (e) {
        print('Error initializing voice call: $e');
        if (mounted) {
          loadingStateMessage.value = 'Failed to connect';
          // Show error briefly before going back
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) Get.back();
          });
        }
      }
    });
  }

  // Handle call state changes
  void _handleCallStateChange(CallState state) {
    if (!mounted) return;

    switch (state) {
      case CallState.rejected:
        loadingStateMessage.value =
            "${widget.participant.name ?? 'User'} declined the call";
        break;
      case CallState.busy:
        loadingStateMessage.value =
            "${widget.participant.name ?? 'User'} is busy";
        break;
      case CallState.failed:
        loadingStateMessage.value = "Couldn't connect the call";
        break;
      case CallState.missed:
        loadingStateMessage.value = "No answer";
        break;
      case CallState.disconnected:
        loadingStateMessage.value = "Call ended";
        break;
      case CallState.connecting:
        loadingStateMessage.value = "Connecting...";
        break;
      case CallState.connected:
        loadingStateMessage.value = "Connected";
        break;
      case CallState.outgoing:
        loadingStateMessage.value = "Calling ${widget.participant.name}...";
        break;
      default:
        // Keep current message for other states
        break;
    }
  }

  void _endCall() {
    try {
      if (widget.meetingId != null) {
        // Stop ringtone
        _ringtoneService.stopRingtone();

        _callController.rejectCall(); // Tell the backend the sender cancelled
        FlutterCallkitIncoming.endCall(widget.meetingId!);
      }

      loadingStateMessage.value = "Call Cancelled";

      // Delay Get.back to allow UI to update
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) Get.back();
      });
    } catch (e) {
      print('Error ending call: $e');
      if (mounted) Get.back();
    }
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

  @override
  void dispose() {
    if (widget.meetingId != null) {
      _callController.stopCallRejectionListener();
    }

    // Stop ringtone
    _ringtoneService.stopRingtone();

    _callTimeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: Obx(() {
          // Show rejection/failure UI based on call state
          if (_callController.currentCallState.value == CallState.rejected ||
              _callController.currentCallState.value == CallState.busy ||
              _callController.currentCallState.value == CallState.missed ||
              _callController.currentCallState.value == CallState.failed ||
              _callController.currentCallState.value ==
                  CallState.disconnected) {
            // Determine the specific message and icon for the UI
            String statusMessage = loadingStateMessage.value;
            IconData statusIcon;
            Color iconColor = Colors.red;

            // Select appropriate icon based on call state
            switch (_callController.currentCallState.value) {
              case CallState.rejected:
                statusIcon = Icons.call_end;
                break;
              case CallState.busy:
                statusIcon = Icons.phone_missed;
                break;
              case CallState.missed:
                statusIcon = Icons.phone_missed;
                break;
              case CallState.failed:
                statusIcon = Icons.error_outline;
                break;
              case CallState.disconnected:
                statusIcon = Icons.call_end;
                break;
              default:
                statusIcon = Icons.call_end;
            }

            return _buildCallStatusUI(statusMessage, statusIcon, iconColor);
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
                  // const Text(
                  //   'Calling...',
                  //   style: TextStyle(
                  //     fontSize: 18,
                  //     color: Colors.white,
                  //   ),
                  // ),
                  const SizedBox(height: 8),
                  // Use the reactive loading state message
                  Obx(() => Text(
                        loadingStateMessage.value,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white70,
                        ),
                      )),
                ],
              ),

              // Call control buttons
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
                    icon: Icons.call_end,
                    color: Colors.white,
                    backgroundColor: Colors.red,
                    size: 65,
                    onTap: _endCall,
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

  // Enhanced UI for various call end/failure statuses with better visual indicators
  Widget _buildCallStatusUI(String message, IconData icon, Color iconColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Profile photo with status overlay
          Stack(
            alignment: Alignment.center,
            children: [
              CircleAvatar(
                radius: 70,
                backgroundImage: widget.participant.photos?.isNotEmpty == true
                    ? NetworkImage(widget.participant.photos!.first)
                    : null,
                child: widget.participant.photos?.isEmpty ?? true
                    ? const Icon(Icons.person, size: 70, color: Colors.white54)
                    : null,
              ),
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                    stops: const [0.7, 1.0],
                  ),
                ),
              ),
              // Status icon
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Text(
            message,
            textAlign: TextAlign.center,
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
              style: TextStyle(fontSize: 18, color: Colors.white),
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
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
