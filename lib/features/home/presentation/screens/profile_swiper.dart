import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:iftook/core/services/socket_service.dart';
import 'package:iftook/features/home/controllers/home_controller.dart';
import 'package:iftook/features/profile/data/models/user.dart';
import 'package:iftook/helpers/app_colors.dart';
import 'package:iftook/features/shared/widgets/user_online_indicator.dart';
import 'package:iftook/features/shared/controllers/user_online_controller.dart';

class TinderStyleProfileCard extends StatefulWidget {
  final User profile;
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
  final HomeController _homeController = Get.find<HomeController>();

  void _handleHorizontalDrag(DragEndDetails details) {
    if (details.primaryVelocity == null) return;

    if (details.primaryVelocity! > 0 && _currentImageIndex > 0) {
      carouselController.previousPage();
    } else if (details.primaryVelocity! < 0 &&
        _currentImageIndex < widget.profile.photos!.length - 1) {
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
                  itemCount: (widget.profile.photos?.isEmpty ?? true)
                      ? 1
                      : widget.profile.photos!.length,
                  options: CarouselOptions(
                    height: double.infinity,
                    viewportFraction: 1.0,
                    enableInfiniteScroll: false,
                    onPageChanged: (index, _) {
                      setState(() => _currentImageIndex = index);
                    },
                  ),
                  itemBuilder: (context, index, _) {
                    final hasPhotos =
                        widget.profile.photos?.isNotEmpty ?? false;
                    final imageUrl = hasPhotos
                        ? widget.profile.photos![index]
                        : 'https://api.randomuser.me/portraits/${widget.profile.gender?.toLowerCase() == 'female' ? 'women' : 'men'}/${(widget.profile.sId?.hashCode ?? 0) % 70}.jpg';
                    print('Image URL: $imageUrl');
                    return CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[900],
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) => Image.network(
                        'https://api.randomuser.me/portraits/men/${DateTime.now().millisecondsSinceEpoch % 70}.jpg',
                        fit: BoxFit.cover,
                      ),
                    );
                  }),

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
          _buildUserOnlineStatus(),
          Row(
            children: [
              // Add wishlist/favorite button
              _buildWishlistButton(),
              // const SizedBox(width: 8),
              // Container(
              //   padding:
              //       const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              //   decoration: BoxDecoration(
              //     color: Colors.black.withOpacity(0.6),
              //     borderRadius: BorderRadius.circular(20),
              //   ),
              //   child: const Icon(
              //     HugeIcons.strokeRoundedStar,
              //     size: 20,
              //     color: Colors.white,
              //   ),
              // ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserOnlineStatus() {
    final userOnlineController = Get.find<UserOnlineController>();

    return StreamBuilder<bool>(
      stream:
          userOnlineController.getUserStatusStream(widget.profile.sId ?? ''),
      builder: (context, snapshot) {
        final bool isOnline = snapshot.data ?? false;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline ? Colors.green : Colors.grey,
                  boxShadow: [
                    BoxShadow(
                      color: isOnline
                          ? Colors.green.withOpacity(0.4)
                          : Colors.transparent,
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isOnline ? 'Online' : 'Offline',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWishlistButton() {
    return Obx(() {
      final isInWishlist =
          _homeController.isUserInWishlist(widget.profile.sId ?? '');
      // final Sock = SocketService().isUserOnline(widget.profile.sId ?? '');

      // Enhanced logging to track wishlist state
      print('📋 WISHLIST STATE CHECK:');
      // print('📋 ONLINE STATUS CHECK: $Sock');
      print('📋 Profile: ${widget.profile.name} (ID: ${widget.profile.sId})');
      print('📋 Is in wishlist: $isInWishlist');
      print('📋 Wishlist count: ${_homeController.wishlistUsers.length}');
      if (_homeController.wishlistUsers.isNotEmpty) {
        print(
            '📋 Wishlist IDs: ${_homeController.wishlistUsers.map((u) => u.sId).toList()}');
      }

      return GestureDetector(
        onTap: () {
          if (widget.profile.sId == null) return;

          print(
              '📋 WISHLIST BUTTON TAPPED for ${widget.profile.name} (${widget.profile.sId})');
          print('📋 Current wishlist status: $isInWishlist');

          if (isInWishlist) {
            print('📋 Removing from wishlist...');
            _homeController.removeFromWishlist(widget.profile.sId!);
          } else {
            print('📋 Adding to wishlist...');
            _homeController.addToWishlist(widget.profile.sId!);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            isInWishlist
                ? Icons.star_rounded // Filled star when wishlisted
                : HugeIcons
                    .strokeRoundedStar, // Outline star when not wishlisted
            size: 20,
            color: isInWishlist ? Colors.redAccent : Colors.white,
          ),
        ),
      );
    });
  }

  int calculateAge(String? dobString) {
    if (dobString == null || dobString.isEmpty) {
      print('DOB is null or empty for profile card');
      return 0; // Default age if DOB is missing
    }

    try {
      print('Parsing DOB in profile card: $dobString');
      final DateTime birthDate = DateTime.parse(dobString);
      final currentDate = DateTime.now();
      int age = currentDate.year - birthDate.year;
      final monthDiff = currentDate.month - birthDate.month;

      if (monthDiff < 0 ||
          (monthDiff == 0 && currentDate.day < birthDate.day)) {
        age--;
      }

      print('Successfully calculated age in profile card: $age');
      return age;
    } catch (e) {
      print('Invalid date format in profile card: "$dobString" - $e');
      return 0; // Default age if date parsing fails
    }
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
                  // Safely handle potential null values
                  '${widget.profile.name ?? "No Name"}, ${calculateAge(widget.profile.dob)}',
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
              // Safely handle potentially null location
              Row(
                children: [
                  const Icon(HugeIcons.strokeRoundedLocation01,
                      size: 18, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    widget.profile.location != null
                        ? "${widget.profile.location!.city ?? 'Unknown'}, ${widget.profile.location!.state ?? ''}"
                        : "Location unknown",
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
                    widget.profile.profession?.toString() ?? 'Not specified',
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
          children: widget.profile.photos!.asMap().entries.map((entry) {
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
  final List<User> profiles;
  final Function(User, bool)? onSwipe;
  final Function(int)? onIndexChanged; // Add this

  const ProfileSwiper({
    Key? key,
    required this.profiles,
    this.onSwipe,
    this.onIndexChanged, // Add this
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
            if (widget.onIndexChanged != null) {
              widget.onIndexChanged!(currentIndex ?? previousIndex);
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
