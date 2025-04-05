import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefs {
  static String sharedPreferenceUserNameKey = 'USER_NAME_KEY';
  static String sharedPreferenceUserEmailKey = 'USER_EMAIL_KEY';
  static String sharedPreferenceUserIdKey = 'USER_ID_KEY';
  static String sharedPreferenceUserTokenKey = 'USER_TOKEN_KEY';
  static String sharedPreferenceUserProfileKey = 'USER_PROFILE_KEY';
  static const String instaTalkHistoryKey = 'instaTalkHistory';

  /// storing data in shared preferences (Local Storage)
  static Future<bool> saveUsernameSharedPreference(String username) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return await prefs.setString(sharedPreferenceUserNameKey, username);
  }

  static Future<bool> saveUserEmailSharedPreference(String userEmail) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return await prefs.setString(sharedPreferenceUserEmailKey, userEmail);
  }

  static Future<bool> saveUserIdSharedPreference(String userId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return await prefs.setString(sharedPreferenceUserIdKey, userId);
  }

  static Future<bool> saveUserTokenSharedPreference(String userToken) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return await prefs.setString(sharedPreferenceUserTokenKey, userToken);
  }

  static Future<bool> saveUserProfileSharedPreference(
      String userProfile) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return await prefs.setString(sharedPreferenceUserProfileKey, userProfile);
  }

  static Future<bool> saveInstaTalkHistory(List<String> userIds) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setStringList(instaTalkHistoryKey, userIds);
  }

  static Future<bool> saveTokens(
      String accessToken, String refreshToken) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('userAccessToken', accessToken);
    await prefs.setString('userRefreshToken', refreshToken);
    return true;
  }

  ///getting data from shared preferences (Local Storage)
  static Future<String?> getUsernameSharedPreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(sharedPreferenceUserNameKey);
  }

  static Future<String?> getUserEmailSharedPreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(sharedPreferenceUserEmailKey);
  }

  static Future<String?> getUserIdSharedPreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(sharedPreferenceUserIdKey);
  }

  static Future<String?> getUserTokenSharedPreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(sharedPreferenceUserTokenKey);
  }

  static Future<String?> getUserProfileSharedPreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(sharedPreferenceUserProfileKey);
  }

  static Future<List<String>> getInstaTalkHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(instaTalkHistoryKey) ?? [];
  }

  static Future<String?> getAccessToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('userAccessToken');
  }

  static Future<String?> getRefreshToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('userRefreshToken');
  }

  /// Clearing all data from shared preferences (Local Storage)
  static Future<bool> clearTokens() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('userAccessToken');
    await prefs.remove('userRefreshToken');
    return true;
  }

  static Future<void> clearUserSharedPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(sharedPreferenceUserNameKey);
    await prefs.remove(sharedPreferenceUserEmailKey);
    await prefs.remove(sharedPreferenceUserIdKey);
    await clearTokens(); // Clear tokens along with other data
    await prefs.remove(sharedPreferenceUserProfileKey);
  }
}
