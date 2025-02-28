import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:iftook/features/auth/controllers/auth_controller.dart';
import 'package:path_provider/path_provider.dart';

import '../../calls/presentation/screens/video_call_screen.dart';
import '../../calls/presentation/screens/voice_call_screen.dart';
import 'notification_body.dart';

class NotificationHelper {
  static Future<void> initialize(
      FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin) async {
    var androidInitialize =
        const AndroidInitializationSettings('ic_notification');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();

    var initializationsSettings = InitializationSettings(
        android: androidInitialize, iOS: initializationSettingsIOS);

    flutterLocalNotificationsPlugin.initialize(initializationsSettings,
        onDidReceiveNotificationResponse:
            (NotificationResponse notificationResponse) async {
      String? payload = notificationResponse.payload;
      print("Payload: $payload");

      try {
        if (payload != null && payload.isNotEmpty) {
          NotificationBody notificationBody =
              NotificationBody.fromJson(jsonDecode(payload));
          print("Type: ${notificationBody.type}");

          // Navigate to the appropriate screen based on the call type
          if (notificationBody.type == 'voice') {
            Get.to(VoiceCallScreen(
              meetingId: jsonDecode(payload)['meetingId'],
              channel: jsonDecode(payload)['channelName'],
              token: jsonDecode(payload)['token'],
            ));
          } else if (notificationBody.type == 'video') {
            Get.to(VideoCallScreen(
              meetingId: jsonDecode(payload)['meetingId'],
              channel: jsonDecode(payload)['channelName'],
              token: jsonDecode(payload)['token'],
            ));
          }
        }
      } catch (e) {
        print("Error processing notification payload: $e");
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print(
          "onMessage: ${message.notification!.title}/${message.notification!.body}/${message.notification!.titleLocKey}");
      print("body: ${message.data}");
      // NotificationHelper.showNotification(
      //     message, flutterLocalNotificationsPlugin, false);
      Get.put(AuthController());
      if (await Get.find<AuthController>().isLoggedIn()) {
        NotificationHelper.showNotification(
            message, flutterLocalNotificationsPlugin, false);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage? message) {
      print("callOnMessageOpenApp");

      try {
        if (message != null && message.data.isNotEmpty) {
          NotificationBody _notificationBody =
              convertNotification(message.data);

          // Navigate to the appropriate screen based on the call type
          if (_notificationBody.type == 'voice') {
            Get.to(VoiceCallScreen(
              channel: "1953648cfe27a07",
              meetingId: "",
              token:
                  "007eJxTYAjuiYtVmnAhZ1vhjKkTrz9yDtiaknYppvTF5c9/DTt9TRIVGExTEk0MkiwNTVKS00wSDSwsUy2SklJTzU0TLY3MDM0tmI32pDcEMjKsXHOSkZEBAkF8fgZDS1NjMxOL5LRUI/NEA3MGBgBFwyNe",
            ));
          } else if (_notificationBody.type == 'video') {
            Get.to(VideoCallScreen(
              channel: "1953648cfe27a07",
              meetingId: "",
              token:
                  "007eJxTYAjuiYtVmnAhZ1vhjKkTrz9yDtiaknYppvTF5c9/DTt9TRIVGExTEk0MkiwNTVKS00wSDSwsUy2SklJTzU0TLY3MDM0tmI32pDcEMjKsXHOSkZEBAkF8fgZDS1NjMxOL5LRUI/NEA3MGBgBFwyNe",
            ));
          }
        }
      } catch (e) {
        print("Error processing notification: $e");
      }
    });
  }

  static Future<void> showNotification(RemoteMessage message,
      FlutterLocalNotificationsPlugin fln, bool data) async {
    if (!GetPlatform.isIOS) {
      String? _title;
      String? _body;
      String? _image;
      String playLoad = jsonEncode(message.data);

      if (data) {
        _title =
            message.data['title']?.replaceAll('_', ' ').toString().capitalize;
        _body = message.data['body'].replaceAll('_', ' ').toString();
      } else {
        _title = message.notification!.title
            ?.replaceAll('_', ' ')
            .toString()
            .capitalize;
        _body = message.notification!.body;
      }

      print("msg data: ${message.data.toString()}");

      // Determine if this is a call notification
      bool isCall =
          message.data['type'] == 'voice' || message.data['type'] == 'video';

      if (_image != null && _image.isNotEmpty) {
        try {
          await showBigPictureNotificationHiddenLargeIcon(
              _title!, _body!, playLoad, _image, fln, isCall);
        } catch (e) {
          await showBigTextNotification(_title!, _body!, playLoad, fln, isCall);
        }
      } else {
        await showBigTextNotification(_title!, _body!, playLoad, fln, isCall);
      }
    }
  }

  static Future<void> showBigTextNotification(String title, String body,
      String payload, FlutterLocalNotificationsPlugin fln, bool isCall) async {
    BigTextStyleInformation bigTextStyleInformation = BigTextStyleInformation(
      body,
      htmlFormatBigText: true,
      contentTitle: title,
      htmlFormatContentTitle: true,
    );

    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      isCall ? "call_channel" : "regular_channel",
      isCall ? "Call Notifications" : "Regular Notifications",
      channelDescription: "description",
      playSound: true,
      sound: isCall
          ? const UriAndroidNotificationSound(
              'content://settings/system/ringtone') // Use default ringtone
          : null, // No sound for regular notifications
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: isCall, // Wake the screen for calls
      styleInformation: bigTextStyleInformation,
    );

    NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await fln.show(isCall ? 1 : 0, title, body, platformChannelSpecifics,
        payload: payload);
  }

  static Future<void> showBigPictureNotificationHiddenLargeIcon(
      String title,
      String body,
      String payload,
      String image,
      FlutterLocalNotificationsPlugin fln,
      bool isCall) async {
    final String largeIconPath = await _downloadAndSaveFile(image, 'largeIcon');
    final String bigPicturePath =
        await _downloadAndSaveFile(image, 'bigPicture');
    final BigPictureStyleInformation bigPictureStyleInformation =
        BigPictureStyleInformation(
      FilePathAndroidBitmap(bigPicturePath),
      hideExpandedLargeIcon: false,
      contentTitle: title,
      htmlFormatContentTitle: true,
      summaryText: body,
      htmlFormatSummaryText: true,
    );

    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      isCall ? "call_channel" : "regular_channel",
      isCall ? "Call Notifications" : "Regular Notifications",
      channelDescription: "description",
      playSound: true,
      sound: isCall
          ? const UriAndroidNotificationSound(
              'content://settings/system/ringtone') // Use default ringtone
          : null, // No sound for regular notifications
      largeIcon: FilePathAndroidBitmap(largeIconPath),
      priority: Priority.max,
      fullScreenIntent: isCall, // Wake the screen for calls
      styleInformation: bigPictureStyleInformation,
      importance: Importance.max,
    );

    NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await fln.show(isCall ? 1 : 0, title, body, platformChannelSpecifics,
        payload: payload);
  }

  static Future<String> _downloadAndSaveFile(
      String url, String fileName) async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final String filePath = '${directory.path}/$fileName';
    final http.Response response = await http.get(Uri.parse(url));
    final File file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);
    return filePath;
  }

  static NotificationBody convertNotification(Map<String, dynamic> data) {
    return NotificationBody.fromJson(data);
  }
}

Future<dynamic> myBackgroundMessageHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print(
        "onBackground: ${message.notification!.title}/${message.notification!.body}/${message.notification!.titleLocKey}");
  }

  // Handle background notification for calls
  if (message.data['type'] == 'voice' || message.data['type'] == 'video') {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    await NotificationHelper.initialize(flutterLocalNotificationsPlugin);
    await NotificationHelper.showNotification(
        message, flutterLocalNotificationsPlugin, true);
  }
}
