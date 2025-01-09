import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:iftook/features/friends/presentation/screens/chat_room.dart';
import 'package:iftook/features/home/presentation/widgets/user_profile_screen.dart';
import 'package:iftook/helpers/app_colors.dart';

class FriendsListScreen extends StatefulWidget {
  const FriendsListScreen({super.key});

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showChatBottomSheet(BuildContext context, UserProfile profile,
      {bool isTrial = false}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.primaryBackground,
      isScrollControlled: true, // This is crucial
      useSafeArea: true, // Add this
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom, // Add this
        ),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: AppColors.primaryBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: ChatRoom(
            profile: profile,
            isTrial: isTrial,
          ),
        ),
      ),
    );
  }

  Widget _buildServiceButtons(UserProfile profile) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildServiceButton(
            icon: HugeIcons.strokeRoundedAlarmClock,
            label: 'Trial',
            onTap: () {
              if (profile.isOnline) {
                _showChatBottomSheet(context, profile, isTrial: true);
              } else {
                showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    backgroundColor: AppColors.secondaryBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: const BoxDecoration(
                              color: AppColors.primaryBackground,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.mail_outline,
                              color: AppColors.primaryColor,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Trial Request Sent!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your trial request has been sent to ${profile.name}.\nThey will be notified when they come online.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
                              minimumSize: const Size(double.infinity, 45),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            child: const Text(
                              'Got it',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
            },
            isTrial: true,
          ),
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
        ],
      ),
    );
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
                      // color: Colors.white,
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

  void _showDeleteDialog(UserProfile profile) {
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
              // Handle unfriend logic here
              Navigator.pop(context); // Close chat
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

  Widget _buildProfileCard(UserProfile profile, bool isWishlist) {
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
                        onTap: () {
                          Get.to(() => const UserProfileScreen());
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            profile.imageUrl,
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      if (profile.isOnline)
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
                                  profile.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (profile.age != null)
                                  Text(
                                    '${profile.age}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 16,
                                    ),
                                  ),
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
                        Text(
                          profile.location,
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
                                  child: const Text('Date me'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {},
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
                                  child: const Text('Book Meeting'),
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
      // backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'My List',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
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
            labelStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(text: 'My Wishlist'),
              Tab(text: 'My Friends'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Wishlist Tab
          ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: dummyProfiles.length,
            itemBuilder: (context, index) => _buildProfileCard(
              dummyProfiles[index],
              true,
            ),
          ),
          // Friends Tab
          ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: dummyProfiles.length,
            itemBuilder: (context, index) => _buildProfileCard(
              dummyProfiles[index],
              false,
            ),
          ),
        ],
      ),
    );
  }
}

class UserProfile {
  final String name;
  final int? age;
  final String location;
  final String imageUrl;
  final bool isOnline;

  UserProfile({
    required this.name,
    this.age,
    required this.location,
    required this.imageUrl,
    this.isOnline = false,
  });
}

// Dummy data
final dummyProfiles = [
  UserProfile(
    name: 'Sarah',
    age: 25,
    location: 'Mumbai',
    imageUrl: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1',
    isOnline: true,
  ),
  UserProfile(
    name: 'Jessica',
    age: 24,
    location: 'Delhi',
    imageUrl: 'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e',
  ),
  // Add more dummy profiles as needed
];
