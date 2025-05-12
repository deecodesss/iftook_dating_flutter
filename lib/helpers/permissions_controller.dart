import 'package:get/get.dart';
import 'package:iftook/helpers/permissions_handler.dart';
import 'package:iftook/helpers/permissions_explanation_dialog.dart';

class PermissionsController extends GetxController {
  final PermissionsHandler _permissionsHandler = PermissionsHandler();

  // Observable permission states
  final RxBool notificationPermission = false.obs;
  final RxBool cameraPermission = false.obs;
  final RxBool microphonePermission = false.obs;

  // Track if dialog has been shown this session
  final RxBool _hasShownDialog = false.obs;

  // Track if we're currently checking permissions
  final RxBool _isCheckingPermissions = false.obs;

  // Check if all required permissions are granted
  bool get allPermissionsGranted =>
      notificationPermission.value &&
      cameraPermission.value &&
      microphonePermission.value;

  @override
  void onInit() {
    super.onInit();
    checkAllPermissions();
  }

  // Check status of all permissions
  Future<void> checkAllPermissions() async {
    if (_isCheckingPermissions.value) return;

    _isCheckingPermissions.value = true;

    try {
      notificationPermission.value =
          await _permissionsHandler.checkNotificationPermissions();
      cameraPermission.value = await _permissionsHandler.checkCameraStatus();
      microphonePermission.value =
          await _permissionsHandler.checkMicrophoneStatus();

      print(
          'Permissions status updated: notification=${notificationPermission.value}, camera=${cameraPermission.value}, microphone=${microphonePermission.value}');
    } catch (e) {
      print('Error checking permissions: $e');
    } finally {
      _isCheckingPermissions.value = false;
    }
  }

  // Request notification permission
  Future<bool> requestNotificationPermission() async {
    final result = await _permissionsHandler.requestNotificationPermission();
    notificationPermission.value = result;
    return result;
  }

  // Request camera permission
  Future<bool> requestCameraPermission() async {
    final result = await _permissionsHandler.requestCameraPermission();
    cameraPermission.value = result;
    return result;
  }

  // Request microphone permission
  Future<bool> requestMicrophonePermission() async {
    final result = await _permissionsHandler.requestMicrophonePermission();
    microphonePermission.value = result;
    return result;
  }

  // Show permissions explanation screen after a delay if needed
  Future<void> showPermissionsDialogIfNeeded() async {
    try {
      // If dialog already shown this session, don't show again
      if (_hasShownDialog.value) {
        print('Permission dialog already shown this session, skipping');
        return;
      }

      // Check permissions first
      await checkAllPermissions();

      // If all permissions are already granted, don't show anything
      if (allPermissionsGranted) {
        print('All permissions already granted, no need to show dialog');
        return;
      }

      // Mark dialog as shown for this session
      _hasShownDialog.value = true;

      print('Showing permissions explanation dialog');

      // Show the explanation screen
      await showPermissionsExplanationDialog();

      // Update permission states after dialog is closed
      await checkAllPermissions();

      print('Dialog closed, permissions updated');
    } catch (e) {
      print('Error in showPermissionsDialogIfNeeded: $e');
    }
  }

  // Reset the dialog shown flag (for testing or to force show)
  void resetDialogShownFlag() {
    _hasShownDialog.value = false;
    print('Permission dialog flag reset, will show next time it is needed');
  }
}
