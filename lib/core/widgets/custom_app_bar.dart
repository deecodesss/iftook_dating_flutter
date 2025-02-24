import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/features/home/presentation/screens/search_screen.dart';
import 'package:iftook/helpers/myassets.dart';

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
    return AppBar(
      title: Row(
        children: [
          Image.asset(MyAssets.appIconPNG, height: 80),
          const Spacer(),
          const Text(
            'India',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
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
