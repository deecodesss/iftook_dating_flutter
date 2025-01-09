import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:iftook/features/home/presentation/screens/main_home_screen.dart';

class TinderStyleProfileCard extends StatefulWidget {
  final UserProfile profile;
  final VoidCallback? onLike;
  final VoidCallback? onDislike;
  final double? percentThresholdX;
  final bool isProfileScreen;

  const TinderStyleProfileCard({
    super.key,
    required this.profile,
    this.onLike,
    this.onDislike,
    this.isProfileScreen = false,
    this.percentThresholdX,
  });

  @override
  State<TinderStyleProfileCard> createState() => _TinderStyleProfileCardState();
}

class _TinderStyleProfileCardState extends State<TinderStyleProfileCard> {
  int _currentImageIndex = 0;
  final CarouselSliderController carouselController =
      CarouselSliderController();

  void _handleHorizontalDrag(DragEndDetails details) {
    if (details.primaryVelocity == null) return;

    if (details.primaryVelocity! > 0 && _currentImageIndex > 0) {
      carouselController.previousPage();
    } else if (details.primaryVelocity! < 0 &&
        _currentImageIndex < widget.profile.imageUrls.length - 1) {
      carouselController.nextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate the opacity based on the swipe threshold
    final swipeOpacity = widget.percentThresholdX != null
        ? (1 - widget.percentThresholdX!.abs() * 0.8).clamp(0.0, 1.0)
        : 1.0;

    return GestureDetector(
      onHorizontalDragEnd: _handleHorizontalDrag,
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Full width image carousel
              CarouselSlider.builder(
                carouselController: carouselController,
                itemCount: widget.profile.imageUrls.length,
                options: CarouselOptions(
                  height: double.infinity,
                  viewportFraction: 1.0,
                  enableInfiniteScroll: false,
                  onPageChanged: (index, _) {
                    setState(() => _currentImageIndex = index);
                  },
                ),
                itemBuilder: (context, index, _) {
                  return CachedNetworkImage(
                    imageUrl: widget.profile.imageUrls[index],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[900],
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[900],
                      child: const Icon(Icons.error),
                    ),
                  );
                },
              ),

              // Gradient overlay with fade animation
              Opacity(
                opacity: swipeOpacity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.4),
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                      stops: const [0.0, 0.2, 0.8],
                    ),
                  ),
                ),
              ),

              // Profile info with fade animation
              Opacity(
                opacity: swipeOpacity,
                child: Column(
                  children: [
                    // Top section
                    _buildTopSection(),
                    const Spacer(),
                    // Bottom section
                    _buildBottomSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.circle, color: Colors.green, size: 10),
                SizedBox(width: 6),
                Text(
                  'Online',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              HugeIcons.strokeRoundedStar,
              size: 20,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.isProfileScreen)
                Text(
                  '${widget.profile.name}, ${widget.profile.age}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(offset: Offset(0, 1), blurRadius: 3),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(HugeIcons.strokeRoundedLocation01,
                      size: 18, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    widget.profile.location,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.work_outline_rounded,
                      size: 18, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    widget.profile.profession,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Image indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: widget.profile.imageUrls.asMap().entries.map((entry) {
            return Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentImageIndex == entry.key
                    ? Colors.white
                    : Colors.white.withOpacity(0.5),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class ProfileSwiper extends StatefulWidget {
  final List<UserProfile> profiles;
  final Function(UserProfile, bool)? onSwipe;

  const ProfileSwiper({
    Key? key,
    required this.profiles,
    this.onSwipe,
  }) : super(key: key);

  @override
  State<ProfileSwiper> createState() => _ProfileSwiperState();
}

class _ProfileSwiperState extends State<ProfileSwiper> {
  final CardSwiperController controller = CardSwiperController();

  @override
  Widget build(BuildContext context) {
    if (widget.profiles.isEmpty) {
      return const Center(child: Text('No profiles available'));
    }

    return Stack(
      children: [
        CardSwiper(
          controller: controller,
          cardsCount: widget.profiles.length,
          numberOfCardsDisplayed: 1,
          backCardOffset: const Offset(0, 40),
          padding: EdgeInsets.zero,
          threshold: 50,
          scale: 0.95,
          isLoop: true,
          onSwipe: (previousIndex, currentIndex, direction) {
            if (widget.onSwipe != null) {
              widget.onSwipe!(
                widget.profiles[previousIndex],
                direction == CardSwiperDirection.right,
              );
            }
            return true;
          },
          cardBuilder: (context, index, percentThresholdX, percentThresholdY) {
            final profile = widget.profiles[index % widget.profiles.length];
            return TinderStyleProfileCard(
              key: ValueKey(profile.hashCode),
              profile: profile,
              percentThresholdX: percentThresholdX.toDouble(),
            );
          },
        ),
        Positioned.fill(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: IconButton(
                  onPressed: () => controller.swipe(CardSwiperDirection.left),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.keyboard_double_arrow_left_rounded,
                      color: Colors.black54,
                      size: 30,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: IconButton(
                  onPressed: () => controller.swipe(CardSwiperDirection.right),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.keyboard_double_arrow_right_rounded,
                      color: Colors.black54,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
