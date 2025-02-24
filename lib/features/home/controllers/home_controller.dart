import 'dart:convert';

import 'package:get/get.dart';
import 'package:iftook/core/services/api_service.dart';
import 'package:iftook/core/services/shared_prefs.dart';
import 'package:iftook/features/profile/data/models/user.dart';

class HomeController extends GetxController {
  var profiles = <User>[].obs;
  var isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    fetchProfiles();
  }

  Future<void> fetchProfiles() async {
    try {
      isLoading(true);
      final token = await SharedPrefs.getUserTokenSharedPreference();
      final response = await ApiService.fetchDatingFeed();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final users = data['users'] as List;
        profiles.assignAll(users.map((user) => User.fromJson(user)).toList());
      } else {
        throw Exception('Failed to load profiles');
      }
    } catch (e) {
      print('Error fetching profiles: $e');
    } finally {
      isLoading(false);
    }
  }
}
