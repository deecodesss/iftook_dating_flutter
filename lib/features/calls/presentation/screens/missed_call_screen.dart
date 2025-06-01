import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:iftook/helpers/app_colors.dart';
import 'package:iftook/features/profile/data/models/user.dart';
import 'package:iftook/features/calls/controllers/call_controller.dart';

class MissedCallScreen extends StatefulWidget {
  final User caller;
  final DateTime timestamp;
  final bool isVideo;
  final bool isInstatalk;

  const MissedCallScreen({
    Key? key,
    required this.caller,
    required this.timestamp,
    this.isVideo = false,
    this.isInstatalk = false,
  }) : super(key: key);

  @override
  State<MissedCallScreen> createState() => _MissedCallScreenState();
}

class _MissedCallScreenState extends State<MissedCallScreen> {
  late final CallController _callController;

  @override
  void initState() {
    super.initState();
    _callController = Get.find<CallController>();
  }

  void _callBack() {
    // Initiate a call back to the caller
    if (widget.isInstatalk) {
      _callController.initiateInstaTalkCall(widget.caller.sId!,
          widget.isVideo ? 'video' : 'voice', widget.caller.name ?? 'Unknown');
    } else {
      _callController.initiateMeetingCall(
        widget.caller.sId!,
        widget.isVideo ? 'video' : 'voice',
        DateTime.now(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Missed Call'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Caller image with missed call icon overlay
              Stack(
                alignment: Alignment.center,
                children: [
                  // Caller image
                  CircleAvatar(
                    radius: 70,
                    backgroundColor: Colors.grey[800],
                    backgroundImage: widget.caller.photos?.isNotEmpty == true
                        ? NetworkImage(widget.caller.photos!.first)
                        : null,
                    child: widget.caller.photos?.isEmpty ?? true
                        ? const Icon(Icons.person,
                            size: 70, color: Colors.white54)
                        : null,
                  ),

                  // Overlay gradient
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

                  // Missed call icon
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.call_missed,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // Caller name
              Text(
                widget.caller.name ?? 'Unknown Caller',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 10),

              // Call type
              Text(
                '${widget.isVideo ? 'Video' : 'Voice'} ${widget.isInstatalk ? 'InstaTalk' : 'Call'}',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[400],
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 20),

              // Timestamp
              Text(
                'Missed at ${DateFormat('h:mm a').format(widget.timestamp)}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[500],
                ),
              ),

              const SizedBox(height: 50),

              // Call back button
              ElevatedButton.icon(
                onPressed: _callBack,
                icon: const Icon(Icons.call_made, color: Colors.white),
                label: const Text(
                  'Call Back',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  minimumSize: const Size(200, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Dismiss button
              TextButton(
                onPressed: () => Get.back(),
                child: Text(
                  'Dismiss',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[400],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
