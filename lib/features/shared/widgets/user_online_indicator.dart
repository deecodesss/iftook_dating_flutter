import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/features/shared/controllers/user_online_controller.dart';

/// A widget that displays a user's online status
///
/// This can be used in various places like:
/// - User profiles
/// - Chat list
/// - Friend list
class UserOnlineIndicator extends StatelessWidget {
  final String userId;
  final double size;
  final bool showOffline;
  final Color onlineColor;
  final Color offlineColor;
  final Widget? offlineWidget;

  const UserOnlineIndicator({
    Key? key,
    required this.userId,
    this.size = 12.0,
    this.showOffline = false,
    this.onlineColor = Colors.green,
    this.offlineColor = Colors.grey,
    this.offlineWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get the controller instance - will be created if not already exists
    final controller = Get.find<UserOnlineController>();

    return StreamBuilder<bool>(
      stream: controller.getUserStatusStream(userId),
      builder: (context, snapshot) {
        // Show loading while we get the initial status
        if (!snapshot.hasData) {
          return SizedBox(
            width: size,
            height: size,
          );
        }

        final isOnline = snapshot.data ?? false;

        // If offline and we don't want to show offline indicators
        if (!isOnline && !showOffline) {
          return const SizedBox.shrink();
        }

        // If offline and we have a custom offline widget
        if (!isOnline && offlineWidget != null) {
          return offlineWidget!;
        }

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isOnline ? onlineColor : offlineColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: isOnline
                    ? onlineColor.withOpacity(0.4)
                    : offlineColor.withOpacity(0.2),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A widget that shows online status next to a user name
class UserNameWithStatus extends StatelessWidget {
  final String userId;
  final String name;
  final TextStyle? nameStyle;

  const UserNameWithStatus({
    Key? key,
    required this.userId,
    required this.name,
    this.nameStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          style: nameStyle ??
              const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(width: 8),
        UserOnlineIndicator(userId: userId),
      ],
    );
  }
}
