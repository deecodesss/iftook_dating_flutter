import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:iftook/helpers/permissions_explanation_dialog.dart';
import 'package:iftook/helpers/app_colors.dart';

class PermissionsHandler {
  // Singleton instance
  static final PermissionsHandler _instance = PermissionsHandler._internal();
  factory PermissionsHandler() => _instance;
  PermissionsHandler._internal();

  // Track if permissions have been requested already during this app session
  bool _permissionsExplained = false;

  // Reset flag when app is launched (to be called from main.dart)
  void resetPermissionsState() {
    _permissionsExplained = false;
  }

  // Request all necessary permissions for the app with explanation first
  Future<bool> requestAllPermissions({bool forceRequest = false}) async {
    // Skip explanation if already shown this session unless forced
    if (_permissionsExplained && !forceRequest) {
      await requestNotificationPermission();
      await requestCameraPermission();
      await requestMicrophonePermission();
      return true; // Return true since we're proceeding with permissions
    }

    // Show explanation dialog only once per app launch
    _permissionsExplained = true; // Mark as explained for this session
    await showPermissionsExplanationDialog();

    // We always return true since we don't care about the dialog result anymore
    return true;
  }

  // Request notification permissions
  Future<bool> requestNotificationPermission() async {
    try {
      // For iOS, use FirebaseMessaging
      if (Platform.isIOS) {
        FirebaseMessaging messaging = FirebaseMessaging.instance;
        NotificationSettings settings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );

        return settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
      }
      // For Android, use permission_handler
      else {
        final status = await Permission.notification.request();
        return status.isGranted;
      }
    } catch (e) {
      print("Error requesting notification permission: $e");
      return false;
    }
  }

  // Request camera permission
  Future<bool> requestCameraPermission() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted &&
          (status.isDenied || status.isPermanentlyDenied)) {
        _showSettingsDialog(
            'Camera', 'take photos, record videos, and for video calls');
      }
      return status.isGranted;
    } catch (e) {
      print("Error requesting camera permission: $e");
      return false;
    }
  }

  // Request microphone permission
  Future<bool> requestMicrophonePermission() async {
    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted &&
          (status.isDenied || status.isPermanentlyDenied)) {
        _showSettingsDialog(
            'Microphone', 'record audio and for voice/video calls');
      }
      return status.isGranted;
    } catch (e) {
      print("Error requesting microphone permission: $e");
      return false;
    }
  }

  // Show settings dialog when permission is denied
  void _showSettingsDialog(String permissionName, String featureDescription) {
    Get.dialog(
      AlertDialog(
        title: Text('$permissionName Permission Required'),
        content: Text(
          'The $permissionName permission is required to $featureDescription.\n\n'
          'Please enable it in app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // Check if notification permissions are granted
  Future<bool> checkNotificationPermissions() async {
    try {
      if (Platform.isIOS) {
        FirebaseMessaging messaging = FirebaseMessaging.instance;
        NotificationSettings settings =
            await messaging.getNotificationSettings();
        return settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
      } else {
        return Permission.notification.isGranted;
      }
    } catch (e) {
      print("Error checking notification permissions: $e");
      return false;
    }
  }

  // Check camera permission status
  Future<bool> checkCameraStatus() async {
    try {
      return Permission.camera.isGranted;
    } catch (e) {
      print("Error checking camera permission: $e");
      return false;
    }
  }

  // Check microphone permission status
  Future<bool> checkMicrophoneStatus() async {
    try {
      return Permission.microphone.isGranted;
    } catch (e) {
      print("Error checking microphone permission: $e");
      return false;
    }
  }
}
