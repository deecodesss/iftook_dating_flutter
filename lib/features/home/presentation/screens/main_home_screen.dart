import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:iftook/core/services/api_service.dart';
import 'package:iftook/core/services/shared_prefs.dart';
import 'package:iftook/core/widgets/custom_app_bar.dart';
import 'package:iftook/features/activity/presentation/screens/activity_screen.dart';
import 'package:iftook/features/friends/controllers/instaTalkController.dart';
import 'package:iftook/features/home/presentation/screens/profile_swiper.dart';
import 'package:iftook/features/home/presentation/screens/schedule_meeting_screen.dart';
import 'package:iftook/features/home/presentation/screens/swiper_animation.dart';
import 'package:iftook/features/instatalk/presentation/instatalk_schedule.dart';
import 'package:iftook/features/live/controllers/live_controller.dart';
import 'package:iftook/features/live/screens/broadcaster_screen.dart';
import 'package:iftook/features/live/screens/live_streams_screen.dart';
import 'package:iftook/features/profile/data/models/user.dart';
import 'package:iftook/features/profile/presentation/screens/view_reviews_screen.dart';
import 'package:iftook/helpers/app_colors.dart';
import 'package:iftook/features/home/data/enums/meeting_type.dart';
import 'package:iftook/features/wallet/presentation/screens/wallet_screen.dart';
import 'package:iftook/helpers/permissions_handler.dart';

import '../../../calls/presentation/screens/laoding_voice_call_screen.dart';
import '../../../calls/presentation/screens/loading_video_call_screen.dart';
import '../../../friends/presentation/screens/chat_room_screen.dart';
import '../../../live/screens/viewer_screen.dart';
import '../../../wallet/controllers/wallet_controller.dart';
import '../../controllers/home_controller.dart';

class UserProfile {
  String name;
  int age;
  String description;
  List<String> imageUrls;
  String location;
  String profession;
  double rating;
  int reviewCount;
  List<Review> reviews;
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

  // Replace direct find with proper initialization
  late HomeController _homeController;
  late InstaTalkController _instaTalkController;
  late LiveController _liveController;

  // Add these variables to track live status
  bool _isCheckingLiveStatus = false;
  bool _isCurrentUserLive = false;
  String? _currentLiveStreamId;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _requestPermissions();
  }

  // Add this new method to request permissions when the home screen loads
  void _requestPermissions() async {
    // Request all necessary permissions
    await PermissionsHandler().requestAllPermissions();
  }

  void _initControllers() {
    // Initialize HomeController
    try {
      if (!Get.isRegistered<HomeController>()) {
        Get.put(HomeController());
      }
      _homeController = Get.find<HomeController>();

      // Add listener to check live status when current index changes
      _homeController.currentIndex.listen((index) {
        if (_homeController.profiles.isNotEmpty) {
          _checkCurrentUserLiveStatus();
        }
      });
    } catch (e) {
      print('Error initializing HomeController: $e');
      _homeController = HomeController();
      Get.put(_homeController);
    }
    try {
      if (!Get.isRegistered<InstaTalkController>()) {
        Get.put(InstaTalkController());
      }
      _instaTalkController = Get.find<InstaTalkController>();

      _instaTalkController.currentIndex.listen((index) {});
    } catch (e) {
      print('Error initializing _instaTalkController: $e');
      _instaTalkController = InstaTalkController();
      Get.put(_instaTalkController);
    }

    // Initialize LiveController
    try {
      if (!Get.isRegistered<LiveController>()) {
        Get.put(LiveController());
      }
      _liveController = Get.find<LiveController>();
    } catch (e) {
      print('Error initializing LiveController: $e');
      _liveController = LiveController();
      Get.put(_liveController);
    }
  }

  // Add method to check if current user is live
  Future<void> _checkCurrentUserLiveStatus() async {
    if (_homeController.profiles.isEmpty || _liveController == null) return;

    final currentProfile =
        _homeController.profiles[_homeController.currentIndex.value];
    if (currentProfile.sId == null) return;

    setState(() => _isCheckingLiveStatus = true);

    try {
      print('Checking live status for user: ${currentProfile.sId}');
      final liveStream =
          await _liveController.getUserActiveLiveStream(currentProfile.sId!);

      print(
          'Live stream check result: ${liveStream != null ? "LIVE" : "NOT LIVE"}');
      if (liveStream != null) {
        print('Live stream ID: ${liveStream.id}');
      }

      setState(() {
        _isCurrentUserLive = liveStream != null;
        _currentLiveStreamId = liveStream?.id;
        _isCheckingLiveStatus = false;
      });
    } catch (e) {
      print('Error checking live status: $e');
      setState(() => _isCheckingLiveStatus = false);
    }
  }

  // Method to handle joining a live stream directly - update this method
  void _handleJoinLiveStream() async {
    if (!_isCurrentUserLive || _currentLiveStreamId == null) {
      // If not live, show live streams list instead
      _handleLiveButton();
      return;
    }

    final currentProfile =
        _homeController.profiles[_homeController.currentIndex.value];

    // Check if user already has a subscription
    final hasActiveSubscription =
        _liveController.hasSubscription(currentProfile.sId ?? '');

    // Try to join live stream
    final streamData =
        await _liveController.joinLiveStream(_currentLiveStreamId!);

    if (streamData == null) {
      Get.snackbar(
        'Error',
        _liveController.errorMessage.value,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      return;
    }

    // If already subscribed, go directly to viewer screen
    if (hasActiveSubscription) {
      Get.to(() => ViewerScreen(
            liveStreamId: _currentLiveStreamId!,
            streamData: streamData,
          ));
      return;
    }

    // Check if subscription is required
    if (streamData.containsKey('subscriptionRequired') &&
        streamData['subscriptionRequired'] == true) {
      // Get subscription price from stream data or profile
      final subscriptionPrice = streamData.containsKey('subscriptionPrice')
          ? streamData['subscriptionPrice'].toDouble()
          : (currentProfile.earnings?.subscriptionRate ?? 700.0);

      final walletController = Get.find<WalletController>();
      final hasEnoughBalance =
          walletController.hasEnoughBalance(subscriptionPrice);

      final subscribe = await _showSubscriptionDialog(
          message:
              'You need to subscribe to ${currentProfile.name} to join this live stream.',
          price: subscriptionPrice,
          hasEnoughBalance: hasEnoughBalance);

      if (subscribe) {
        final success = await _liveController.subscribeToCreator(
          streamData['broadcasterId'],
        );

        if (success) {
          // Try joining again after subscribing
          _handleJoinLiveStream();
        }
      }
      return;
    }

    // Navigate to viewer screen if no subscription required
    Get.to(() => ViewerScreen(
          liveStreamId: _currentLiveStreamId!,
          streamData: streamData,
        ));
  }

  // Add helper method to show subscription dialog (same as in profile screen)
  Future<bool> _showSubscriptionDialog({
    required String message,
    required double price,
    required bool hasEnoughBalance,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: const Text(
              'Subscription Required',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Text(
                  'Subscription price: ₹${price.toStringAsFixed(0)}/month',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (!hasEnoughBalance)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Insufficient wallet balance. Please add funds.',
                            style:
                                TextStyle(color: Colors.red[300], fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: hasEnoughBalance
                    ? () => Navigator.pop(context, true)
                    : () {
                        Navigator.pop(context, false);
                        Get.to(() => const WalletScreen());
                      },
                child: Text(hasEnoughBalance ? 'Subscribe' : 'Add Funds'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(() {
        if (_homeController.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        } else if (_homeController.profiles.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_search, size: 64, color: Colors.grey[600]),
                const SizedBox(height: 16),
                Text(
                  'No Profiles Found',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                if (_homeController.selectedCountry.value != 'All')
                  Text(
                    'Try selecting a different country',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          );
        } else {
          return Column(
            children: [
              CustomAppBar(),
              Expanded(
                child: ProfileSwiper(
                  profiles: _homeController.profiles,
                  onSwipe: (profile, isLike) {
                    // Handle swipe if needed
                  },
                  onIndexChanged: (index) {
                    if (index >= 0 && index < _homeController.profiles.length) {
                      _currentProfileIndex = index;
                      _homeController.updateCurrentIndex(index);
                    }
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
          );
        }
      }),
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
              if (_homeController.profiles.isNotEmpty) {
                final currentProfile =
                    _homeController.profiles[_currentProfileIndex];
                Get.to(() => ViewReviewsScreen(userId: currentProfile.sId!));
              }
            },
            showRating: false,
          ),
          _buildActionButtonWithLabel(
            icon: HugeIcons.strokeRoundedInLove,
            label: 'Interested\nin Friendship',
            color: AppColors.primaryColor,
            backgroundColor: Colors.transparent,
            onPressed: () {
              if (_homeController.profiles.isNotEmpty) {
                final currentProfile =
                    _homeController.profiles[_currentProfileIndex];
                _homeController
                    .sendFriendRequest(currentProfile.sId.toString());
              }
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
          _buildActionButtonWithLiveStatus(
            icon: HugeIcons.strokeRoundedVideo02,
            label: 'Live',
            color: AppColors.primaryColor,
            backgroundColor: Colors.transparent,
            onPressed:
                _isCurrentUserLive ? _handleJoinLiveStream : _handleLiveButton,
            isLive: _isCurrentUserLive,
            isChecking: _isCheckingLiveStatus,
          ),
        ],
      ),
    );
  }

  // Widget for live button with status indicator
  Widget _buildActionButtonWithLiveStatus({
    required IconData icon,
    required String label,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onPressed,
    bool isLive = false,
    bool isChecking = false,
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
              child: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isLive
                          ? Colors.red.withOpacity(0.2)
                          : backgroundColor,
                      gradient: isLive
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.red.withOpacity(0.3),
                                Colors.red.withOpacity(0.1),
                              ],
                            )
                          : null,
                    ),
                    child: Icon(icon,
                        color: isLive ? Colors.red : color, size: 24),
                  ),
                  if (isLive)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  if (isChecking)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: SizedBox(
                        width: 12,
                        height: 12,
                        // child: CircularProgressIndicator(
                        //   strokeWidth: 2,
                        //   valueColor:
                        //       AlwaysStoppedAnimation<Color>(Colors.white),
                        // ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isLive)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildServiceButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Obx(() {
        final currentProfile = _homeController.profiles.isEmpty
            ? null
            : _homeController.profiles[_homeController.currentIndex.value];
        final earnings = currentProfile?.earnings;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildServiceButton(
              icon: HugeIcons.strokeRoundedComment01,
              label: 'Chat\n₹${earnings?.chatRate.toInt() ?? 150}/ 30m',
              onTap: () => _navigateToSchedule(MeetingType.chat),
            ),
            _buildServiceButton(
              icon: HugeIcons.strokeRoundedCall02,
              label: 'Call\n₹${earnings?.voiceRate.toInt() ?? 300}/ 30m',
              onTap: () => _navigateToSchedule(MeetingType.voice),
            ),
            _buildServiceButton(
              icon: HugeIcons.strokeRoundedVideo01,
              label: 'Video\n₹${earnings?.videoRate.toInt() ?? 450}/ 30m',
              onTap: () => _navigateToSchedule(MeetingType.video),
            ),
            _buildTrialDropdown(),
          ],
        );
      }),
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
        mainAxisSize: MainAxisSize.min,
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

  Widget _buildTrialDropdown() {
    return Column(
      children: [
        const Text(
          'Insta Talk',
          style: TextStyle(color: AppColors.primaryColor),
        ),
        Obx(
          () => _homeController.isInstaTalkLoading.value
              ? SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryColor,
                  ),
                )
              : DropdownButton<String>(
                  value: _selectedTrialOption,
                  dropdownColor: const Color(0xFF1E1E1E),
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  underline: Container(
                    height: 1,
                    color: Colors.grey[700],
                  ),
                  items: ['Chat', 'Call', 'Video'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null &&
                        !_homeController.isInstaTalkLoading.value) {
                      // Only update the selected option, don't trigger setState
                      _selectedTrialOption = newValue;
                      MeetingType value = newValue == 'Chat'
                          ? MeetingType.chat
                          : newValue == 'Call'
                              ? MeetingType.voice
                              : MeetingType.video;

                      final currentProfile =
                          _homeController.profiles[_currentProfileIndex];
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ScheduleInstaTalkScreen(
                                participant: currentProfile!, type: value)),
                      );

                      // Call InstaTalk without causing a rebuild
                      // _startInstaTalk(newValue);
                    }
                  },
                ),
        ),
      ],
    );
  }

  // void _startInstaTalk(String option) async {
  //   if (_homeController.profiles.isEmpty) return;

  //   final currentProfile = _homeController.profiles[_currentProfileIndex];
  //   final walletController = Get.find<WalletController>();

  //   // Get the InstaTalk type based on the selected option
  //   String instaTalkType;
  //   switch (option.toLowerCase()) {
  //     case 'chat':
  //       instaTalkType = 'chat';
  //       break;
  //     case 'call':
  //       instaTalkType = 'voice';
  //       break;
  //     case 'video':
  //       instaTalkType = 'video';
  //       break;
  //     default:
  //       Get.snackbar(
  //         'Invalid Option',
  //         'Please select a valid option: Chat, Call, or Video',
  //         backgroundColor: Colors.red,
  //         colorText: Colors.white,
  //       );
  //       return;
  //   }

  //   // Check if InstaTalk was previously used
  //   final hasUsedInstaTalk = await ApiService.checkIfTrialUsed(
  //       currentProfile.sId!,
  //       SharedPrefs.getUserIdSharedPreference().toString());

  //   if (hasUsedInstaTalk == true) {
  //     // Get live rate from profile
  //     final liveRate = currentProfile.earnings?.liveRate ?? 500.0;
  //     final hasEnoughBalance = walletController.hasEnoughBalance(liveRate);

  //     // Show payment confirmation dialog
  //     final shouldProceed = await showDialog<bool>(
  //           context: context,
  //           builder: (context) => AlertDialog(
  //             backgroundColor: const Color(0xFF1A1A1A),
  //             title: const Text('Payment Required',
  //                 style: TextStyle(color: Colors.white)),
  //             content: Column(
  //               mainAxisSize: MainAxisSize.min,
  //               children: [
  //                 Text(
  //                   'You have already used your free InstaTalk with this user. You need to pay ₹${liveRate.toInt()} to continue.',
  //                   style: const TextStyle(color: Colors.white70),
  //                 ),
  //                 if (!hasEnoughBalance) ...[
  //                   const SizedBox(height: 16),
  //                   Container(
  //                     padding: const EdgeInsets.all(8),
  //                     decoration: BoxDecoration(
  //                       color: Colors.red.withOpacity(0.1),
  //                       borderRadius: BorderRadius.circular(8),
  //                       border: Border.all(color: Colors.red.withOpacity(0.5)),
  //                     ),
  //                     child: const Text(
  //                       'Insufficient wallet balance. Please add funds.',
  //                       style: TextStyle(color: Colors.red),
  //                     ),
  //                   ),
  //                 ],
  //               ],
  //             ),
  //             actions: [
  //               TextButton(
  //                 onPressed: () => Navigator.pop(context, false),
  //                 child: const Text('Cancel'),
  //               ),
  //               ElevatedButton(
  //                 style: ElevatedButton.styleFrom(
  //                   backgroundColor: AppColors.primaryColor,
  //                   foregroundColor: Colors.white,
  //                 ),
  //                 onPressed: hasEnoughBalance
  //                     ? () => Navigator.pop(context, true)
  //                     : () {
  //                         Navigator.pop(context, false);
  //                         Get.to(() => const WalletScreen());
  //                       },
  //                 child:
  //                     Text(hasEnoughBalance ? 'Pay & Continue' : 'Add Funds'),
  //               ),
  //             ],
  //           ),
  //         ) ??
  //         false;

  //     if (!shouldProceed) return;

  //     // Process payment
  //     final paymentSuccess = await _instaTalkController.processInstaTalkPayment(
  //       userId: currentProfile.sId!,
  //       amount: liveRate,
  //     );

  //     if (!paymentSuccess) {
  //       Get.snackbar(
  //         'Payment Failed',
  //         'Unable to process payment. Please try again.',
  //         backgroundColor: Colors.red,
  //         colorText: Colors.white,
  //       );
  //       return;
  //     }
  //   }

  //   // Create InstaTalk request
  //   final result = await _instaTalkController.createInstaTalk(
  //       currentProfile.sId!, instaTalkType);

  //   if (result == null) return;

  //   Get.snackbar(
  //     'InstaTalk Request Sent',
  //     '${currentProfile.name} will need to accept your request',
  //     backgroundColor: Colors.green.withOpacity(0.8),
  //     colorText: Colors.white,
  //     duration: const Duration(seconds: 3),
  //   );
  // }

  void _handleGoLive() async {
    // Create controllers to capture input
    final titleController = TextEditingController(text: 'My Live Stream');
    final descriptionController = TextEditingController();

    // Show dialog to enter title and description
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Start Live Stream',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Title',
                labelStyle: TextStyle(color: Colors.grey[400]),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primaryColor),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                labelStyle: TextStyle(color: Colors.grey[400]),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primaryColor),
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(context, {
                'title': titleController.text.isNotEmpty
                    ? titleController.text
                    : 'My Live Stream',
                'description': descriptionController.text,
              });
            },
            child: const Text(
              'Start',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (result != null) {
      final liveStream = await _liveController.startLiveStream(
        title: result['title'] ?? 'My Live Stream',
        description: result['description'] ?? '',
      );

      if (liveStream != null) {
        Get.to(() => BroadcasterScreen(liveStream: liveStream));
      } else {
        Get.snackbar(
          'Error',
          _liveController.errorMessage.value,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }

    // Dispose controllers to prevent memory leaks
    titleController.dispose();
    descriptionController.dispose();
  }

  void _handleViewLiveStreams() {
    Get.to(() => const LiveStreamsScreen());
  }

  // Update the live button handling method to match profile screen
  void _handleLiveButton() {
    final currentProfile = _homeController.profiles.isEmpty
        ? null
        : _homeController.profiles[_homeController.currentIndex.value];

    // If current profile is live, handle joining that stream
    if (_isCurrentUserLive &&
        _currentLiveStreamId != null &&
        currentProfile != null) {
      _handleJoinLiveStream();
      return;
    }

    // Otherwise show options dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Live Streaming',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.live_tv, color: AppColors.primaryColor),
              title: const Text('Start a Live Stream',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _handleGoLive();
              },
            ),
            const Divider(color: Colors.grey),
            ListTile(
              leading: const Icon(Icons.ondemand_video,
                  color: AppColors.primaryColor),
              title: const Text('View Live Streams',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _handleViewLiveStreams();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _navigateToSchedule(MeetingType type) {
    if (_homeController.profiles.isEmpty) return;
    final currentProfile = _homeController.profiles[_currentProfileIndex];
    print(
        'Navigating to schedule with user earnings: ${currentProfile.earnings?.toJson()}');
    print('User wallet balance: ${currentProfile.walletBalance}');

    // Check if earnings exist
    if (currentProfile.earnings == null) {
      print('Warning: User has no earnings set, using defaults');
    }

    Get.to(() => ScheduleMeetingScreen(
          participant: currentProfile,
          type: type,
        ));
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }
}
