import 'package:flutter/material.dart';
import 'package:get/get.dart';

class VoiceCallScreen extends StatelessWidget {
  const VoiceCallScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(height: 40),
            const CircleAvatar(
              radius: 70,
              backgroundImage: NetworkImage('https://i.pravatar.cc/300'),
            ),
            const Column(
              children: [
                Text(
                  'Sarah Parker',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Calling...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '00:32',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCallButton(
                  icon: Icons.mic_off,
                  color: Colors.white,
                  backgroundColor: Colors.grey[800]!,
                ),
                _buildCallButton(
                  onTap: () {
                    Get.back();
                  },
                  icon: Icons.call_end,
                  color: Colors.white,
                  backgroundColor: Colors.red,
                  size: 65,
                ),
                _buildCallButton(
                  icon: Icons.volume_up,
                  color: Colors.white,
                  backgroundColor: Colors.grey[800]!,
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required Color color,
    required Color backgroundColor,
    VoidCallback? onTap,
    double size = 50,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
        ),
        child: Icon(
          icon,
          color: color,
          size: size * 0.5,
        ),
      ),
    );
  }
}
