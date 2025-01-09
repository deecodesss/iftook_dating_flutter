import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:iftook/features/home/presentation/screens/main_home_screen.dart';
import 'package:iftook/features/home/presentation/screens/profile_swiper.dart';
import 'package:iftook/helpers/app_colors.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

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
  );

  @override
  Widget build(BuildContext context) {
    final List<String> imageUrls = List<String>.from(profile.imageUrls);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          profile.name as String,
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
              height: 500,
              child: TinderStyleProfileCard(
                profile: profile,
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
                        '${profile.name}, ${profile.age}',
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
                              '${profile.rating} (${profile.reviewCount})',
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
                    profile.description as String,
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
            ),
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
