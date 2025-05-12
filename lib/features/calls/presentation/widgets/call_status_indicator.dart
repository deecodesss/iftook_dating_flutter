import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/features/calls/controllers/call_status_controller.dart';
import 'package:iftook/helpers/app_colors.dart';

/// A widget to show a user's call status (whether they are in a call or not)
///
/// This widget automatically updates when the user's call status changes.
/// It can be used in various parts of the UI like friend cards, profile cards, etc.
class CallStatusIndicator extends StatelessWidget {
  /// The ID of the user to check
  final String userId;

  /// Whether to show text along with the indicator
  final bool showText;

  /// Size of the indicator dot (default: 10)
  final double size;

  /// Text style for the status text
  final TextStyle? textStyle;

  /// Whether to display horizontally (dot + text) or vertically
  final bool horizontal;

  /// Spacing between dot and text
  final double spacing;

  /// Optional widget to show when the user is in a call
  final Widget? inCallWidget;

  /// Optional text to show when in a call
  final String? inCallText;

  /// Optional text to show when in a voice call
  final String? inVoiceCallText;

  /// Optional text to show when in a video call
  final String? inVideoCallText;

  const CallStatusIndicator({
    Key? key,
    required this.userId,
    this.showText = true,
    this.size = 10,
    this.textStyle,
    this.horizontal = true,
    this.spacing = 4.0,
    this.inCallWidget,
    this.inCallText,
    this.inVoiceCallText,
    this.inVideoCallText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Make sure CallStatusController is registered
    if (!Get.isRegistered<CallStatusController>()) {
      Get.put(CallStatusController());
    }

    return StreamBuilder<Map<String, dynamic>>(
      stream: Get.find<CallStatusController>().getUserCallStatusStream(userId),
      initialData: {'inCall': false},
      builder: (context, snapshot) {
        final bool inCall = snapshot.data?['inCall'] ?? false;
        final String? callType = snapshot.data?['callType'];

        // If custom widget is provided, use it instead of the default
        if (inCall && inCallWidget != null) {
          return inCallWidget!;
        }

        // Define the dot based on call status
        final Widget dot = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: inCall ? Colors.red : Colors.transparent,
          ),
        );

        // If text should not be shown, just return the dot
        if (!showText) {
          return dot;
        }

        // Determine the text to show
        String statusText = '';
        if (inCall) {
          if (callType == 'voice' && inVoiceCallText != null) {
            statusText = inVoiceCallText!;
          } else if (callType == 'video' && inVideoCallText != null) {
            statusText = inVideoCallText!;
          } else if (inCallText != null) {
            statusText = inCallText!;
          } else {
            statusText = '• In ${callType == 'voice' ? 'Voice' : 'Video'} Call';
          }
        }

        final Widget text = Text(
          statusText,
          style: textStyle ??
              TextStyle(
                fontSize: 12,
                color: inCall ? Colors.red : Colors.transparent,
                fontWeight: FontWeight.bold,
              ),
        );

        // Arrange widgets according to orientation
        if (horizontal) {
          return inCall
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    dot,
                    SizedBox(width: spacing),
                    text,
                  ],
                )
              : Container(); // Return empty container when not in call
        } else {
          return inCall
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    dot,
                    SizedBox(height: spacing),
                    text,
                  ],
                )
              : Container(); // Return empty container when not in call
        }
      },
    );
  }
}

/// A simpler version of the call status indicator that only shows an icon
class CallStatusIcon extends StatelessWidget {
  /// The ID of the user to check
  final String userId;

  /// Size of the icon
  final double size;

  /// Icon to show when user is in a voice call
  final IconData voiceCallIcon;

  /// Icon to show when user is in a video call
  final IconData videoCallIcon;

  /// Color of the icon
  final Color color;

  const CallStatusIcon({
    Key? key,
    required this.userId,
    this.size = 16.0,
    this.voiceCallIcon = Icons.phone_in_talk,
    this.videoCallIcon = Icons.videocam,
    this.color = Colors.red,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Make sure CallStatusController is registered
    if (!Get.isRegistered<CallStatusController>()) {
      Get.put(CallStatusController());
    }

    return StreamBuilder<Map<String, dynamic>>(
      stream: Get.find<CallStatusController>().getUserCallStatusStream(userId),
      initialData: {'inCall': false},
      builder: (context, snapshot) {
        final bool inCall = snapshot.data?['inCall'] ?? false;
        final String? callType = snapshot.data?['callType'];

        if (!inCall) {
          return Container(); // Return empty container when not in call
        }

        // Show the appropriate icon based on call type
        return Icon(
          callType == 'voice' ? voiceCallIcon : videoCallIcon,
          color: color,
          size: size,
        );
      },
    );
  }
}
