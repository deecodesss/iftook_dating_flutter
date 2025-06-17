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

class _ViewReviewsScreenState extends State<ViewReviewsScreen>
    with TickerProviderStateMixin {
  bool isLoading = true;
  List<Review> reviews = [];
  Map<String, double> ratings = {};
  double averageRating = 0.0;
  late AnimationController _mainAnimationController;
  late AnimationController _ratingAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _ratingScaleAnimation;

  @override
  void initState() {
    super.initState();

    _mainAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _ratingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainAnimationController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _mainAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _ratingScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _ratingAnimationController,
      curve: Curves.elasticOut,
    ));

    _fetchUserRatings();
  }

  @override
  void dispose() {
    _mainAnimationController.dispose();
    _ratingAnimationController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserRatings() async {
    try {
      setState(() => isLoading = true);
      final response = await ApiService.getRatings(widget.userId);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('API Response: ${response.body}'); // Debug log

        // Parse reviews first
        if (data['reviews'] != null) {
          reviews = (data['reviews'] as List)
              .map((review) => Review(
                    name: review['reviewer']?['name'] ?? 'Anonymous',
                    rating: (review['rating'] ?? 0).toDouble(),
                    comment: review['review'] ?? '',
                    date: review['createdAt'] != null
                        ? DateTime.parse(review['createdAt'])
                            .toString()
                            .split('.')[0]
                        : '',
                  ))
              .toList();
        }

        // Parse ratings with better error handling
        if (data['ratings'] != null) {
          final Map<String, dynamic> ratingsData = data['ratings'];

          // Extract individual ratings
          final politeness = (ratingsData['politeness'] ?? 0).toDouble();
          final communication = (ratingsData['communication'] ?? 0).toDouble();
          final professionalism =
              (ratingsData['professionalism'] ?? 0).toDouble();
          final punctuality = (ratingsData['punctuality'] ?? 0).toDouble();

          ratings = {
            'Politeness': politeness,
            'Communication': communication,
            'Professionalism': professionalism,
            'Punctuality': punctuality,
          };

          // Calculate overall average from individual ratings OR from reviews
          final validRatings =
              ratings.values.where((rating) => rating > 0).toList();
          if (validRatings.isNotEmpty) {
            averageRating =
                validRatings.reduce((a, b) => a + b) / validRatings.length;
          } else if (reviews.isNotEmpty) {
            // Fallback to calculating from reviews if ratings breakdown is not available
            averageRating =
                reviews.map((r) => r.rating).reduce((a, b) => a + b) /
                    reviews.length;
          } else {
            averageRating = ratingsData['average']?.toDouble() ?? 0.0;
          }

          print('Parsed ratings: $ratings'); // Debug log
          print('Average rating: $averageRating'); // Debug log
          print('Reviews count: ${reviews.length}'); // Debug log
        } else if (reviews.isNotEmpty) {
          // If no ratings breakdown but have reviews, calculate from reviews
          averageRating = reviews.map((r) => r.rating).reduce((a, b) => a + b) /
              reviews.length;
          print('Calculated average from reviews: $averageRating');
        }

        // Start animations after data is loaded
        _mainAnimationController.forward();
        Future.delayed(const Duration(milliseconds: 400), () {
          _ratingAnimationController.forward();
        });
      } else {
        throw Exception('Failed to fetch ratings');
      }
    } catch (e) {
      print('Error fetching ratings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching ratings: $e'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Ratings & Reviews',
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading reviews...',
                style: GoogleFonts.manrope(
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Ratings & Reviews',
          style: GoogleFonts.manrope(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16), // Reduced from 24
            child: Column(
              children: [
                // Overall Rating Card
                _buildOverallRatingCard(),

                const SizedBox(height: 16), // Reduced from 24

                // Detailed Ratings
                _buildDetailedRatingsCard(),

                const SizedBox(height: 16), // Reduced from 24

                // Reviews List
                _buildReviewsList(),
              ],
            ),
          ),
        ),
      ),
      //   floatingActionButton: ScaleTransition(
      //     scale: _ratingScaleAnimation,
      //     child: FloatingActionButton.extended(
      //       onPressed: () async {
      //         final result = await Navigator.push(
      //           context,
      //           MaterialPageRoute(
      //             builder: (context) => AddReviewScreen(userId: widget.userId),
      //           ),
      //         );

      //         if (result == true) {
      //           await _fetchUserRatings();
      //         }
      //       },
      //       backgroundColor: AppColors.primaryColor,
      //       foregroundColor: Colors.white,
      //       elevation: 8,
      //       icon: const Icon(Icons.rate_review),
      //       label: Text(
      //         'Add Review',
      //         style: GoogleFonts.manrope(
      //           fontWeight: FontWeight.w600,
      //         ),
      //       ),
      //     ),
      //   ),
    );
  }

  Widget _buildOverallRatingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20), // Reduced from 24
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E1E1E),
            const Color(0xFF2A2A2A),
          ],
        ),
        borderRadius: BorderRadius.circular(16), // Reduced from 20
        border: Border.all(
          color: AppColors.primaryColor.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12, // Reduced from 15
            offset: const Offset(0, 4), // Reduced from 5
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Overall Rating',
            style: GoogleFonts.manrope(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13, // Reduced from 14
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12), // Reduced from 16

          // Animated Rating Display
          ScaleTransition(
            scale: _ratingScaleAnimation,
            child: Column(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: Text(
                    averageRating > 0
                        ? averageRating.toStringAsFixed(1)
                        : '0.0',
                    key: ValueKey(averageRating),
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: 40, // Reduced from 48
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '/ 5.0',
                  style: GoogleFonts.manrope(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14, // Reduced from 16
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12), // Reduced from 16

          // Animated Stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 1), // Reduced from 2
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 300 + (index * 100)),
                  child: Icon(
                    index < averageRating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: index < averageRating
                        ? const Color(0xFFFFD700)
                        : Colors.white.withOpacity(0.3),
                    size: 24, // Reduced from 28
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 12), // Reduced from 16

          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4), // Reduced
            decoration: BoxDecoration(
              color: _getRatingColor(averageRating).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12), // Reduced from 16
              border: Border.all(
                color: _getRatingColor(averageRating).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              '${reviews.length} ${reviews.length == 1 ? 'Review' : 'Reviews'}',
              style: GoogleFonts.manrope(
                color: _getRatingColor(averageRating),
                fontSize: 11, // Reduced from 12
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedRatingsCard() {
    // Only show breakdown if we have ratings
    if (ratings.values.every((rating) => rating == 0)) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16), // Reduced from 20
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12), // Reduced from 16
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rating Breakdown',
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontSize: 15, // Reduced from 16
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12), // Reduced from 16

          ...ratings.entries
              .where((entry) => entry.value > 0)
              .map((entry) => _buildAnimatedRatingBar(entry.key, entry.value))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildAnimatedRatingBar(String label, double rating) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12), // Reduced from 16
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.manrope(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 13, // Reduced from 14
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2), // Reduced
                decoration: BoxDecoration(
                  color: _getRatingColor(rating).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6), // Reduced from 8
                  border: Border.all(
                    color: _getRatingColor(rating).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  rating.toStringAsFixed(1),
                  style: GoogleFonts.manrope(
                    color: _getRatingColor(rating),
                    fontSize: 10, // Reduced from 11
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6), // Reduced from 8

          Container(
            height: 5, // Reduced from 6
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Stack(
              children: [
                AnimatedContainer(
                  duration:
                      Duration(milliseconds: 800 + (label.hashCode % 400)),
                  curve: Curves.easeOutCubic,
                  width:
                      MediaQuery.of(context).size.width * 0.75 * (rating / 5),
                  height: 5, // Reduced from 6
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getRatingColor(rating),
                        _getRatingColor(rating).withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsList() {
    if (reviews.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24), // Reduced from 32
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12), // Reduced from 16
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.rate_review_outlined,
              color: Colors.white.withOpacity(0.3),
              size: 32, // Reduced from 40
            ),
            const SizedBox(height: 8), // Reduced from 12
            Text(
              'No Reviews Yet',
              style: GoogleFonts.manrope(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14, // Reduced from 16
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2), // Reduced from 4
            Text(
              'Be the first to share your experience',
              style: GoogleFonts.manrope(
                color: Colors.white.withOpacity(0.4),
                fontSize: 11, // Reduced from 12
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16), // Reduced from 20
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12), // Reduced from 16
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Reviews',
                style: GoogleFonts.manrope(
                  color: Colors.white,
                  fontSize: 15, // Reduced from 16
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3), // Reduced
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10), // Reduced from 12
                  border: Border.all(
                    color: AppColors.primaryColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  '${reviews.length}',
                  style: GoogleFonts.manrope(
                    color: AppColors.primaryColor,
                    fontSize: 10, // Reduced from 11
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12), // Reduced from 16

          ...reviews
              .asMap()
              .entries
              .map((entry) => _buildAnimatedReviewCard(entry.value, entry.key))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildAnimatedReviewCard(Review review, int index) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300 + (index * 100)),
      margin: const EdgeInsets.only(bottom: 8), // Reduced from 12
      padding: const EdgeInsets.all(12), // Reduced from 16
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10), // Reduced from 12
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 28, // Reduced from 32
                    height: 28, // Reduced from 32
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryColor.withOpacity(0.3),
                          AppColors.primaryColor.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(6), // Reduced from 8
                    ),
                    child: Icon(
                      Icons.person,
                      color: AppColors.primaryColor,
                      size: 14, // Reduced from 16
                    ),
                  ),
                  const SizedBox(width: 8), // Reduced from 10
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.name,
                        style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontSize: 13, // Reduced from 14
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatDate(review.date),
                        style: GoogleFonts.manrope(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 10, // Reduced from 11
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2), // Reduced
                decoration: BoxDecoration(
                  color: _getRatingColor(review.rating).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6), // Reduced from 8
                  border: Border.all(
                    color: _getRatingColor(review.rating).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      color: _getRatingColor(review.rating),
                      size: 10, // Reduced from 12
                    ),
                    const SizedBox(width: 2), // Reduced from 3
                    Text(
                      review.rating.toStringAsFixed(1),
                      style: GoogleFonts.manrope(
                        color: _getRatingColor(review.rating),
                        fontSize: 10, // Reduced from 11
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 8), // Reduced from 12
            Text(
              review.comment,
              style: GoogleFonts.manrope(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12, // Reduced from 13
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getRatingColor(double rating) {
    if (rating <= 2) return const Color(0xFFFF6B6B);
    if (rating <= 3) return const Color(0xFFFFB347);
    if (rating <= 4) return const Color(0xFF4ECDC4);
    return const Color(0xFF51CF66);
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 7) {
        return '${date.day}/${date.month}/${date.year}';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return dateString;
    }
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
