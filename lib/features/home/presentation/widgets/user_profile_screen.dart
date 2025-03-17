import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:iftook/features/home/presentation/screens/main_home_screen.dart';
import 'package:iftook/features/home/presentation/screens/profile_swiper.dart';
import 'package:iftook/features/profile/data/models/user.dart';
import 'package:iftook/helpers/app_colors.dart';
import 'package:iftook/features/home/data/enums/meeting_type.dart';
import 'package:iftook/features/home/presentation/screens/schedule_meeting_screen.dart';
import 'package:iftook/features/activity/presentation/screens/activity_screen.dart';
import 'package:iftook/features/profile/presentation/screens/view_reviews_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final User profile;
  const UserProfileScreen({super.key, required this.profile});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  int _currentImageIndex = 0;
  final CarouselSliderController _carouselController =
      CarouselSliderController();
  String _selectedTrialOption = 'Chat';

  // Static profile data with proper typing
  UserProfile profile = UserProfile(
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
    // reviews: [
    //   Review(
    //       name: "John D.",
    //       comment: "Great conversation, very friendly and engaging!",
    //       rating: 5,
    //       date: "2 days ago"),
    //   Review(
    //       name: "Mike R.",
    //       comment: "Helpful and professional, would recommend.",
    //       rating: 4,
    //       date: "1 week ago"),
    // ],
  );
  int calculateAge(DateTime birthDate) {
    final currentDate = DateTime.now();
    int age = currentDate.year - birthDate.year;
    final monthDiff = currentDate.month - birthDate.month;

    if (monthDiff < 0 || (monthDiff == 0 && currentDate.day < birthDate.day)) {
      age--;
    }

    return age;
  }

  void _navigateToSchedule(MeetingType type) {
    Get.to(() => ScheduleMeetingScreen(
          participant: widget.profile,
          type: type,
        ));
  }

  double getCurrentRate(MeetingType type, Earnings? earnings) {
    if (earnings == null) {
      return type == MeetingType.chat
          ? 150
          : type == MeetingType.voice
              ? 300
              : 450;
    }
    return type == MeetingType.chat
        ? earnings.chat.toDouble()
        : type == MeetingType.voice
            ? earnings.voice.toDouble()
            : earnings.video.toDouble();
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

  Widget _buildActionButtonsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActionButtonWithLabel(
            icon: HugeIcons.strokeRoundedDiamond02,
            label: 'Rating\nand Review',
            color: AppColors.primaryColor,
            backgroundColor: Colors.transparent,
            onPressed: () {
              Get.to(() => ViewReviewsScreen(userId: widget.profile.sId!));
            },
            showRating: false,
          ),
          _buildActionButtonWithLabel(
            icon: HugeIcons.strokeRoundedInLove,
            label: 'Interested\nin Friendship',
            color: AppColors.primaryColor,
            backgroundColor: Colors.transparent,
            onPressed: () {
              // TODO: Implement friend request functionality
              // _homeController.sendFriendRequest(widget.profile.sId.toString());
            },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.profile.name as String,
          style: const TextStyle(color: Colors.white),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Carousel
            SizedBox(
              height: 450,
              child: TinderStyleProfileCard(
                profile: widget.profile,
                isProfileScreen:
                    true, // New parameter to adjust UI for profile screen
              ),
            ),
            // Profile Info
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${widget.profile.name}, ${calculateAge(DateTime.parse(widget.profile.dob.toString()))}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              // Changed this section to use widget.profile instead of profile
                              '${widget.profile.averageRating?.toStringAsFixed(1) ?? '0.0'} (${widget.profile.reviews ?? 0})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.profile.about as String,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[300],
                    ),
                  ),
                ],
              ),
            ),
            // Service Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildServiceButton(
                    icon: HugeIcons.strokeRoundedComment01,
                    label:
                        'Chat\n₹${widget.profile.earnings?.chatRate.toInt() ?? 150}/30min',
                    onTap: () => _navigateToSchedule(MeetingType.chat),
                  ),
                  _buildServiceButton(
                    icon: HugeIcons.strokeRoundedCall02,
                    label:
                        'Call\n₹${widget.profile.earnings?.voiceRate.toInt() ?? 300}/30min',
                    onTap: () => _navigateToSchedule(MeetingType.voice),
                  ),
                  _buildServiceButton(
                    icon: HugeIcons.strokeRoundedVideo01,
                    label:
                        'Video\n₹${widget.profile.earnings?.videoRate.toInt() ?? 450}/30min',
                    onTap: () => _navigateToSchedule(MeetingType.video),
                  ),
                  _buildTrialDropdown(),
                ],
              ),
            ),
            // Add Action Buttons Section
            _buildActionButtonsRow(),
          ],
        ),
      ),
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
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
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
}
