import 'package:flutter/material.dart';
import 'package:get/get.dart';
// import 'package:permission_handler/permission_handler.dart'; // Will be replaced by PermissionsHandler for camera/mic
import '../../helpers/permissions_handler.dart';
import '../../helpers/app_colors.dart';
import '../home/presentation/screens/home_screen.dart';
import '../../../main.dart'; // For updateFCMToken

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _notificationGranted = false;
  bool _cameraGranted = false;
  bool _microphoneGranted = false;
  bool _loading = true;
  final PermissionsHandler _permissionsHandler = PermissionsHandler();

  @override
  void initState() {
    super.initState();
    _initializePermissions();
  }

  Future<void> _initializePermissions() async {
    // First check permissions without displaying UI
    await _checkAllPermissions();

    // If all permissions are already granted, proceed to home screen
    if (_allGranted) {
      _navigateToHome();
      return;
    }

    // Show the permissions explanation dialog
    final shouldProceed =
        await _permissionsHandler.requestAllPermissions(forceRequest: true);

    // If user continues from explanation dialog, they've likely granted some permissions
    if (shouldProceed) {
      // Check permissions again before showing permissions screen
      await _checkAllPermissions();

      // If all permissions granted after explanation, go to home
      if (_allGranted) {
        _navigateToHome();
        return;
      }
    }

    setState(() {
      _loading = false;
    });
  }

  Future<void> _checkAllPermissions() async {
    final notification =
        await _permissionsHandler.checkNotificationPermissions();
    final camera = await _permissionsHandler.checkCameraStatus();
    final microphone = await _permissionsHandler.checkMicrophoneStatus();

    setState(() {
      _notificationGranted = notification;
      _cameraGranted = camera;
      _microphoneGranted = microphone;
    });
  }

  Future<void> _requestNotification() async {
    await _permissionsHandler.requestNotificationPermission();
    await _checkAllPermissions();
    _checkForAllGranted();
  }

  Future<void> _requestCamera() async {
    await _permissionsHandler.requestCameraPermission();
    await _checkAllPermissions();
    _checkForAllGranted();
  }

  Future<void> _requestMicrophone() async {
    await _permissionsHandler.requestMicrophonePermission();
    await _checkAllPermissions();
    _checkForAllGranted();
  }

  void _checkForAllGranted() {
    if (_allGranted) {
      // Small delay to allow the UI to update before navigation
      Future.delayed(const Duration(milliseconds: 300), () {
        _navigateToHome();
      });
    }
  }

  bool get _allGranted =>
      _notificationGranted && _cameraGranted && _microphoneGranted;

  void _navigateToHome() async {
    await updateFCMToken();
    Get.offAll(() => HomeScreen());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardColor = isDark ? Colors.grey.shade800 : Colors.grey.shade50;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Required Permissions',
          style: TextStyle(color: textColor),
        ),
        actions: [
          TextButton(
            onPressed: _navigateToHome,
            child: const Text('Skip'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please enable these permissions to use all features:',
              style: TextStyle(fontSize: 16, color: textColor),
            ),
            const SizedBox(height: 24),
            _buildPermissionCard(
              icon: Icons.notifications,
              title: 'Notifications',
              subtitle: 'For messages and important updates',
              granted: _notificationGranted,
              onTap: _requestNotification,
              cardColor: cardColor,
              textColor: textColor,
            ),
            const SizedBox(height: 16),
            _buildPermissionCard(
              icon: Icons.camera_alt,
              title: 'Camera',
              subtitle: 'For video calls and photos',
              granted: _cameraGranted,
              onTap: _requestCamera,
              cardColor: cardColor,
              textColor: textColor,
            ),
            const SizedBox(height: 16),
            _buildPermissionCard(
              icon: Icons.mic,
              title: 'Microphone',
              subtitle: 'For voice calls and messages',
              granted: _microphoneGranted,
              onTap: _requestMicrophone,
              cardColor: cardColor,
              textColor: textColor,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _navigateToHome,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Continue to App',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool granted,
    required VoidCallback onTap,
    required Color cardColor,
    required Color textColor,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor:
                  granted ? AppColors.primaryColor : Colors.grey.shade300,
              child: Icon(
                icon,
                color: granted ? Colors.white : Colors.grey,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: granted,
              activeColor: AppColors.primaryColor,
              onChanged: (val) {
                if (!granted) onTap();
              },
            ),
          ],
        ),
      ),
    );
  }
}
