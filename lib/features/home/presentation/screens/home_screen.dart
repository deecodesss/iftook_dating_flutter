import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:iftook/features/friend_requests/presentation/screens/friend_requests_screen.dart';
import 'package:iftook/features/friends/presentation/screens/friends_list_screen.dart';
import 'package:iftook/features/home/presentation/screens/main_home_screen.dart';
import 'package:iftook/features/profile/presentation/screens/profile_screen.dart';
import 'package:iftook/helpers/app_colors.dart';
import 'package:iftook/helpers/permissions_controller.dart';
import 'package:iftook/features/notifications/services/notification_storage_service.dart';
// import 'package:iftook/features/notifications/presentation/screens/notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late PermissionsController _permissionsController;
  late NotificationStorageService _notificationService;

  final List<Widget> _pages = [
    MainHomeScreen(),
    FriendsListScreen(),
    const FriendRequestsScreen(),
    ProfileScreen(),
  ];

  final List<NavigationItem> _items = [
    NavigationItem(icon: HugeIcons.strokeRoundedHome01, label: 'Home'),
    NavigationItem(icon: HugeIcons.strokeRoundedFavourite, label: 'My List'),
    NavigationItem(icon: HugeIcons.strokeRoundedUserAdd02, label: 'Requests'),
    NavigationItem(icon: HugeIcons.strokeRoundedUser, label: 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    _initPermissionsController();
    _initNotificationService();
  }

  void _initPermissionsController() {
    try {
      // Try to find existing controller
      _permissionsController = Get.find<PermissionsController>();
      print('Found existing PermissionsController');
    } catch (e) {
      // Create a new one if not found
      print('Creating new PermissionsController');
      _permissionsController = Get.put(PermissionsController());
    }

    // The permissions check is now handled in MainHomeScreen
  }

  void _initNotificationService() {
    try {
      _notificationService = Get.find<NotificationStorageService>();
      print('Found existing NotificationStorageService');
    } catch (e) {
      print('Creating new NotificationStorageService');
      _notificationService =
          Get.put(NotificationStorageService(), permanent: true);
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDarkMode
              ? AppColors.secondaryAccent.withOpacity(0.16)
              : Colors.white,
          boxShadow: [
            BoxShadow(
              color: isDarkMode ? Colors.black26 : Colors.grey.shade300,
              blurRadius: 15,
              spreadRadius: 1,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(
                _items.length,
                (index) => GestureDetector(
                  onTap: () => _onItemTapped(index),
                  child: _buildNavItem(index, isDarkMode),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, bool isDarkMode) {
    final isSelected = _selectedIndex == index;

    final unselectedColor = isDarkMode ? Colors.grey[400] : Colors.grey[500];
    final selectedColor =
        isDarkMode ? AppColors.primaryColor : AppColors.primaryColor;
    final selectedBackgroundColor = isDarkMode
        ? AppColors.primaryColor.withOpacity(0.15)
        : AppColors.primaryColor.withOpacity(0.1);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: isSelected ? selectedBackgroundColor : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Icon(
                _items[index].icon,
                color: isSelected ? selectedColor : unselectedColor,
                size: 26,
              ),
              // Show badge for Friends (index 1) for chat notifications
              if (index == 1)
                Obx(() => _notificationService.chatUnreadCount > 0
                    ? Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : const SizedBox()),
              // Show badge for Requests (index 2) for request notifications
              if (index == 2)
                Obx(() => _notificationService.requestsUnreadCount > 0
                    ? Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : const SizedBox()),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _items[index].label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? selectedColor : unselectedColor,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final String label;

  NavigationItem({required this.icon, required this.label});
}
