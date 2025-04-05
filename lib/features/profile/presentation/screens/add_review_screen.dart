import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iftook/helpers/app_colors.dart';
import '../../../../core/services/api_service.dart';
import 'dart:convert';

class AddReviewScreen extends StatefulWidget {
  final String userId;

  const AddReviewScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  _AddReviewScreenState createState() => _AddReviewScreenState();
}

class _AddReviewScreenState extends State<AddReviewScreen> {
  final TextEditingController _reviewController = TextEditingController();
  bool isSubmitting = false;

  // Rating values for each factor
  Map<String, double> ratings = {
    'Politeness': 0,
    'Communication': 0,
    'Professionalism': 0,
    'Punctuality': 0,
  };

  double get averageRating {
    if (ratings.isEmpty) return 0;
    return ratings.values.reduce((a, b) => a + b) / ratings.length;
  }

  Future<void> _submitReview() async {
    // Check if any rating is missing
    for (var entry in ratings.entries) {
      if (entry.value == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please rate ${entry.key}')),
        );
        return;
      }
    }

    setState(() => isSubmitting = true);

    try {
      final response = await ApiService.addRating(
        widget.userId,
        ratings,
        _reviewController.text,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submitted successfully!')),
        );
      } else {
        final error = jsonDecode(response.body);
        if (error['error']?.toString()?.contains('already rated') ?? false) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You have already rated this user')),
          );
        } else {
          throw Exception(error['error'] ?? 'Failed to submit review');
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Add Review & Rating',
          style: GoogleFonts.manrope(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overall Rating Display
            Center(
              child: Column(
                children: [
                  Text(
                    'Overall Rating',
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    averageRating.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return Icon(
                        index < averageRating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 24,
                      );
                    }),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Individual Rating Factors
            ...ratings.entries.map((entry) => _buildRatingFactor(entry.key)),

            const SizedBox(height: 24),

            // Review Text Field
            Text(
              'Write Your Review (Optional)',
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reviewController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Share your experience...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                fillColor: Colors.grey[850],
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isSubmitting ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Submit Review',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingFactor(String factor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            factor,
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: List.generate(5, (index) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    ratings[factor] = index + 1.0;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    index < (ratings[factor] ?? 0)
                        ? Icons.star
                        : Icons.star_border,
                    color: Colors.amber,
                    size: 32,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
