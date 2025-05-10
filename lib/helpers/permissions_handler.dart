import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:iftook/helpers/permissions_explanation_dialog.dart';

class PermissionsHandler {
  // Singleton instance
  static final PermissionsHandler _instance = PermissionsHandler._internal();
  factory PermissionsHandler() => _instance;
  PermissionsHandler._internal();

  // Track if permissions have been requested already
  bool _permissionsRequested = false;

  // Request all necessary permissions for the app with explanation first
  Future<void> requestAllPermissions({bool forceRequest = false}) async {
    // Only request once unless forced
    if (_permissionsRequested && !forceRequest) return;

    // Show explanation dialog first
    final shouldProceed = await showPermissionsExplanationDialog();

    if (shouldProceed) {
      await requestNotificationPermission();
      await requestCameraAndMicrophonePermissions();
      _permissionsRequested = true;
    }
  }

  // Show initial explanation dialog
  Future<bool> _showPermissionsExplanationDialog() async {
    return await Get.dialog<bool>(
          AlertDialog(
            title: const Text(
              'Permissions Required',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'For the best experience, iftook needs the following permissions:',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  _buildPermissionExplanationItem(
                    icon: Icons.notifications,
                    title: 'Notifications',
                    description:
                        'To receive chat messages, video call requests, and other important alerts',
                  ),
                  const SizedBox(height: 12),
                  _buildPermissionExplanationItem(
                    icon: Icons.camera_alt,
                    title: 'Camera',
                    description:
                        'For video calls, live streaming, and profile pictures',
                  ),
                  const SizedBox(height: 12),
                  _buildPermissionExplanationItem(
                    icon: Icons.mic,
                    title: 'Microphone',
                    description:
                        'For voice calls, video calls, and voice messages',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'You can change these permissions later in your device settings.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Get.back(result: false);
                },
                child: const Text('Later'),
              ),
              ElevatedButton(
                onPressed: () {
                  Get.back(result: true);
                },
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
  }

  // Helper widget for permission explanation items
  Widget _buildPermissionExplanationItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.blue, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Request notification permissions
  Future<bool> requestNotificationPermission() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    try {
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print("User granted permission for notifications.");
        return true;
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        print("User granted provisional permission.");
        return true;
      } else {
        print("User denied notification permission.");
        return false;
      }
    } catch (e) {
      print("Error requesting notification permission: $e");
      return false;
    }
  }

  // Request camera and microphone permissions
  Future<bool> requestCameraAndMicrophonePermissions() async {
    try {
      // For Android and iOS
      Map<Permission, PermissionStatus> statuses = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      bool allGranted = true;
      statuses.forEach((permission, status) {
        if (!status.isGranted) {
          allGranted = false;
          print("${permission.toString()} permission denied");
        }
      });

      if (!allGranted) {
        // Show custom dialog explaining why permissions are needed
        _showPermissionDeniedDialog();
      }

      return allGranted;
    } catch (e) {
      print("Error requesting camera/microphone permissions: $e");
      return false;
    }
  }

  // Show explanation dialog when permissions are denied
  void _showPermissionDeniedDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('Permission Denied'),
        content: const Text(
          'Some features may not work properly without camera and microphone permissions. '
          'Would you like to open app settings to enable these permissions?',
        ),
        actions: [
          TextButton(
            child: const Text('Not Now'),
            onPressed: () => Get.back(),
          ),
          TextButton(
            child: const Text('Open Settings'),
            onPressed: () {
              Get.back();
              openAppSettings();
            },
          ),
        ],
      ),
    );
  }

  // Check if notification permissions are granted
  Future<bool> checkNotificationPermissions() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.getNotificationSettings();

      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      print("Error checking notification permissions: $e");
      return false;
    }
  }

  // New: Request only camera permission
  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (!status.isGranted && (status.isDenied || status.isPermanentlyDenied)) {
      _showSpecificPermissionDeniedDialog(Permission.camera);
    }
    return status.isGranted;
  }

  // New: Request only microphone permission
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted && (status.isDenied || status.isPermanentlyDenied)) {
      _showSpecificPermissionDeniedDialog(Permission.microphone);
    }
    return status.isGranted;
  }

  // New: Helper dialog for specific permission denial
  void _showSpecificPermissionDeniedDialog(Permission permission) {
    String permissionName = '';
    String featureDescription = '';

    if (permission == Permission.camera) {
      permissionName = 'Camera';
      featureDescription = 'take photos, record videos, and for video calls';
    } else if (permission == Permission.microphone) {
      permissionName = 'Microphone';
      featureDescription = 'record audio and for voice/video calls';
    } else {
      return; // Should not happen for this dialog
    }

    Get.dialog(
      AlertDialog(
        title: Text('$permissionName Permission Denied'),
        content: Text(
          'The $permissionName permission is required to $featureDescription. '
          'Please enable it in app settings if you wish to use these features.',
        ),
        actions: [
          TextButton(
            child: const Text('Not Now'),
            onPressed: () => Get.back(),
          ),
          TextButton(
            child: const Text('Open Settings'),
            onPressed: () {
              Get.back();
              openAppSettings();
            },
          ),
        ],
      ),
    );
  }

  // New: Check camera permission status
  Future<bool> checkCameraStatus() async {
    return Permission.camera.isGranted;
  }

  // New: Check microphone permission status
  Future<bool> checkMicrophoneStatus() async {
    return Permission.microphone.isGranted;
  }
}
