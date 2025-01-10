import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:iftook/core/widgets/custom_app_bar.dart';
import 'package:iftook/features/activity/presentation/screens/activity_screen.dart';
import 'package:iftook/features/home/presentation/screens/profile_swiper.dart';
import 'package:iftook/features/home/presentation/screens/swiper_animation.dart';
import 'package:iftook/helpers/app_colors.dart';

class UserProfile {
  final String name;
  final int age;
  final String description;
  final List<String> imageUrls;
  final String location;
  final String profession;
  final double rating;
  final int reviewCount;
  final List<Review> reviews;
  int likes;
  int dislikes;

  UserProfile({
    required this.name,
    required this.age,
    required this.description,
    required this.imageUrls,
    required this.location,
    required this.profession,
    this.rating = 4.5,
    this.reviewCount = 128,
    this.likes = 2300,
    this.dislikes = 23,
    this.reviews = const [],
  });

  // Helper methods to format likes/dislikes
  String get formattedLikes => _formatCount(likes!);
  String get formattedDislikes => _formatCount(dislikes!);

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

class Review {
  final String name;
  final String comment;
  final double rating;
  final String date;

  Review({
    required this.name,
    required this.comment,
    required this.rating,
    required this.date,
  });
}

class ProfileImageContainer extends StatelessWidget {
  final String imageUrl;
  final double height;
  final BorderRadius borderRadius;

  const ProfileImageContainer({
    Key? key,
    required this.imageUrl,
    this.height = 400,
    this.borderRadius = const BorderRadius.all(Radius.circular(15)),
  }) : super(key: key);

  String get _optimizedImageUrl => '$imageUrl?w=800&q=80';

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: Colors.grey[900],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: CachedNetworkImage(
          imageUrl: _optimizedImageUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Center(
            child: CircularProgressIndicator(
              color: AppColors.primaryColor,
            ),
          ),
          errorWidget: (context, url, error) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.red[400], size: 32),
                const SizedBox(height: 8),
                Text(
                  'Image not available',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _currentImageIndex = 0;
  String _selectedCountry = 'India';
  String _selectedTrialOption = 'Chat';
  int _currentProfileIndex = 0;
  final carouselController = CarouselSliderController();
  PageController pageController = PageController();
  double _dragPosition = 0;
  double _angle = 0;
  bool _isDragging = false;
  final double _swipeThreshold = 100;
  final AppinioSwiperController _swiperController = AppinioSwiperController();

  final List<UserProfile> _profiles = [
    UserProfile(
      name: 'Sarah',
      age: 25,
      description: 'Professional model and fitness enthusiast',
      imageUrls: [
        'https://images.unsplash.com/photo-1494790108377-be9c29b29330',
        'https://images.unsplash.com/photo-1524504388940-b1c1722653e1',
        'https://images.unsplash.com/photo-1517841905240-472988babdf9'
      ],
      location: 'Mumbai',
      profession: 'Model',
      rating: 4.8,
      reviewCount: 156,
      reviews: [
        Review(
            name: "John D.",
            comment: "Great conversation, very friendly and engaging!",
            rating: 5,
            date: "2 days ago"),
        Review(
            name: "Mike R.",
            comment: "Helpful and professional, would recommend.",
            rating: 4,
            date: "1 week ago"),
      ],
    ),
    UserProfile(
      name: 'Emma',
      age: 23,
      description: 'Travel blogger | Coffee lover',
      imageUrls: [
        'https://images.unsplash.com/photo-1524250502761-1ac6f2e30d43',
        'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e',
        'https://images.unsplash.com/photo-1535324492437-d8dea70a38a7'
      ],
      location: 'Delhi',
      profession: 'Blogger',
      rating: 4.8,
      reviewCount: 156,
      reviews: [
        Review(
            name: "John D.",
            comment: "Great conversation, very friendly and engaging!",
            rating: 5,
            date: "2 days ago"),
        Review(
            name: "Mike R.",
            comment: "Helpful and professional, would recommend.",
            rating: 4,
            date: "1 week ago"),
      ],
    ),
    UserProfile(
      name: 'Priya',
      age: 24,
      description: 'Software Engineer | Music enthusiast',
      imageUrls: [
        'https://images.unsplash.com/photo-1531746020798-e6953c6e8e04',
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
        'https://images.unsplash.com/photo-1526510747491-58f928ec870f'
      ],
      location: 'Bangalore',
      profession: 'Engineer',
      rating: 4.8,
      reviewCount: 156,
      reviews: [
        Review(
            name: "John D.",
            comment: "Great conversation, very friendly and engaging!",
            rating: 5,
            date: "2 days ago"),
        Review(
            name: "Mike R.",
            comment: "Helpful and professional, would recommend.",
            rating: 4,
            date: "1 week ago"),
      ],
    ),
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // App Bar
          CustomAppBar(
              selectedCountry: _selectedCountry,
              countries: ['India', 'USA'],
              onCountryChanged: (value) {
                setState(() => _selectedCountry = value!);
              }),
          // Profile Swiper - Takes all available space
          Expanded(
            child: ProfileSwiper(
              profiles: _profiles,
              onSwipe: (profile, isLike) {
                print('${profile.name} was ${isLike ? 'liked' : 'disliked'}');
              },
            ),
          ),

          // Bottom Section - Service and Action buttons
          Container(
            padding: const EdgeInsets.only(bottom: 16, top: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Service Buttons
                _buildServiceButtons(),
                const SizedBox(height: 16),
                // Action Buttons
                _buildActionButtonsRow(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtonsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActionButtonWithLabel(
            icon: HugeIcons.strokeRoundedStar,
            label: 'Rating\nand Review',
            color: AppColors.primaryColor,
            backgroundColor: Colors.transparent,
            onPressed: () {},
            showRating: false,
          ),
          _buildActionButtonWithLabel(
            icon: HugeIcons.strokeRoundedInLove,
            label: 'Interested\nin Dating',
            color: AppColors.primaryColor,
            backgroundColor: Colors.transparent,
            onPressed: () {},
          ),
          _buildActionButtonWithLabel(
            icon: HugeIcons.strokeRoundedActivity01,
            label: 'Activity',
            color: AppColors.primaryColor,
            backgroundColor: Colors.transparent,
            onPressed: () {
              Get.to(() => ActivityScreen());
            },
          ),
          _buildActionButtonWithLabel(
            icon: HugeIcons.strokeRoundedVideo02,
            label: 'Live',
            color: AppColors.primaryColor,
            backgroundColor: Colors.transparent,
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtonWithLabel({
    required IconData icon,
    required String label,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onPressed,
    bool showRating = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: backgroundColor.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: backgroundColor.withOpacity(0.2),
                spreadRadius: -1,
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: onPressed,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: backgroundColor,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      backgroundColor.withOpacity(0.9),
                      backgroundColor,
                    ],
                  ),
                ),
                child: showRating
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, color: color, size: 24),
                          const Text(
                            '4.5',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Icon(icon, color: color, size: 24),
              ),
            ),
          ),
        ),
        // const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onPressed,
    bool showRating = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: backgroundColor.withOpacity(0.2),
            spreadRadius: -1,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: backgroundColor,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  backgroundColor.withOpacity(0.9),
                  backgroundColor,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: backgroundColor.withOpacity(0.15),
                  spreadRadius: 1,
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: showRating
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: color, size: 24),
                      const SizedBox(width: 4),
                      const Text(
                        '4.5',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 2,
                              color: Colors.black26,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Icon(icon, color: color, size: 24),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewSection(UserProfile profile) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 24),
              const SizedBox(width: 8),
              Text(
                '${profile.rating}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationArrows() {
    return Positioned(
      top: 0,
      bottom: 0,
      left: 0,
      right: 0,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                onPressed: () {
                  if (_currentProfileIndex > 0) {
                    pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                onPressed: () {
                  if (_currentProfileIndex < _profiles.length - 1) {
                    pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBioSection(UserProfile profile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${profile.name}, ${profile.age}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            profile.description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  void _handleNavigation(bool isPrevious) {
    final profile = _profiles[_currentProfileIndex];
    if (isPrevious) {
      if (_currentImageIndex > 0) {
        carouselController.previousPage();
      } else if (_currentProfileIndex > 0) {
        pageController.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      if (_currentImageIndex < profile.imageUrls.length - 1) {
        carouselController.nextPage();
      } else if (_currentProfileIndex < _profiles.length - 1) {
        pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  Widget _buildServiceButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildServiceButton(
            icon: HugeIcons.strokeRoundedComment01,
            label: 'Chat\n₹100/30min',
            onTap: () {},
          ),
          _buildServiceButton(
            icon: HugeIcons.strokeRoundedCall02,
            label: 'Call\n₹300/30min',
            onTap: () {},
          ),
          _buildServiceButton(
            icon: HugeIcons.strokeRoundedVideo01,
            label: 'Video\n₹400/30min',
            onTap: () {},
          ),
          _buildTrialDropdown(),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Reviews Button
          IconButton(
            onPressed: () {},
            icon: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, color: Colors.amber, size: 24),
                SizedBox(width: 4),
                Text(
                  '4.5',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey[900],
              padding: const EdgeInsets.all(12),
              shape: const CircleBorder(),
            ),
          ),

          // Dating Interest Button
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.favorite,
              color: Colors.white,
              size: 24,
            ),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              padding: const EdgeInsets.all(12),
              shape: const CircleBorder(),
            ),
          ),

          // Activity/Profile Button
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.person_outline,
              color: AppColors.primaryColor,
              size: 24,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey[900],
              padding: const EdgeInsets.all(12),
              shape: const CircleBorder(),
            ),
          ),

          // Live Button
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.videocam,
              color: Colors.white,
              size: 24,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.all(12),
              shape: const CircleBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          // padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: const Text(
          'Live - Free on Subscribe & Watch',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildCountryDropdown() {
    return DropdownButton<String>(
      value: _selectedCountry,
      dropdownColor: const Color(0xFF1E1E1E),
      style: const TextStyle(color: Colors.white),
      items: ['India', 'USA', 'UK'].map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Row(
            children: [
              Text(value),
              const SizedBox(width: 8),
              const Icon(Icons.language, color: Colors.white),
            ],
          ),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() => _selectedCountry = newValue!);
      },
    );
  }

  Widget _buildTrialDropdown() {
    return Column(
      children: [
        const Text(
          'Free Trial',
          style: TextStyle(color: AppColors.primaryColor),
        ),
        DropdownButton<String>(
          value: _selectedTrialOption,
          dropdownColor: const Color(0xFF1E1E1E),
          style: const TextStyle(color: Colors.white),
          items: ['Chat', 'Call', 'Video'].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() => _selectedTrialOption = newValue!);
          },
        ),
      ],
    );
  }

  Widget _buildServiceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 24, color: AppColors.primaryColor),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationBadge(UserProfile profile) {
    return Positioned(
      top: 16,
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${profile.location} • ${profile.profession}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildImageIndicators(UserProfile profile) {
    return Positioned(
      bottom: 16,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: profile.imageUrls.asMap().entries.map((entry) {
          return Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _currentImageIndex == entry.key
                  ? AppColors.primaryColor
                  : Colors.grey[600],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProfileIndicators() {
    return Positioned(
      bottom: 30,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _profiles.asMap().entries.map((entry) {
          return Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _currentProfileIndex == entry.key
                  ? AppColors.primaryColor
                  : Colors.grey[600],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }
}
