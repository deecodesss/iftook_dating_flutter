import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:iftook/helpers/app_colors.dart';
import 'package:iftook/core/services/api_service.dart';

class RatingAndReviewWidget extends StatefulWidget {
  final String userId;
  final String interactionType; // "chat", "voice", or "video"

  const RatingAndReviewWidget({
    Key? key,
    required this.userId,
    required this.interactionType,
  }) : super(key: key);

  @override
  State<RatingAndReviewWidget> createState() => _RatingAndReviewWidgetState();
}

class _RatingAndReviewWidgetState extends State<RatingAndReviewWidget> {
  double _rating = 3.0; // Default rating
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_rating <= 0) {
      Get.snackbar(
        'Error',
        'Please select a rating',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final response = await ApiService.submitRating(
        widget.userId,
        _rating,
        _reviewController.text,
        widget.interactionType,
      );

      if (response.statusCode == 200) {
        Get.back(); // Close dialog
        Get.snackbar(
          'Thank you',
          'Your rating has been submitted',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Error',
          'Failed to submit rating',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'An error occurred: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String interactionTypeDisplay;
    switch (widget.interactionType) {
      case "video":
        interactionTypeDisplay = "Video Call";
        break;
      case "voice":
        interactionTypeDisplay = "Voice Call";
        break;
      case "chat":
      default:
        interactionTypeDisplay = "Chat";
        break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Rate your $interactionTypeDisplay experience',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          RatingBar.builder(
            initialRating: _rating,
            minRating: 1,
            direction: Axis.horizontal,
            allowHalfRating: true,
            itemCount: 5,
            itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
            itemBuilder: (context, _) => const Icon(
              Icons.star,
              color: Colors.amber,
            ),
            onRatingUpdate: (rating) {
              setState(() {
                _rating = rating;
              });
            },
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _reviewController,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Write your review (optional)',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primaryColor),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text(
                  'Skip',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                ),
                onPressed: _isSubmitting ? null : _submitRating,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Submit'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
