import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:iftook/features/home/presentation/screens/main_home_screen.dart';

class TinderStyleProfileCard extends StatefulWidget {
  final UserProfile profile;
  final VoidCallback? onLike;
  final VoidCallback? onDislike;

  const TinderStyleProfileCard({
    super.key,
    required this.profile,
    this.onLike,
    this.onDislike,
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
      // Swipe right - show previous image
      carouselController.previousPage();
    } else if (details.primaryVelocity! < 0 &&
        _currentImageIndex < widget.profile.imageUrls.length - 1) {
      // Swipe left - show next image
      carouselController.nextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: _handleHorizontalDrag,
      child: Container(
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
              // Image Carousel
              CarouselSlider(
                carouselController: carouselController,
                options: CarouselOptions(
                  height: double.infinity,
                  viewportFraction: 1.0,
                  enableInfiniteScroll: false,
                  onPageChanged: (index, _) {
                    setState(() => _currentImageIndex = index);
                  },
                ),
                items: widget.profile.imageUrls.map((url) {
                  return CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
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
                }).toList(),
              ),

              // Gradient overlay
              Container(
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

              // Rest of the UI components remain the same...
              Positioned(
                top: 32,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.circle,
                                color: Colors.green,
                                size: 10,
                              ),
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
                      ],
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.profile.location,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.circle, size: 4),
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
                    ),
                  ],
                ),
              ),

              // Profile Info at bottom
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Text(
                  '${widget.profile.name}, ${widget.profile.age}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 3,
                        color: Colors.black,
                      ),
                    ],
                  ),
                ),
              ),

              // Image indicators
              Positioned(
                top: 16,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children:
                      widget.profile.imageUrls.asMap().entries.map((entry) {
                    return Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: _currentImageIndex == entry.key
                            ? Colors.white
                            : Colors.white.withOpacity(0.5),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
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
  int currentIndex = 0;

  void _handleSwipe(bool isLike) {
    if (widget.profiles.isEmpty) return;

    if (widget.onSwipe != null) {
      widget.onSwipe!(widget.profiles[currentIndex], isLike);
    }

    if (isLike) {
      controller.swipe(CardSwiperDirection.right);
    } else {
      controller.swipe(CardSwiperDirection.left);
    }

    setState(() {
      // Implement looping by using modulo
      currentIndex = (currentIndex + 1) % widget.profiles.length;
    });
  }

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
          onSwipe: null, // Disable default swipe behavior
          cardBuilder: (context, index, percentThresholdX, percentThresholdY) {
            // Use a unique key based on the profile and its position in the loop
            final actualIndex = index % widget.profiles.length;
            final profile = widget.profiles[actualIndex];
            return TinderStyleProfileCard(
              key: ValueKey('${profile.hashCode}-$index'),
              profile: profile,
            );
          },
          isLoop: true, // Enable looping in CardSwiper
        ),
        // Left and Right Arrow Buttons
        Positioned.fill(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: IconButton(
                  onPressed: () => _handleSwipe(false),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
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
                  onPressed: () => _handleSwipe(true),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
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

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
