import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:iftook/core/services/api_service.dart';
import 'package:iftook/core/services/shared_prefs.dart';
import 'package:iftook/features/friends/controllers/instaTalkController.dart';
import 'package:iftook/features/home/controllers/home_controller.dart'; // Add HomeController import
import 'package:iftook/features/home/presentation/widgets/user_profile_screen.dart';
import 'package:iftook/features/instatalk/presentation/instatalk_schedule.dart';
import 'package:iftook/features/profile/data/models/user.dart';
import 'package:iftook/helpers/app_colors.dart';

import '../../../calls/presentation/screens/laoding_voice_call_screen.dart';
import '../../../calls/presentation/screens/loading_video_call_screen.dart';
import '../../../friend_requests/controller/friend_controller.dart';
import 'chat_room_screen.dart';
import '../../../home/data/enums/meeting_type.dart';
import '../../../home/presentation/screens/schedule_meeting_screen.dart';

class FriendsListScreen extends StatefulWidget {
  const FriendsListScreen({super.key});

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FriendController _friendController = Get.put(FriendController());
  final HomeController _homeController =
      Get.find<HomeController>(); // Add HomeController
  final InstaTalkController _instaTalkController =
      Get.find<InstaTalkController>(); // Add _instaTalkController

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _friendController.fetchFriends();
    _homeController.fetchWishlist(); // Fetch wishlist users
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showChatBottomSheet(BuildContext context, User profile,
      {bool isTrial = false}) {
    Get.to(() => ChatRoomScreen(
          profile: profile,
          isTrial: isTrial,
          duration: 1,
          isFriend: true,
        ));
  }

  void _navigateToSchedule(User participant, MeetingType type) {
    Get.to(() => ScheduleMeetingScreen(
          participant: participant,
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

  Widget _buildServiceButtons(User profile) {
    // Detailed logging for debugging earnings data
    print('🔥 SERVICE RATES for ${profile.name}:');
    print('🔥 Earnings object: ${profile.earnings?.toJson()}');
    print(
        '🔥 Raw rates - Chat: ${profile.earnings?.chat}, Voice: ${profile.earnings?.voice}, Video: ${profile.earnings?.video}');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildServiceButton(
            icon: HugeIcons.strokeRoundedComment01,
            label:
                'Chat\n₹${_getSimpleRate(profile.earnings?.chat ?? 150)}/30min',
            onTap: () => _navigateToSchedule(profile, MeetingType.chat),
          ),
          _buildServiceButton(
            icon: HugeIcons.strokeRoundedCall02,
            label:
                'Call\n₹${_getSimpleRate(profile.earnings?.voice ?? 300)}/30min',
            onTap: () => _navigateToSchedule(profile, MeetingType.voice),
          ),
          _buildServiceButton(
            icon: HugeIcons.strokeRoundedVideo01,
            label:
                'Video\n₹${_getSimpleRate(profile.earnings?.video ?? 450)}/30min',
            onTap: () => _navigateToSchedule(profile, MeetingType.video),
          ),
        ],
      ),
    );
  }

  // Simplified rate display helper
  String _getSimpleRate(dynamic rate) {
    if (rate == null) return '0';
    try {
      if (rate is num) {
        return rate.toInt().toString();
      }
      return rate.toString();
    } catch (e) {
      print('Error formatting rate: $e');
      return '0';
    }
  }

  String _selectedTrialOption = 'Chat';

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

  Widget _buildServiceButton(
      {required IconData icon,
      required String label,
      required VoidCallback onTap,
      bool isTrial = false}) {
    return InkWell(
      onTap: onTap,
      child: isTrial
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accentColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: Colors.black,
                  ),
                  const SizedBox(
                    width: 4,
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Icon(icon, size: 24, color: AppColors.accentColor),
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

  void _showDeleteDialog(User profile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.secondaryBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Remove ${profile.name} from wishlist?',
          style: const TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to remove this person from your wishlist?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              // Call the HomeController's removeFromWishlist method
              if (profile.sId != null) {
                _homeController.removeFromWishlist(profile.sId!);
              }
              Navigator.pop(context); // Close dialog
            },
            child: const Text(
              'Remove',
              style: TextStyle(color: AppColors.redColor),
            ),
          ),
        ],
      ),
    );
  }

  int calculateAge(String? dobString) {
    if (dobString == null || dobString.isEmpty) {
      print('DOB is null or empty for friend/wishlist item');
      return 0; // Default age if DOB is missing
    }

    try {
      print('Trying to parse DOB: $dobString');
      final DateTime birthDate = DateTime.parse(dobString);
      final currentDate = DateTime.now();
      int age = currentDate.year - birthDate.year;
      final monthDiff = currentDate.month - birthDate.month;

      if (monthDiff < 0 ||
          (monthDiff == 0 && currentDate.day < birthDate.day)) {
        age--;
      }

      print('Successfully calculated age: $age from DOB: $dobString');
      return age;
    } catch (e) {
      print('Invalid date format: "$dobString" - $e');
      return 0; // Default age if date parsing fails
    }
  }

  // Add a helper method to safely navigate to the profile screen
  void _navigateToProfile(User profile) {
    try {
      // Create a complete user object with fallbacks for all required fields
      final safeProfile = User(
        sId: profile.sId ?? '',
        name: profile.name ?? 'User',
        email: profile.email ?? '',
        dob: profile.dob ?? '',
        gender: profile.gender ?? '',
        interestedIn: profile.interestedIn ?? '',
        about: profile.about ?? 'No information available',
        profession: profile.profession ?? 'Not specified',
        height: profile.height ?? '',
        languages: profile.languages ?? [],
        photos: profile.photos ?? [],
        interests: profile.interests ?? [],
        isOnline: profile.isOnline ?? false,
        role: profile.role ?? 'user',
        location: profile.location ??
            Location(country: 'Unknown', state: '', city: ''),
        earnings: profile.earnings ?? Earnings(),
        walletBalance: profile.walletBalance ?? 0,
      );

      print('Navigating to profile with safe data: ${safeProfile.name}');
      Get.to(() => UserProfileScreen(profile: safeProfile));
    } catch (e) {
      print('Error navigating to profile: $e');
      Get.snackbar(
        'Error',
        'Could not load profile details',
        backgroundColor: Colors.red.withOpacity(0.7),
        colorText: Colors.white,
      );
    }
  }

  void _showInstaOptions(User friend) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Insta Talk',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a 30-second free trial with ${friend.name}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildInstaOption(
                  icon: Icons.chat_bubble_outline,
                  label: 'Chat',
                  price: friend.earnings?.chatRate.toInt() ?? 150,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ScheduleInstaTalkScreen(
                              participant: friend, type: MeetingType.chat)),
                    );
                    // _instaTalkController.createInstaTalk(friend.sId!, 'chat');
                  },
                ),
                _buildInstaOption(
                  icon: Icons.call_outlined,
                  label: 'Call',
                  price: friend.earnings?.voiceRate.toInt() ?? 300,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ScheduleInstaTalkScreen(
                              participant: friend, type: MeetingType.voice)),
                    );
                    // _instaTalkController.createInstaTalk(friend.sId!, 'call');
                  },
                ),
                _buildInstaOption(
                  icon: Icons.videocam_outlined,
                  label: 'Video',
                  price: friend.earnings?.videoRate.toInt() ?? 450,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ScheduleInstaTalkScreen(
                              participant: friend, type: MeetingType.video)),
                    );
                    // _instaTalkController.createInstaTalk(friend.sId!, 'video');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstaOption({
    required IconData icon,
    required String label,
    required int price,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 90,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primaryColor, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '₹$price/30m',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // void _startInstaTalk(String option, User friend) {
  //   switch (option.toLowerCase()) {
  //     case 'chat':
  //       Get.to(() => ChatRoomScreen(
  //             profile: friend,
  //             isInstaTalk: true,
  //             instaTalkDuration: 30, // seconds
  //           ));
  //       break;
  //     case 'call':
  //       Get.to(() => VoiceCallLoadingScreen(
  //             participant: friend,
  //             scheduleTime: DateTime.now(),
  //             type: "voice",
  //             isInstaTalk: true,
  //             instaTalkDuration: 30, // seconds
  //           ));
  //       break;
  //     case 'video':
  //       Get.to(() => VideoCallLoadingScreen(
  //             participant: friend,
  //             scheduleTime: DateTime.now(),
  //             type: "video",
  //             isInstaTalk: true,
  //             instaTalkDuration: 30, // seconds
  //           ));
  //       break;
  //     default:
  //       Get.snackbar(
  //         'Invalid Option',
  //         'Please select a valid option: Chat, Call, or Video',
  //         backgroundColor: Colors.red,
  //         colorText: Colors.white,
  //       );
  //   }
  // }

  void _navigateToChat(User friend) {
    // Fix: Create an instance of ApiService first
    final apiService = ApiService();

    // Use the instance method instead of static access
    apiService
        .createOrGetChatRoom(SharedPrefs.sharedPreferenceUserIdKey, friend.sId!)
        .then((chatRoom) {
      // Fix: Add the required 'profile' parameter to ChatRoomScreen
      Get.to(() => ChatRoomScreen(
            profile: friend,
            duration: 1,
            isFriend: true,
          ));
    }).catchError((error) {
      print('Error creating chat room: $error');
      Get.snackbar(
        'Error',
        'Could not start chat session',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    });
  }

  void _navigateToMeeting(User friend, MeetingType type) {
    // Use Schedule Meeting Screen but set isInstant to true
    Get.to(() => ScheduleMeetingScreen(
          participant: friend,
          type: type,
          isInstant: true, // Add this parameter to ScheduleMeetingScreen
        ));
  }

  Widget _buildProfileCard(User profile, bool isWishlist) {
    // Check if essential properties exist
    if (profile.sId == null) {
      print('Warning: Profile has null ID');
    }

    if (profile.name == null || profile.name!.isEmpty) {
      print('Warning: Profile has null or empty name');
    }

    print('Building profile card for: ${profile.name} (DOB: ${profile.dob})');
    print('Location data: ${profile.location}');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        onTap: isWishlist ? null : () => _showChatBottomSheet(context, profile),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Stack(
                    children: [
                      InkWell(
                        onTap: () => _navigateToProfile(
                            profile), // Use the safe navigation method
                        child: ClipOval(
                          child: profile.photos != null &&
                                  profile.photos!.isNotEmpty
                              ? Image.network(
                                  profile.photos![0],
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                )
                              : const CircleAvatar(
                                  radius: 35,
                                  backgroundColor: Colors.grey,
                                  child: Icon(Icons.person,
                                      color: Colors.white, size: 40),
                                ),
                        ),
                      ),
                      if (profile.isOnline == true)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 15,
                            height: 15,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              border: Border.all(
                                  color: AppColors.primaryBackground, width: 2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  profile.name?.toString() ?? 'No Name',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ),
                            if (isWishlist)
                              IconButton(
                                style: IconButton.styleFrom(
                                  backgroundColor:
                                      AppColors.redColor.withOpacity(0.15),
                                ),
                                onPressed: () {
                                  _showDeleteDialog(profile);
                                },
                                icon: const Icon(
                                  HugeIcons.strokeRoundedDelete02,
                                  color: AppColors.redColor,
                                ),
                              )
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Fix this line - safely handle null location
                        Text(
                          profile.location?.city?.toString() ??
                              'Location unknown',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14,
                          ),
                        ),
                        if (isWishlist) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {},
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryColor,
                                    foregroundColor: Colors.white,
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text('Become Friends'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    _showInstaOptions(profile);
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primaryColor,
                                    side: const BorderSide(
                                        color: AppColors.primaryColor),
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text('Insta Talk'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (isWishlist) ...[
                const SizedBox(height: 12),
                _buildServiceButtons(profile),
              ]
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'My List',
          style: GoogleFonts.manrope(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primaryColor,
            indicatorWeight: 3,
            dividerColor: Colors.transparent,
            labelColor: AppColors.primaryColor,
            unselectedLabelColor: Colors.white.withOpacity(0.6),
            labelStyle: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(
                text: 'My Wishlist',
              ),
              Tab(text: 'My Friends'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Wishlist Tab - Use HomeController's wishlistUsers
          Obx(() {
            return _homeController.wishlistUsers.isEmpty
                ? EmptyWishlistView()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _homeController.wishlistUsers.length,
                    itemBuilder: (context, index) => _buildProfileCard(
                      _homeController.wishlistUsers[index],
                      true, // isWishlist = true
                    ),
                  );
          }),
          // Friends Tab
          Obx(() {
            return _friendController.friends.length < 1
                ? EmptyFriendsView()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _friendController.friends.length,
                    itemBuilder: (context, index) => _buildProfileCard(
                      _friendController.friends[index],
                      false,
                    ),
                  );
          }),
        ],
      ),
    );
  }
}

class EmptyWishlistView extends StatelessWidget {
  const EmptyWishlistView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon container
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.favorite_border,
                  size: 48,
                  color: AppColors.primaryColor,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                'Your Wishlist is Empty',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                "You haven't added anything to your wishlist yet. Start browsing and save your favorites here.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),

              // Placeholder Cards
              _buildPlaceholderCard(opacity: 1.0),
              const SizedBox(height: 12),
              _buildPlaceholderCard(opacity: 0.7),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderCard({required double opacity}) {
    return Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blueGrey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            // Image placeholder
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 16),

            // Text placeholders
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 80,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),

            // Button placeholder
            Container(
              width: 80,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.greenColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyFriendsView extends StatelessWidget {
  const EmptyFriendsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon container
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 48,
                  color: AppColors.primaryColor,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                'No Friends Yet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                "You don't have any friends added yet. Start sending friend requests to connect with others.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),

              // Placeholder Cards
              _buildPlaceholderCard(opacity: 1.0),
              const SizedBox(height: 12),
              _buildPlaceholderCard(opacity: 0.7),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderCard({required double opacity}) {
    return Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blueGrey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            // Avatar placeholder
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accentColor.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: const CircleAvatar(
                radius: 30,
                backgroundColor: Colors.black12,
              ),
            ),
            const SizedBox(width: 16),

            // Text placeholders
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 80,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),

            // Button placeholders
            Column(
              children: [
                Container(
                  width: 80,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.greenColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 80,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.redColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
