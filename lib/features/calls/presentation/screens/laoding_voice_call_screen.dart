import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/features/calls/presentation/screens/voice_call_screen.dart';
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
  bool _isSpeakerOn = true;
  bool _isMuted = false;
  String _loadingStateMessage =
      'Calling...'; // To manage different loading/failure states

  @override
  void initState() {
    super.initState();
    // Initialize CallController if not already initialized
    _callController = Get.put(CallController());

    // Listen to call controller's state for more detailed feedback
    // Assuming CallController has observables like:
    // RxString callStatusMessage = 'Calling...'.obs;
    // RxBool callFailed = false.obs;
    // For this example, we'll use _loadingStateMessage and update it based on hypothetical controller states.

    // Example of how you might listen to detailed status from CallController:
    // ever(_callController.callStatus, _handleCallStatusChange);

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
          print('Is InstaTalk: ${widget.isInstaTalk}');
          print('Is Trial: ${widget.isTrial}');
          print('InstaTalk Duration: ${widget.instaTalkDuration}');

          // Start call rejection listener for outgoing calls
          _callController.startCallRejectionListener(widget.meetingId!);
          // Update loading state message based on call controller's status
          // This is a simplified representation. Ideally, CallController would expose a reactive state.
          if (_callController.wasCallRejected.value) {
            // Hypothetically, CallController might have a more specific reason
            // String reason = _callController.rejectionReason.value; // e.g., "declined", "busy"
            // For now, we'll use a generic message if wasCallRejected is true before navigation.
            setState(() {
              _loadingStateMessage =
                  "${widget.participant.name ?? 'User'} is unavailable.";
            });
            // Potentially show the rejection UI immediately if already rejected.
            return; // Don't proceed to navigate if already rejected.
          }

          // End any existing call notifications
          await FlutterCallkitIncoming.endCall(widget.meetingId!);

          // Navigate directly to call screen after a short delay
          // to give the rejection listener time to initialize
          Future.delayed(const Duration(milliseconds: 500), () {
            // Don't navigate if component is unmounted or call was rejected
            if (!mounted) return;

            if (_callController.wasCallRejected.value) {
              // Update UI based on rejection
              setState(() {
                // Assuming CallController provides a specific message for rejection/busy.
                // For example: _loadingStateMessage = _callController.callFailedMessage.value;
                // If not, use a generic one.
                _loadingStateMessage =
                    "${widget.participant.name ?? 'User'} declined the call.";
              });
              return;
            }

            print('Navigating to VoiceCallScreen with:');
            print('Is InstaTalk: ${widget.isInstaTalk}');
            print('Is Trial: ${widget.isTrial}');
            print('InstaTalk Duration: ${widget.instaTalkDuration}');

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
                      onSessionEnd: widget.onSessionEnd,
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
        print('Is InstaTalk: ${widget.isInstaTalk}');
        print('Is Trial: ${widget.isTrial}');
        print('InstaTalk Duration: ${widget.instaTalkDuration}');

        if (widget.isInstaTalk) {
          // Listen for immediate failure from initiateInstaTalkCall if it returns a status
          // or updates an observable in CallController
          await _callController.initiateInstaTalkCall(
            widget.participant.sId.toString(),
            widget.type,
            isTrial: widget.isTrial,
          );
        } else {
          await _callController.initiateMeetingCall(
            widget.participant.sId.toString(),
            widget.type,
            widget.scheduleTime,
          );
        }
        // After initiation, check controller status again or rely on listeners
        // if (_callController.callFailed.value) { // Hypothetical
        //   setState(() {
        //     _loadingStateMessage = _callController.callFailedMessage.value;
        //   });
        // }
      } catch (e) {
        print('Error initializing voice call: $e');
        if (mounted) {
          setState(() {
            _loadingStateMessage = 'Failed to connect';
          });
        }
      }
    });
  }

  void _endCall() {
    try {
      if (widget.meetingId != null) {
        _callController
            .rejectCall(); // This should ideally tell the backend the sender cancelled
        FlutterCallkitIncoming.endCall(widget.meetingId!);
      }
      if (mounted) {
        setState(() {
          // Assuming CallController updates a state that leads to wasCallRejected being true
          // and potentially a message like "Call Cancelled"
          _loadingStateMessage = "Call Cancelled";
        });
        // Delay Get.back to allow UI to update if desired, or handle it via controller state change
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) Get.back();
        });
      } else {
        Get.back();
      }
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: Obx(() {
          // Show rejection/failure UI if call has been rejected or failed
          // This condition should be driven by more specific states from CallController
          // For example: if (_callController.callState.value == CallState.rejected || _callController.callState.value == CallState.busy)
          if (_callController.wasCallRejected.value ||
              _loadingStateMessage == "Call Cancelled" ||
              _loadingStateMessage == "Failed to connect" ||
              _loadingStateMessage.contains("unavailable") ||
              _loadingStateMessage.contains("declined")) {
            // Determine the specific message for the UI
            String statusMessage = _loadingStateMessage;
            IconData statusIcon = Icons.call_end;
            Color iconColor = Colors.red;

            // Hypothetical: refine message based on CallController's detailed status
            // if (_callController.callEndReason.value == "busy") {
            //   statusMessage = "${widget.participant.name ?? 'User'} is busy";
            //   statusIcon = Icons.phone_missed; // Or a busy icon
            // } else if (_callController.callEndReason.value == "declined") {
            //   statusMessage = "${widget.participant.name ?? 'User'} declined the call";
            // } else if (_loadingStateMessage == "Call Cancelled") {
            //   statusMessage = "Call Cancelled";
            // }

            // For now, we use the _loadingStateMessage directly if it's a failure/rejection state
            if (_callController.wasCallRejected.value &&
                !_loadingStateMessage.contains("declined") &&
                !_loadingStateMessage.contains("unavailable")) {
              statusMessage =
                  "${widget.participant.name ?? 'User'} declined the call.";
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
                  const Text(
                    'Calling...',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _loadingStateMessage, // Use the dynamic loading state message
                    style: const TextStyle(
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

  // Renamed and generalized UI for various call end/failure statuses
  Widget _buildCallStatusUI(String message, IconData icon, Color iconColor) {
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
          Icon(
            icon,
            color: iconColor,
            size: 50,
          ),
          const SizedBox(height: 20),
          Text(
            message, // Display the specific message
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
              style: TextStyle(
                  fontSize: 18,
                  color: Colors.white), // Ensure text color is white
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
