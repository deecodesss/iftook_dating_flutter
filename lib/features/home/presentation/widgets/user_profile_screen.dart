import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:iftook/features/friends/controllers/instaTalkController.dart';
import 'package:iftook/features/home/presentation/screens/main_home_screen.dart';
import 'package:iftook/features/home/presentation/screens/profile_swiper.dart';
import 'package:iftook/features/profile/data/models/user.dart';
import 'package:iftook/helpers/app_colors.dart';
import 'package:iftook/features/home/data/enums/meeting_type.dart';
import 'package:iftook/features/home/presentation/screens/schedule_meeting_screen.dart';
import 'package:iftook/features/activity/presentation/screens/activity_screen.dart';
import 'package:iftook/features/profile/presentation/screens/view_reviews_screen.dart';
import 'package:iftook/features/live/controllers/live_controller.dart';
import 'package:iftook/features/live/screens/viewer_screen.dart';
import 'package:iftook/features/wallet/controllers/wallet_controller.dart';
import 'package:iftook/features/instatalk/presentation/instatalk_schedule.dart';

import '../../../calls/presentation/screens/laoding_voice_call_screen.dart';
import '../../../calls/presentation/screens/loading_video_call_screen.dart';
import '../../../friends/presentation/screens/chat_room_screen.dart';
import '../../controllers/home_controller.dart';

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
  bool _isCheckingLiveStatus = false;
  bool _isUserLive = false;
  String? _liveStreamId;

  // Controllers - make these nullable and initialize them properly
  LiveController? _liveController;
  WalletController? _walletController;
  late HomeController _homeController;
  late InstaTalkController _instaTalkController;

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
  );

  @override
  void initState() {
    super.initState();
    // Initialize controllers safely
    _initControllers();
    _checkLiveStatus();
  }

  void _initControllers() {
    // LiveController initialization
    try {
      if (!Get.isRegistered<LiveController>()) {
        Get.put(LiveController());
      }
      _liveController = Get.find<LiveController>();
    } catch (e) {
      print('Error initializing LiveController: $e');
      // If LiveController fails to initialize, create a new instance
      _liveController = LiveController();
      Get.put(_liveController!);
    }

    // WalletController initialization
    try {
      if (!Get.isRegistered<WalletController>()) {
        Get.put(WalletController());
      }
      _walletController = Get.find<WalletController>();
    } catch (e) {
      print('Error initializing WalletController: $e');
      // If WalletController fails to initialize, create a new instance
      _walletController = WalletController();
      Get.put(_walletController!);
    }

    // HomeController initialization
    try {
      if (!Get.isRegistered<HomeController>()) {
        Get.put(HomeController());
      }
      _homeController = Get.find<HomeController>();
    } catch (e) {
      print('Error initializing HomeController: $e');
      _homeController = HomeController();
      Get.put(_homeController);
    }

    // InstaTalkController initialization
    try {
      if (!Get.isRegistered<InstaTalkController>()) {
        Get.put(InstaTalkController());
      }
      _instaTalkController = Get.find<InstaTalkController>();
    } catch (e) {
      print('Error initializing InstaTalkController: $e');
      _instaTalkController = InstaTalkController();
      Get.put(_instaTalkController);
    }
  }

  Future<void> _checkLiveStatus() async {
    if (widget.profile.sId == null || _liveController == null) return;

    setState(() => _isCheckingLiveStatus = true);

    try {
      print('Checking live status for user: ${widget.profile.sId}');
      final liveStream =
          await _liveController!.getUserActiveLiveStream(widget.profile.sId!);

      print(
          'Live stream check result: ${liveStream != null ? "LIVE" : "NOT LIVE"}');
      if (liveStream != null) {
        print('Live stream ID: ${liveStream.id}');
      }

      setState(() {
        _isUserLive = liveStream != null;
        _liveStreamId = liveStream?.id;
        _isCheckingLiveStatus = false;
      });

      // Force a UI update after a short delay to ensure it refreshes
      if (_isUserLive) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) setState(() {});
        });
      }
    } catch (e) {
      print('Error checking live status: $e');
      setState(() => _isCheckingLiveStatus = false);
    }
  }

  void _handleLiveButtonPressed() async {
    // Ensure controllers are initialized
    if (_liveController == null || _walletController == null) {
      _initControllers();
      // If still null, show error and return
      if (_liveController == null || _walletController == null) {
        Get.snackbar(
          'Error',
          'Unable to initialize required controllers',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }
    }

    if (_isCheckingLiveStatus) {
      // Show loading indicator if still checking
      Get.snackbar(
        'Please wait',
        'Checking live status...',
        backgroundColor: Colors.grey[800],
        colorText: Colors.white,
      );
      return;
    }

    // First, check if the user already has an active subscription
    final hasActiveSubscription =
        _liveController!.hasSubscription(widget.profile.sId ?? '');

    // If the user is not live streaming
    if (!_isUserLive) {
      // If already subscribed, just show a message and return
      if (hasActiveSubscription) {
        Get.snackbar(
          'Not Live',
          '${widget.profile.name} is not streaming right now. We\'ll notify you when they go live.',
          backgroundColor: Colors.grey[800],
          colorText: Colors.white,
        );
        return;
      }

      // Only offer subscription if not already subscribed
      final subscriptionPrice =
          widget.profile.earnings?.subscriptionRate ?? 700.0;

      // Check if subscription is free
      if (subscriptionPrice <= 0) {
        Get.snackbar(
          'Free Access',
          '${widget.profile.name} offers free access to their streams, but they are not live right now.',
          backgroundColor: Colors.grey[800],
          colorText: Colors.white,
        );
        return;
      }

      final subscribe = await _showSubscriptionDialog(
        message:
            '${widget.profile.name} is not streaming right now. Would you like to subscribe to get notified of future streams?',
        price: subscriptionPrice,
        hasActiveSubscription: false,
      );

      if (subscribe) {
        await _purchaseSubscription(
            widget.profile.sId ?? '', subscriptionPrice);
      }
      return;
    }

    // If they are live but we don't have their stream ID
    if (_liveStreamId == null) {
      Get.snackbar(
        'Error',
        'Could not find live stream information',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    // Try to join the live stream
    final streamData = await _liveController!.joinLiveStream(_liveStreamId!);

    if (streamData == null) {
      Get.snackbar(
        'Error',
        _liveController!.errorMessage.value,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    // If already subscribed, go directly to viewer screen
    if (hasActiveSubscription) {
      Get.to(() => ViewerScreen(
            liveStreamId: _liveStreamId!,
            streamData: streamData,
          ));
      return;
    }

    // Check if subscription is required (and price is not 0/free)
    final subscriptionPrice = streamData.containsKey('subscriptionPrice')
        ? streamData['subscriptionPrice'].toDouble()
        : (widget.profile.earnings?.subscriptionRate ?? 700.0);

    if (streamData.containsKey('subscriptionRequired') &&
        streamData['subscriptionRequired'] == true &&
        subscriptionPrice > 0) {
      final subscribe = await _showSubscriptionDialog(
        message:
            'You need to subscribe to ${widget.profile.name ?? "this creator"} to join their live stream.',
        price: subscriptionPrice,
        hasActiveSubscription: false,
      );

      if (subscribe) {
        final success = await _purchaseSubscription(
          streamData['broadcasterId'],
          subscriptionPrice,
        );

        if (success) {
          // Try joining again after subscribing
          _handleLiveButtonPressed();
        }
      }
      return;
    }

    // Navigate to viewer screen if no subscription required, price is 0, or already subscribed
    Get.to(() => ViewerScreen(
          liveStreamId: _liveStreamId!,
          streamData: streamData,
        ));
  }

  // Helper method to show subscription dialog
  Future<bool> _showSubscriptionDialog({
    required String message,
    required double price,
    required bool hasActiveSubscription,
  }) async {
    // If already subscribed, don't show dialog and return true immediately
    if (hasActiveSubscription) {
      return true;
    }

    // If price is 0, no subscription is needed
    if (price <= 0) {
      return true;
    }

    final hasEnoughBalance = _walletController!.hasEnoughBalance(price);

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
                  'Subscription price: ₹$price/month',
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
                        Get.toNamed('/wallet');
                      },
                child: Text(hasEnoughBalance ? 'Subscribe' : 'Add Funds'),
              ),
            ],
          ),
        ) ??
        false;
  }

  // Helper method for subscription purchase
  Future<bool> _purchaseSubscription(String creatorId, double amount) async {
    // If subscription is free (amount is 0), return true without charging
    if (amount <= 0) {
      return true;
    }

    final success = await _liveController!.subscribeToCreator(creatorId);

    if (success) {
      Get.snackbar(
        'Success',
        'Subscription purchased successfully',
        backgroundColor: Colors.green.withOpacity(0.8),
        colorText: Colors.white,
      );
      return true;
    } else {
      Get.snackbar(
        'Error',
        'Failed to purchase subscription: ${_liveController!.errorMessage.value}',
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
      return false;
    }
  }

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
    // For the Live button, show live indicator if the user is live
    if (label == 'Live') {
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
                      child: Icon(icon, color: color, size: 24),
                    ),
                    if (_isUserLive)
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
                    if (_isCheckingLiveStatus)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
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
              if (_isUserLive)
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

    // Default rendering for other buttons
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
              if (widget.profile.sId != null) {
                _homeController
                    .sendFriendRequest(widget.profile.sId.toString());
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
          _buildActionButtonWithLabel(
            icon: HugeIcons.strokeRoundedVideo02,
            label: 'Live',
            color: AppColors.primaryColor,
            backgroundColor: Colors.transparent,
            onPressed: _handleLiveButtonPressed,
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
                  style: const TextStyle(color: Colors.white),
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
                      setState(() => _selectedTrialOption = newValue);
                      _startInstaTalk(newValue);
                    }
                  },
                ),
        ),
      ],
    );
  }

  void _startInstaTalk(String option) async {
    if (widget.profile.sId == null) {
      Get.snackbar(
        'Error',
        'User ID not found',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    // Get the meeting type based on the selected option
    MeetingType meetingType;
    switch (option.toLowerCase()) {
      case 'chat':
        meetingType = MeetingType.chat;
        break;
      case 'call':
        meetingType = MeetingType.voice;
        break;
      case 'video':
        meetingType = MeetingType.video;
        break;
      default:
        Get.snackbar(
          'Invalid Option',
          'Please select a valid option: Chat, Call, or Video',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
    }

    // Navigate to InstaTalk scheduling screen
    Get.to(() => ScheduleInstaTalkScreen(
          participant: widget.profile,
          type: meetingType,
        ));
  }
}
