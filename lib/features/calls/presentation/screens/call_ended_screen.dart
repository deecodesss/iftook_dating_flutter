import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/features/profile/data/models/user.dart';
import 'package:iftook/features/shared/widgets/rating_review_widget.dart';
import 'package:iftook/helpers/app_colors.dart';

class CallEndedScreen extends StatelessWidget {
  final User participant;
  final String callType; // "voice" or "video"
  final Duration callDuration;

  const CallEndedScreen({
    Key? key,
    required this.participant,
    required this.callType,
    required this.callDuration,
  }) : super(key: key);

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.call_end,
                      color: Colors.red,
                      size: 50,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Call Ended',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Duration: ${_formatDuration(callDuration)}',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 30),
                    RatingAndReviewWidget(
                      userId: participant.sId ?? "",
                      interactionType: callType, // "voice" or "video"
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Get.until((route) => route.isFirst);
                  },
                  child: const Text('Return Home'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
