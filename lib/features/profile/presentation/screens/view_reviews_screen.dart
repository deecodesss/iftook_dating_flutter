import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iftook/features/profile/presentation/screens/add_review_screen.dart';
import 'package:iftook/helpers/app_colors.dart';

import '../../../../core/services/api_service.dart';

class ViewReviewsScreen extends StatefulWidget {
  final String userId;

  const ViewReviewsScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<ViewReviewsScreen> createState() => _ViewReviewsScreenState();
}

class _ViewReviewsScreenState extends State<ViewReviewsScreen> {
  bool isLoading = true;
  List<Review> reviews = [];
  Map<String, double> ratings = {};
  double averageRating = 0.0;
  final _reviewController = TextEditingController();
  double _userRating = 0;

  @override
  void initState() {
    super.initState();
    _fetchUserRatings();
  }

  Future<void> _fetchUserRatings() async {
    try {
      setState(() => isLoading = true);
      final response = await ApiService.getRatings(widget.userId);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Parse ratings
        if (data['ratings'] != null) {
          final Map<String, dynamic> ratingsData = data['ratings'];
          ratings = {
            'Overall': ratingsData['average']?.toDouble() ?? 0.0,
            'Politeness': ratingsData['politeness']?.toDouble() ?? 0.0,
            'Communication': ratingsData['communication']?.toDouble() ?? 0.0,
            'Professionalism':
                ratingsData['professionalism']?.toDouble() ?? 0.0,
            'Punctuality': ratingsData['punctuality']?.toDouble() ?? 0.0,
          };
          averageRating = ratings['Overall'] ?? 0.0;
        }

        // Parse reviews
        if (data['reviews'] != null) {
          reviews = (data['reviews'] as List)
              .map((review) => Review(
                    name: review['reviewer']?['name'] ?? 'Anonymous',
                    rating: review['rating']?.toDouble() ?? 0.0,
                    comment: review['review'] ?? '',
                    date: review['createdAt'] != null
                        ? DateTime.parse(review['createdAt'])
                            .toString()
                            .split('.')[0]
                        : '',
                  ))
              .toList();
        }
      } else {
        throw Exception('Failed to fetch ratings');
      }
    } catch (e) {
      print('Error fetching ratings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching ratings: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ratings & Reviews')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
          title: Text('Ratings & Reviews', style: GoogleFonts.manrope())),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () async {
      //     final result = await Navigator.push(
      //       context,
      //       MaterialPageRoute(
      //         builder: (context) => AddReviewScreen(userId: widget.userId),
      //       ),
      //     );

      //     if (result == true) {
      //       // Refresh reviews if a new review was added
      //       await _fetchUserRatings();
      //     }
      //   },
      //   child: const Icon(Icons.rate_review),
      //   backgroundColor: AppColors.primaryColor,
      // ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Overall Rating Card
            _buildOverallRatingCard(),

            // Detailed Ratings
            _buildDetailedRatingsCard(),

            // Reviews List
            _buildReviewsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallRatingCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
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
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                averageRating.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                ' / 5.0',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 16),
          Text(
            'Based on ${reviews.length} reviews',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedRatingsCard() {
    // Remove 'Overall' from detailed breakdown
    final detailedRatings = Map<String, double>.from(ratings)
      ..remove('Overall');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rating Breakdown',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // Build rating bars only for detailed ratings
          ...detailedRatings.entries
              .map((entry) => _buildRatingBar(entry.key, entry.value)),
        ],
      ),
    );
  }

  Widget _buildRatingBar(String label, double rating) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: 16,
                ),
              ),
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: rating / 5,
            backgroundColor: Colors.grey[700],
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppColors.primaryColor,
            ),
            minHeight: 8,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsList() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Reviews',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...reviews.map((review) => _buildReviewCard(review)),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Review review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                review.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                review.date,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              return Icon(
                index < review.rating ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 16,
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            review.comment,
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class Review {
  final String name;
  final double rating;
  final String comment;
  final String date;

  Review({
    required this.name,
    required this.rating,
    required this.comment,
    required this.date,
  });
}
