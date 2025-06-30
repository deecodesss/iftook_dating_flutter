import 'package:get/get.dart';
import 'package:iftook/core/services/api_service.dart';

class NotificationController extends GetxController {
  Future<void> updateFCMToken(String fcmToken) async {
    final response = await ApiService.updateFCMToken(fcmToken);
    print("fcm: ${response.body}");
  }
}
