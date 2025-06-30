import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/helpers/app_colors.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionExplanationScreen extends StatefulWidget {
  const PermissionExplanationScreen({Key? key}) : super(key: key);

  @override
  State<PermissionExplanationScreen> createState() =>
      _PermissionExplanationScreenState();
}

class _PermissionExplanationScreenState
    extends State<PermissionExplanationScreen> {
  bool _notificationStatus = false;
  bool _cameraStatus = false;
  bool _microphoneStatus = false;
  bool _isProcessingNotification = false;
  bool _isProcessingCamera = false;
  bool _isProcessingMicrophone = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionStatus();
  }

  Future<void> _checkPermissionStatus() async {
    final notificationSettings = await Permission.notification.status;
    final cameraStatus = await Permission.camera.status;
    final microphoneStatus = await Permission.microphone.status;

    if (mounted) {
      setState(() {
        _notificationStatus = notificationSettings.isGranted;
        _cameraStatus = cameraStatus.isGranted;
        _microphoneStatus = microphoneStatus.isGranted;
      });
    }
  }

  Future<void> _requestNotification() async {
    if (_isProcessingNotification) return;

    setState(() {
      _isProcessingNotification = true;
    });

    try {
      // Directly request the system permission
      final status = await Permission.notification.request();

      if (mounted) {
        setState(() {
          _notificationStatus = status.isGranted;
        });
      }

      // If permission is permanently denied, open app settings directly
      if (status.isPermanentlyDenied && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "Please enable notifications in settings to receive important updates",
            ),
            action: SnackBarAction(
              label: "Settings",
              onPressed: () {
                openAppSettings();
              },
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print("Error requesting notification permission: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingNotification = false;
        });
      }
    }
  }

  Future<void> _requestCamera() async {
    if (_isProcessingCamera) return;

    setState(() {
      _isProcessingCamera = true;
    });

    try {
      // Directly request the system permission
      final status = await Permission.camera.request();

      if (mounted) {
        setState(() {
          _cameraStatus = status.isGranted;
        });
      }

      // If permission is permanently denied, show a simple snackbar
      if (status.isPermanentlyDenied && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "Please enable camera access in settings for video calls",
            ),
            action: SnackBarAction(
              label: "Settings",
              onPressed: () {
                openAppSettings();
              },
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print("Error requesting camera permission: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingCamera = false;
        });
      }
    }
  }

  Future<void> _requestMicrophone() async {
    if (_isProcessingMicrophone) return;

    setState(() {
      _isProcessingMicrophone = true;
    });

    try {
      // Directly request the system permission
      final status = await Permission.microphone.request();

      if (mounted) {
        setState(() {
          _microphoneStatus = status.isGranted;
        });
      }

      // If permission is permanently denied, show a simple snackbar
      if (status.isPermanentlyDenied && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "Please enable microphone access in settings for voice calls",
            ),
            action: SnackBarAction(
              label: "Settings",
              onPressed: () {
                openAppSettings();
              },
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print("Error requesting microphone permission: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingMicrophone = false;
        });
      }
    }
  }

  void _closeScreen() {
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    } else {
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final backgroundColor =
        isDark ? Theme.of(context).scaffoldBackgroundColor : Colors.white;
    final cardColor = isDark ? Colors.grey.shade800 : Colors.grey.shade50;

    return WillPopScope(
      onWillPop: () async {
        _closeScreen();
        return false;
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        CircleAvatar(
                          backgroundColor: AppColors.primaryColor,
                          radius: 50,
                          child: const Icon(
                            Icons.security,
                            size: 50,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "Welcome to iftook!",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "To provide you with the best experience, we need a few permissions:",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: textColor.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 40),
                        _buildPermissionCard(
                          context,
                          Icons.notifications_active,
                          "Notifications",
                          "For chat messages, video calls, and important updates",
                          _notificationStatus,
                          _requestNotification,
                          _isProcessingNotification,
                          cardColor,
                          textColor,
                        ),
                        const SizedBox(height: 16),
                        _buildPermissionCard(
                          context,
                          Icons.camera_alt,
                          "Camera",
                          "For video calls, live streaming, and profile photos",
                          _cameraStatus,
                          _requestCamera,
                          _isProcessingCamera,
                          cardColor,
                          textColor,
                        ),
                        const SizedBox(height: 16),
                        _buildPermissionCard(
                          context,
                          Icons.mic,
                          "Microphone",
                          "For voice calls and voice messages",
                          _microphoneStatus,
                          _requestMicrophone,
                          _isProcessingMicrophone,
                          cardColor,
                          textColor,
                        ),
                        const SizedBox(height: 40),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _closeScreen,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              "Continue",
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard(
    BuildContext context,
    IconData icon,
    String title,
    String description,
    bool isGranted,
    VoidCallback onRequest,
    bool isProcessing,
    Color cardColor,
    Color textColor,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: cardColor,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isGranted || isProcessing ? null : onRequest,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.primaryColor, size: 28),
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
                          fontSize: 18,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: textColor.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isProcessing)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                else
                  Switch(
                    value: isGranted,
                    activeColor: Colors.green,
                    activeTrackColor: Colors.green.withOpacity(0.4),
                    inactiveThumbColor: Colors.grey,
                    inactiveTrackColor: Colors.grey.withOpacity(0.4),
                    onChanged: (value) {
                      if (!isGranted) {
                        onRequest();
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Helper function to show the full-screen dialog
Future<void> showPermissionsExplanationDialog() async {
  try {
    await Navigator.of(Get.context!).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const PermissionExplanationScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;

          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
        fullscreenDialog: true,
      ),
    );
  } catch (e) {
    print('Error showing permissions dialog: $e');
    // Fallback method with animation
    Get.to(
      () => const PermissionExplanationScreen(),
      fullscreenDialog: true,
      transition: Transition.rightToLeft,
      duration: const Duration(milliseconds: 600),
    );
  }
}
