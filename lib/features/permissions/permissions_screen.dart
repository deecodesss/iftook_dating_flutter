import 'package:flutter/material.dart';
import 'package:get/get.dart';
// import 'package:permission_handler/permission_handler.dart'; // Will be replaced by PermissionsHandler for camera/mic
import '../../helpers/permissions_handler.dart';
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
  final PermissionsHandler _permissionsHandler =
      PermissionsHandler(); // Instance for easier access

  @override
  void initState() {
    super.initState();
    _checkAllPermissions(); // Only check, do not request
  }

  Future<void> _checkAllPermissions() async {
    final notification =
        await _permissionsHandler.checkNotificationPermissions();
    // final camera = await Permission.camera.isGranted; // Old way
    // final microphone = await Permission.microphone.isGranted; // Old way
    final camera = await _permissionsHandler.checkCameraStatus(); // New way
    final microphone =
        await _permissionsHandler.checkMicrophoneStatus(); // New way
    setState(() {
      _notificationGranted = notification;
      _cameraGranted = camera;
      _microphoneGranted = microphone;
      _loading = false;
    });
  }

  Future<void> _requestNotification() async {
    await _permissionsHandler.requestNotificationPermission();
    await _checkAllPermissions();
  }

  Future<void> _requestCamera() async {
    // await Permission.camera.request(); // Old way
    await _permissionsHandler.requestCameraPermission(); // New way
    await _checkAllPermissions();
  }

  Future<void> _requestMicrophone() async {
    // await Permission.microphone.request(); // Old way
    await _permissionsHandler.requestMicrophonePermission(); // New way
    await _checkAllPermissions();
  }

  bool get _allGranted =>
      _notificationGranted && _cameraGranted && _microphoneGranted;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Permissions Required'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'To use iftook, please grant the following permissions:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _buildPermissionTile(
              icon: Icons.notifications,
              title: 'Notifications',
              granted: _notificationGranted,
              onTap: _requestNotification,
            ),
            _buildPermissionTile(
              icon: Icons.camera_alt,
              title: 'Camera',
              granted: _cameraGranted,
              onTap: _requestCamera,
            ),
            _buildPermissionTile(
              icon: Icons.mic,
              title: 'Microphone',
              granted: _microphoneGranted,
              onTap: _requestMicrophone,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _allGranted
                    ? () async {
                        await updateFCMToken(); // Register FCM token only after permissions granted
                        Get.offAll(() => HomeScreen());
                      }
                    : null,
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required bool granted,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: granted ? Colors.green : Colors.grey),
      title: Text(title),
      trailing: Switch(
        value: granted,
        onChanged: granted
            ? null
            : (val) {
                if (val) onTap();
              },
      ),
      onTap: granted ? null : onTap,
    );
  }
}
