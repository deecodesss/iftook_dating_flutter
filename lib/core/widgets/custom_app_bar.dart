import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:iftook/features/home/presentation/screens/search_screen.dart';
import 'package:iftook/helpers/myassets.dart';
import 'package:iftook/helpers/app_colors.dart';
import 'package:iftook/features/home/controllers/home_controller.dart';
import 'package:iftook/features/notifications/services/notification_storage_service.dart';
import 'package:iftook/features/notifications/presentation/screens/notifications_screen.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isExtended;
  final PreferredSize? bottom;

  const CustomAppBar({
    super.key,
    this.isExtended = false,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final HomeController controller = Get.find<HomeController>();

    // Initialize notification service
    NotificationStorageService notificationService;
    try {
      notificationService = Get.find<NotificationStorageService>();
    } catch (e) {
      notificationService =
          Get.put(NotificationStorageService(), permanent: true);
    }

    return AppBar(
      title: Row(
        children: [
          Image.asset(MyAssets.appIconPNG, height: 80),
          const Spacer(),
          Obx(() => PopupMenuButton<String>(
                child: Row(
                  children: [
                    Text(
                      controller.selectedCountry.value,
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, color: Colors.white),
                  ],
                ),
                onSelected: (String country) {
                  controller.setSelectedCountry(country);
                },
                itemBuilder: (BuildContext context) {
                  return controller.countries.map((String country) {
                    return PopupMenuItem<String>(
                      value: country,
                      child: Row(
                        children: [
                          Text(
                            country,
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (country == controller.selectedCountry.value)
                            const Icon(Icons.check, size: 18),
                        ],
                      ),
                    );
                  }).toList();
                },
                color: Theme.of(context).scaffoldBackgroundColor,
                elevation: 8,
              )),
          const SizedBox(width: 12),
          // Notification icon with badge
          IconButton(
            icon: Stack(
              children: [
                const Icon(
                  HugeIcons.strokeRoundedNotification03,
                  color: Colors.white,
                  size: 24,
                ),
                Obx(() => notificationService.unreadCount > 0
                    ? Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryColor,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '${notificationService.unreadCount > 99 ? '99+' : notificationService.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : const SizedBox()),
              ],
            ),
            onPressed: () {
              Get.to(() => const NotificationsScreen());
            },
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(
              Icons.search,
              color: Colors.white,
              size: 24,
            ),
            onPressed: () {
              // Navigate to search screen
              Get.to(() => SearchScreen());
            },
          ),
        ],
      ),
      bottom: isExtended ? bottom : null,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(isExtended
      ? kToolbarHeight + (bottom?.preferredSize.height ?? 0)
      : kToolbarHeight);
}
