import 'package:get/get.dart';
import 'package:iftook/core/services/api_service.dart';
import 'package:iftook/core/services/shared_prefs.dart';

class CallDurationService extends GetxService {
  static CallDurationService get to => Get.find();

  final RxBool _isFriend = false.obs;
  bool get isFriend => _isFriend.value;

  // Initialize the service and check friendship status
  Future<void> initialize(String otherUserId) async {
    try {
      final currentUserId = await SharedPrefs.getUserIdSharedPreference();
      if (currentUserId != null) {
        final isFriend = await ApiService.checkIsFriend(otherUserId);
        _isFriend.value = isFriend;
        print(
            'CallDurationService: Users are ${isFriend ? "friends" : "not friends"}');
      }
    } catch (e) {
      print('CallDurationService: Error checking friendship status: $e');
      _isFriend.value = false;
    }
  }

  // Check if call should be timed (not friends and not trial)
  bool shouldTimeCall(bool isTrial) {
    return !_isFriend.value && !isTrial;
  }

  // Get initial timer duration based on call type and friendship status
  int getInitialTimerDuration(bool isInstaTalk, int defaultDuration) {
    if (_isFriend.value) {
      return 0; // No timer for friends
    }
    return isInstaTalk
        ? 30
        : defaultDuration; // 30 seconds for InstaTalk, default duration for regular calls
  }

  // Reset the service
  void reset() {
    _isFriend.value = false;
  }
}
