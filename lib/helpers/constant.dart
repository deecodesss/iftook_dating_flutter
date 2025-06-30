import 'package:iftook/helpers/app_constants.dart';

class Constants {
  // Agora credentials for live streaming
  static const String agoraAppId = '5da40b914dcf4a089e8bbee75a926178';
  static const String agoraAppCertificate = 'b2e9d04ef46d4d29a608c74886d95880';

////CHANGE THIS ONE URL and ONE IN APPCONSTANTS.DART FILE FOR LOCAL TESTING
  // static const String socketUrl = 'http://localhost:3000';
  static const String socketUrl = AppConstants.URL;

  static const String apiBaseUrl = AppConstants.BASE_URL;

  // App name
  static const String appName = 'Iftook';

  // App version
  static const String appVersion = '1.0.0';

  // Default timeout duration for API calls (in seconds)
  static const int apiTimeoutDuration = 30;

  // Image placeholder URL
  static const String placeholderImageUrl = 'https://via.placeholder.com/150';

  // Default pagination limit
  static const int defaultPaginationLimit = 10;

  // Chat message pagination limit
  static const int chatMessageLimit = 50;

  // Default avatar placeholder
  static const String defaultAvatarPlaceholder =
      'assets/images/default_avatar.png';

  // Currency symbol
  static const String currencySymbol = '₹';
}
