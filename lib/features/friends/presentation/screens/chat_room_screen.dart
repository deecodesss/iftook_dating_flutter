import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iftook/core/services/shared_prefs.dart';
import 'package:iftook/features/calls/presentation/screens/laoding_voice_call_screen.dart';
import 'package:iftook/features/calls/presentation/screens/loading_video_call_screen.dart';
import 'package:iftook/features/calls/presentation/screens/video_call_screen.dart';
import 'package:iftook/features/calls/presentation/screens/voice_call_screen.dart';
import 'package:iftook/features/calls/services/chat_call_service.dart';
import 'package:iftook/features/friends/data/message.dart';
import 'package:iftook/features/profile/data/models/user.dart';
import 'package:iftook/features/profile/presentation/screens/add_review_screen.dart';
import 'package:iftook/features/shared/controllers/user_online_controller.dart';
import 'package:iftook/features/shared/widgets/user_online_indicator.dart';
import 'package:iftook/features/shared/widgets/rating_review_widget.dart';
import 'package:iftook/helpers/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:iftook/features/home/data/enums/meeting_type.dart';
import 'package:iftook/features/home/presentation/screens/schedule_meeting_screen.dart';
import 'package:iftook/features/friends/data/chatroom.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/services/api_service.dart';
import '../../controllers/chat_controller.dart';

class ChatRoomScreen extends StatefulWidget {
  final User profile;
  final bool isTrial;
  final bool isInstaTalk;
  final bool isFriend;
  final int duration;
  final String? existingChatRoomId;
  final Function? onSessionEnd;
  final bool isInstaTalkSender;
  final DateTime? scheduledTime;

  const ChatRoomScreen({
    super.key,
    required this.profile,
    required this.duration,
    this.isTrial = false,
    this.isInstaTalk = false,
    this.isFriend = false,
    this.existingChatRoomId,
    this.onSessionEnd,
    this.isInstaTalkSender = false,
    this.scheduledTime,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  final FocusNode _focusNode = FocusNode();
  final ChatController _chatController = Get.put(ChatController());
  String? currentUserId;
  static const double MESSAGE_FEE = 10;

  Timer? _sessionTimer;
  Timer? _autoPaymentTimer;
  int _remainingSeconds = 0;
  int _elapsedSeconds = 0; // Add elapsed seconds counter for growing timer
  bool _sessionExpired = false;
  bool _showingPaymentPrompt = false;

  bool _hasRenewedSession = false;
  bool _isRenewing = false;

  // Auto-payment state
  int _elapsedMinutes = 0;
  int _lastBilledMinute = 0;

  bool _isNearBottom = true;

  DateTime? _meetingStartTime;
  DateTime? _meetingEndTime;

  @override
  void initState() {
    super.initState();
    _initializeChatRoom();
    _focusNode.addListener(_onFocusChange);

    _chatController.messages.listen((_) {
      if (_isNearBottom) {
        _chatController.scrollToBottom();
      }
    });

    _chatController.scrollController.addListener(_onScroll);

    // Initialize meeting time tracking
    if (!widget.isFriend) {
      if (widget.isInstaTalk) {
        // For InstaTalk
        if (widget.isTrial) {
          // Trial mode - use short timer (30 seconds)
          print('Starting trial InstaTalk with 30 seconds');
          _remainingSeconds = 30;
          _startSessionTimer();
        } else {
          // Paid InstaTalk - start growing timer with auto-billing
          final liveRate = widget.profile.earnings?.liveRate ?? 0;
          print('Starting regular InstaTalk with rate: $liveRate');

          if (_chatController.isFreeChat(liveRate)) {
            // Free chat - just use regular timer
            _remainingSeconds = widget.duration * 60;
            _startSessionTimer();
          } else {
            // Paid chat with auto-billing
            _elapsedSeconds = 0; // Start timer from 0
            _startGrowingTimer(); // Use growing timer for paid InstaTalk
            _startAutoPaymentTimer();
          }
        }
      } else if (widget.scheduledTime != null) {
        // For scheduled meetings, use the scheduled time to determine timer
        _meetingStartTime = widget.scheduledTime;
        _meetingEndTime =
            _meetingStartTime!.add(Duration(minutes: widget.duration));
        _updateRemainingTimeFromSchedule();
        _startSessionTimer();

        // For paid meetings, also start auto-billing
        final chatRate = widget.profile.earnings?.chatRate ?? 0;
        if (!_chatController.isFreeChat(chatRate)) {
          _startAutoPaymentTimer();
        }
      } else if (widget.duration > 0) {
        // Fallback for meetings without scheduled time
        _meetingStartTime = DateTime.now();
        _meetingEndTime =
            _meetingStartTime!.add(Duration(minutes: widget.duration));
        _remainingSeconds = widget.duration * 60;
        _startSessionTimer();

        // For paid meetings, also start auto-billing
        final chatRate = widget.profile.earnings?.chatRate ?? 0;
        if (!_chatController.isFreeChat(chatRate)) {
          _startAutoPaymentTimer();
        }
      }
    }
  }

  void _onScroll() {
    if (_chatController.scrollController.hasClients) {
      final maxScroll =
          _chatController.scrollController.position.maxScrollExtent;
      final currentScroll = _chatController.scrollController.offset;
      _isNearBottom = maxScroll - currentScroll <= 100;
    }
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 300),
          () => _chatController.scrollToBottom());
    }
  }

  Future<void> _initializeChatRoom() async {
    currentUserId = await SharedPrefs.getUserIdSharedPreference();
    if (currentUserId != null) {
      if (widget.existingChatRoomId != null) {
        await _chatController.fetchMessages();
        _chatController.startPolling();
      } else {
        await _chatController.openChatRoom(
          currentUserId.toString(),
          widget.profile.sId.toString(),
        );
      }
    }
  }

  bool _isFreeChatSession() {
    if (widget.isFriend) {
      print('ChatRoomScreen: Chat is free because users are friends');
      return true;
    }

    // For InstaTalk, check liveRate
    if (widget.isInstaTalk) {
      final liveRate = widget.profile.earnings?.liveRate;
      if (liveRate == null) {
        print('ChatRoomScreen: InstaTalk is free because liveRate is null');
        return true;
      } else if (liveRate <= 0) {
        print(
            'ChatRoomScreen: InstaTalk is free because liveRate is $liveRate (≤0)');
        return true;
      } else {
        print('ChatRoomScreen: InstaTalk is PAID with liveRate of $liveRate');
        return false;
      }
    }
    // For regular chats/meetings, check chatRate
    else {
      final chatRate = widget.profile.earnings?.chatRate;
      print("Chat rate: $chatRate");
      if (chatRate == null) {
        print("Chat rate: $chatRate");
        print('ChatRoomScreen: Meeting chat is free because chatRate is null');
        return true;
      } else if (chatRate <= 0) {
        print(
            'ChatRoomScreen: Meeting chat is free because chatRate is $chatRate (≤0)');
        return true;
      } else {
        print(
            'ChatRoomScreen: Meeting chat is PAID with chatRate of $chatRate');
        return false;
      }
    }
  }

  // Add method to update remaining time based on scheduled time
  void _updateRemainingTimeFromSchedule() {
    if (_meetingEndTime != null) {
      final now = DateTime.now();
      final difference = _meetingEndTime!.difference(now);

      print(
          'ChatRoomScreen: Meeting scheduled from ${_meetingStartTime?.toString() ?? "N/A"} to ${_meetingEndTime?.toString() ?? "N/A"}');
      print('ChatRoomScreen: Current time is ${now.toString()}');

      if (difference.isNegative) {
        _remainingSeconds = 0;
        _sessionExpired = true;
        print('ChatRoomScreen: Meeting has already ended');
      } else {
        _remainingSeconds = difference.inSeconds;
        print(
            'ChatRoomScreen: Meeting has $_remainingSeconds seconds remaining');
      }
    }
  }

  void _startGrowingTimer() {
    _sessionTimer?.cancel();

    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedSeconds++;

        // Calculate elapsed minutes for payment tracking
        _elapsedMinutes = _elapsedSeconds ~/ 60;
      });
    });
  }

  void _startSessionTimer() {
    _sessionTimer?.cancel();

    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        // For scheduled meetings, recalculate time from schedule
        if (!widget.isInstaTalk && widget.scheduledTime != null) {
          _updateRemainingTimeFromSchedule();
        } else {
          // For InstaTalk or unscheduled meetings, just decrement
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          }
        }

        // Calculate elapsed minutes for payment tracking
        final elapsed = (widget.duration * 60) - _remainingSeconds;
        _elapsedMinutes = elapsed ~/ 60;

        // Check if session has expired
        if (_remainingSeconds <= 0) {
          _sessionTimer?.cancel();
          _autoPaymentTimer?.cancel();

          if (!_showingPaymentPrompt && !_sessionExpired) {
            _sessionExpired = true;
            _showingPaymentPrompt = true;

            // For trial sessions, just show the session ended dialog
            if (widget.isInstaTalk && widget.isTrial) {
              _showTrialEndedDialog();
            } else if (widget.isInstaTalk) {
              _showInstaTalkEndedDialog();
            } else {
              _showMeetingEndedDialog();
            }
          }
        }
      });
    });
  }

  void _startAutoPaymentTimer() {
    // Auto-payment timer checks every 10 seconds if we need to bill for another minute
    _autoPaymentTimer?.cancel();
    _autoPaymentTimer =
        Timer.periodic(const Duration(seconds: 10), (timer) async {
      // Check if we need to bill for another minute
      if (_elapsedMinutes > _lastBilledMinute &&
          !_sessionExpired &&
          !_isFreeChatSession()) {
        // Calculate minutes to bill
        final minutesToBill = _elapsedMinutes - _lastBilledMinute;

        // Only proceed if there are actually minutes to bill
        if (minutesToBill > 0) {
          print('Auto-billing for $minutesToBill minutes');

          try {
            // Get rate based on chat type
            final rate = widget.isInstaTalk
                ? widget.profile.earnings?.liveRate ?? 0.0
                : widget.profile.earnings?.chatRate ?? 0.0;

            // Check if we have enough balance
            await _chatController.fetchWalletBalance();

            if (_chatController.userWalletBalance.value < rate) {
              // Not enough balance, stop timers and show topup dialog
              _autoPaymentTimer?.cancel();
              _sessionTimer?.cancel();
              _sessionExpired = true;
              _showInsufficientBalanceDialog();
              return;
            }

            // Process payment silently
            final success = await _chatController.purchaseChatSession(
              widget.profile.sId.toString(),
              rate,
              minutes: minutesToBill,
              silent: true, // Don't show success dialogs
            );

            if (success) {
              // Update the last billed minute
              _lastBilledMinute = _elapsedMinutes;
              print(
                  'Successfully billed for $minutesToBill minutes. Last billed minute: $_lastBilledMinute');
            } else {
              // Payment failed
              _showPaymentFailedDialog();
              _autoPaymentTimer?.cancel();
              _sessionTimer?.cancel();
              _sessionExpired = true;
            }
          } catch (e) {
            print('Auto-payment error: $e');
            _showPaymentFailedDialog();
            _autoPaymentTimer?.cancel();
            _sessionTimer?.cancel();
            _sessionExpired = true;
          }
        }
      }
    });
  }

  void _showInsufficientBalanceDialog() {
    Get.dialog(
      WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Insufficient Balance',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Your wallet balance is too low to continue this session.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              Text(
                'Current balance: ₹${_chatController.userWalletBalance.value.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text(
                'Would you like to add funds to your wallet?',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Get.back();
                Get.back(); // Return to previous screen
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
              ),
              onPressed: () {
                Get.back();
                Get.toNamed('/wallet/topup');
              },
              child: const Text('Add Funds'),
            ),
          ],
        ),
      ),
      barrierDismissible: false,
    );
  }

  void _showPaymentFailedDialog() {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Payment Failed',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'There was an error processing your payment. The session has been ended.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              Get.back(); // Return to previous screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showTrialEndedDialog() {
    if (_isFreeChatSession()) {
      return;
    }

    _showingPaymentPrompt = true;
    final liveRate = widget.profile.earnings?.liveRate ?? 150.0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Trial Session Ended',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your 30-second trial session with ${widget.profile.name} has ended.',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            const Text(
              'Would you like to continue with a paid session?',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Text(
              '₹${liveRate.toStringAsFixed(2)} per minute',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Get.back();
            },
            child: const Text('End Chat'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _purchaseChat(minutes: 1, isInstaTalk: true),
            child: const Text('Continue (1 min)'),
          ),
        ],
      ),
    );
  }

  void _showInstaTalkEndedDialog() {
    if (_isFreeChatSession()) {
      return;
    }

    _showingPaymentPrompt = true;
    final liveRate = widget.profile.earnings?.liveRate ?? 150.0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'InstaTalk Session Ended',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your InstaTalk session with ${widget.profile.name} has ended.',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            const Text(
              'Would you like to continue?',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Text(
              'Rate: ₹${liveRate.toStringAsFixed(2)} per minute',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Get.back();
            },
            child: const Text('End Chat'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _purchaseChat(minutes: 1, isInstaTalk: true),
            child: const Text('Continue (1 min)'),
          ),
        ],
      ),
    );
  }

  void _showMeetingEndedDialog() {
    if (_isFreeChatSession()) {
      return;
    }

    _showingPaymentPrompt = true;
    final chatRate = widget.profile.earnings?.chatRate ?? 150.0;
    final perMinuteRate = chatRate;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Meeting Session Ended',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your meeting session with ${widget.profile.name} has ended.',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            const Text(
              'Would you like to continue?',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Text(
              'Rate: ₹${perMinuteRate.toStringAsFixed(2)} per minute',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Get.back();
            },
            child: const Text('End Chat'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _purchaseChat(minutes: 1, isInstaTalk: false),
            child: const Text('Continue (1 min)'),
          ),
        ],
      ),
    );
  }

  void _purchaseChat({int minutes = 1, bool isInstaTalk = false}) async {
    // Use appropriate rate based on the chat type
    final rate = isInstaTalk
        ? widget.profile.earnings?.liveRate ?? 150.0
        : widget.profile.earnings?.chatRate ?? 150.0;

    final perMinuteRate =
        isInstaTalk ? rate : _chatController.calculatePerMinuteRate(rate);
    final finalAmount = perMinuteRate * minutes;

    setState(() => _isRenewing = true);

    try {
      final success = await _chatController.purchaseChatSession(
        widget.profile.sId.toString(),
        rate,
        minutes: minutes,
      );

      if (success) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        setState(() {
          _sessionExpired = false;
          _hasRenewedSession = true;
          _isRenewing = false;

          // Update the meeting end time for scheduled meetings
          if (!isInstaTalk && _meetingEndTime != null) {
            _meetingEndTime = DateTime.now().add(Duration(minutes: minutes));
            _updateRemainingTimeFromSchedule();
          } else {
            _remainingSeconds = minutes * 60;
          }

          _showingPaymentPrompt = false;
          _lastBilledMinute = 0; // Reset billing counter
          _elapsedMinutes = 0; // Reset elapsed counter
        });

        _startSessionTimer();
        _startAutoPaymentTimer(); // Restart auto payment

        if (Navigator.canPop(context)) {
          Get.snackbar(
            'Success',
            'Session renewed for $minutes minute${minutes > 1 ? 's' : ''}!',
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
        }
      } else {
        throw Exception('Failed to purchase session');
      }
    } catch (e) {
      setState(() => _isRenewing = false);
      Get.snackbar(
        'Error',
        'Failed to renew session: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _autoPaymentTimer?.cancel();
    _chatController.stopPolling();
    _chatController.scrollController.removeListener(_onScroll);
    _messageController.dispose();
    _amountController.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();

    if (_hasRenewedSession) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.to(
          () => AddReviewScreen(userId: widget.profile.sId!),
          fullscreenDialog: true,
          popGesture: false,
        );
      });
    }

    super.dispose();
  }

  Future<void> _showSendMoneyDialog() async {
    _amountController.clear();
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.secondaryBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Send Money',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(() => Text(
                  'Available Balance: ₹${_chatController.userWalletBalance.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                )),
            const SizedBox(height: 15),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter amount',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                prefixText: '₹ ',
                prefixStyle: const TextStyle(color: Colors.white),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.primaryColor)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          Obx(() => TextButton(
                onPressed: _chatController.isTransferring.value
                    ? null
                    : () async {
                        final amount = double.tryParse(_amountController.text);
                        if (amount != null && amount > 0) {
                          Navigator.pop(context);
                          bool success = await _chatController.sendMoney(
                              widget.profile.sId.toString(), amount);
                          if (success) {
                            _sendMoneyMessage(amount);
                          }
                        } else {
                          Get.snackbar(
                            'Invalid Amount',
                            'Please enter a valid amount',
                            backgroundColor: Colors.red,
                            colorText: Colors.white,
                          );
                        }
                      },
                child: _chatController.isTransferring.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryColor,
                        ),
                      )
                    : const Text(
                        'Send',
                        style: TextStyle(color: AppColors.primaryColor),
                      ),
              )),
        ],
      ),
    );
  }

  void _sendMoneyMessage(double amount) {
    _chatController.sendMessage(
        currentUserId.toString(),
        _chatController.chatRoom.value!.sId.toString(),
        "Sent ₹${amount.toStringAsFixed(2)}");
  }

  Future<bool> _showPaymentRequiredDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.secondaryBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Payment Required',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              'To send this message, you need to pay \₹${MESSAGE_FEE.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Pay & Send',
                  style: TextStyle(color: AppColors.primaryColor),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showUnfriendDialog() {
    FocusScope.of(context).unfocus();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.secondaryBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Unfriend ${widget.profile.name}?',
          style: const TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to unfriend this person? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          StatefulBuilder(
            builder: (context, setState) {
              bool isLoading = false;
              return TextButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        try {
                          setState(() => isLoading = true);

                          final success = await _chatController.unfriend(
                              currentUserId.toString(),
                              widget.profile.sId.toString());

                          if (success) {
                            Navigator.pop(context);
                            Get.snackbar(
                              'Success',
                              '${widget.profile.name} has been unfriended',
                              backgroundColor: Colors.green,
                              colorText: Colors.white,
                            );
                          } else {
                            Navigator.pop(context);
                            Get.snackbar(
                              'Error',
                              'Failed to unfriend. Please try again.',
                              backgroundColor: Colors.red,
                              colorText: Colors.white,
                            );
                          }
                        } catch (e) {
                          Navigator.pop(context);
                          Get.snackbar(
                            'Error',
                            'An error occurred: ${e.toString()}',
                            backgroundColor: Colors.red,
                            colorText: Colors.white,
                          );
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.redColor,
                        ),
                      )
                    : const Text(
                        'Unfriend',
                        style: TextStyle(color: AppColors.redColor),
                      ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showMoreOptions() {
    FocusScope.of(context).unfocus();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.secondaryBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (widget.isFriend)
                ListTile(
                  leading: const Icon(Icons.person_remove,
                      color: AppColors.redColor),
                  title: const Text(
                    'Unfriend',
                    style: TextStyle(color: AppColors.redColor),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showUnfriendDialog();
                  },
                ),
              const ListTile(
                leading: Icon(Icons.block, color: Colors.white70),
                title: Text(
                  'Block User',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              const ListTile(
                leading: Icon(Icons.report, color: Colors.white70),
                title: Text(
                  'Report User',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String label,
    Color? color,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
        tooltip: label,
      ),
    );
  }

  void _handleChatVideoCall() async {
    try {
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      final callData = await ChatCallService.initiateChatCall(
        widget.profile.sId!,
        'video',
      );

      Get.back(); // Close loading dialog

      if (callData != null) {
        print('Video call initialized with data: $callData');

        await Get.to(() => VideoCallLoadingScreen(
              participant: widget.profile,
              type: "video",
              scheduleTime: DateTime.now(),
              meetingId: callData['meetingId'],
              token: callData['token'],
              channel: callData['channelName'],
              isTrial: widget.isTrial,
              isInstaTalk: widget.isInstaTalk,
            ));
      }
    } catch (e) {
      Get.back(); // Close loading dialog
      if (e.toString().contains('already in progress')) {
        Get.snackbar(
          'Please Wait',
          'A call request is already being processed',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Error',
          'Could not start video call: ${e.toString()}',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  void _handleChatVoiceCall() async {
    try {
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      final callData = await ChatCallService.initiateChatCall(
        widget.profile.sId!,
        'voice',
      );

      Get.back(); // Close loading dialog

      if (callData != null) {
        print('Voice call initialized with data: $callData');

        await Get.to(() => VoiceCallLoadingScreen(
              participant: widget.profile,
              type: "voice",
              scheduleTime: DateTime.now(),
              meetingId: callData['meetingId'],
              token: callData['token'],
              channel: callData['channelName'],
              isTrial: widget.isTrial,
              isInstaTalk: widget.isInstaTalk,
            ));
      }
    } catch (e) {
      Get.back(); // Close loading dialog
      if (e.toString().contains('already in progress')) {
        Get.snackbar(
          'Please Wait',
          'A call request is already being processed',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Error',
          'Could not start voice call: ${e.toString()}',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            scrolledUnderElevation: 0,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                FocusScope.of(context).unfocus();
                Navigator.pop(context);
              },
            ),
            title: Row(
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: widget.profile.photos != null &&
                              widget.profile.photos!.isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                widget.profile.photos![0],
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              ),
                            )
                          : CircleAvatar(
                              backgroundColor: AppColors.primaryBackground,
                              radius: 25,
                            ),
                    ),
                    _buildOnlineIndicator(),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.profile.name.toString(),
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      _buildOnlineStatusText(),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              if (widget.isFriend) ...[
                _buildActionButton(
                  icon: Icons.videocam,
                  onPressed: _handleChatVideoCall, // Use new handler
                  label: 'Video Call',
                  color: AppColors.primaryColor,
                ),
                _buildActionButton(
                  icon: Icons.call,
                  onPressed: _handleChatVoiceCall, // Use new handler
                  label: 'Voice Call',
                  color: AppColors.greenColor,
                ),
              ],
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onPressed: _showMoreOptions,
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Chat status banner - different based on chat type
                if (_isFreeChatSession()) ...[
                  // Free chat banner - either friend or free rate
                  !widget.isFriend
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 16),
                          color: Colors.green.withOpacity(0.2),
                          child: Row(
                            children: [
                              widget.isFriend
                                  ? const Icon(Icons.check_circle,
                                      color: Colors.green)
                                  : SizedBox(),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.isFriend
                                      ? 'Unlimited chat with friend'
                                      : 'Free chat session',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : SizedBox()
                ] else if (!_sessionExpired) ...[
                  // Timer banner for paid chats - now using updated method
                  _buildTimerBanner(),
                ],

                // Expired session banner
                if (!_isFreeChatSession() && _sessionExpired)
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.redAccent.withOpacity(0.1),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber,
                            color: Colors.redAccent),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Your session has ended. Purchase more time to continue.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                          ),
                          onPressed: () {
                            if (widget.isInstaTalk) {
                              _showInstaTalkEndedDialog();
                            } else {
                              _showMeetingEndedDialog();
                            }
                          },
                          child: const Text('Continue'),
                        ),
                      ],
                    ),
                  ),

                // Message list
                Expanded(
                  child: Obx(() {
                    if (_chatController.isLoading.value) {
                      return _buildSkeletonLoading();
                    } else if (_chatController.messages.isEmpty) {
                      return const Center(
                        child: Text(
                          'Start a conversation!',
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    } else {
                      return ListView.builder(
                        controller: _chatController.scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        itemCount: _chatController.messages.length,
                        itemBuilder: (context, index) {
                          final message = _chatController.messages[index];

                          // Check if we need to show a date header
                          final showDateHeader = index == 0 ||
                              !_isSameDay(
                                  DateTime.parse(_chatController
                                      .messages[index - 1].createdAt
                                      .toString()),
                                  DateTime.parse(message.createdAt.toString()));

                          return Column(
                            children: [
                              if (showDateHeader)
                                _buildDateHeader(DateTime.parse(
                                    message.createdAt.toString())),
                              _buildMessageBubble(message),
                            ],
                          );
                        },
                      );
                    }
                  }),
                ),

                // Chat input field
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  decoration: const BoxDecoration(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(25)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            focusNode: _focusNode,
                            style: const TextStyle(color: Colors.white),
                            textCapitalization: TextCapitalization.sentences,
                            keyboardType: TextInputType.multiline,
                            maxLines: 4,
                            minLines: 1,
                            enabled: _isFreeChatSession() || !_sessionExpired,
                            decoration: InputDecoration(
                              hintText: (!_isFreeChatSession() &&
                                      _sessionExpired)
                                  ? 'Session ended. Purchase time to continue.'
                                  : 'Type a message...',
                              hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.6)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: AppColors.primaryBackground,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: (!_isFreeChatSession() && _sessionExpired)
                                ? Colors.grey
                                : AppColors.primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            iconSize: 20,
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.send, color: Colors.white),
                            onPressed:
                                (!_isFreeChatSession() && _sessionExpired)
                                    ? null
                                    : _sendMessage,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            iconSize: 20,
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.currency_rupee,
                                color: Colors.white),
                            onPressed: _showSendMoneyDialog,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isRenewing)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  void _sendMessage() {
    if (_messageController.text.isEmpty) return;

    _isNearBottom = true;

    _chatController.sendMessage(
      currentUserId.toString(),
      _chatController.chatRoom.value!.sId.toString(),
      _messageController.text,
    );

    _messageController.clear();
    FocusScope.of(context).unfocus();
  }

  Widget _buildMessageBubble(Message message) {
    bool isSentByMe = message.senderId!.sId.toString() == currentUserId;

    String formattedTime = DateFormat('hh:mm a')
        .format(DateTime.parse(message.createdAt.toString()).toLocal());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment:
            isSentByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isSentByMe) ...[
            if (widget.profile.photos != null &&
                widget.profile.photos!.isNotEmpty)
              ClipOval(
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: CachedNetworkImage(
                    imageUrl: widget.profile.photos![0],
                    placeholder: (context, url) => const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.person, size: 20),
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
              const CircleAvatar(radius: 20),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSentByMe
                    ? AppColors.primaryColor
                    : AppColors.secondaryBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formattedTime,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isSentByMe) ...[
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Widget _buildDateHeader(DateTime date) {
    String dateText;
    final now = DateTime.now();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));

    if (_isSameDay(date, now)) {
      dateText = 'Today';
    } else if (_isSameDay(date, yesterday)) {
      dateText = 'Yesterday';
    } else {
      dateText = DateFormat('MMMM d, yyyy').format(date);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.white.withOpacity(0))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                dateText,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.white.withOpacity(0))),
        ],
      ),
    );
  }

  // Helper method to format elapsed time for growing timer
  String _formatElapsedTime() {
    final minutes = _elapsedSeconds ~/ 60;
    final seconds = _elapsedSeconds % 60;

    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '$hours:${mins.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
  }

  // Helper method to format remaining time for countdown timer
  String _formatRemainingTime() {
    if (_remainingSeconds < 60) {
      return '$_remainingSeconds seconds remaining';
    } else {
      final minutes = _remainingSeconds ~/ 60;
      final seconds = _remainingSeconds % 60;

      if (minutes >= 60) {
        final hours = minutes ~/ 60;
        final mins = minutes % 60;
        return '$hours:${mins.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} remaining';
      } else {
        return '$minutes:${seconds.toString().padLeft(2, '0')} remaining';
      }
    }
  }

  // Update banner display to show different timers based on chat type
  Widget _buildTimerBanner() {
    // For regular InstaTalk (not trial) - show growing timer
    if (widget.isInstaTalk && !widget.isTrial && !_isFreeChatSession()) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        color: Colors.green.withOpacity(0.2),
        child: Row(
          children: [
            const Icon(Icons.timer, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row(children: [
                  Text(
                    '${_formatElapsedTime()} ',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    '₹${(widget.profile.earnings?.liveRate ?? 0).toStringAsFixed(2)}/min',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  // ])
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Balance: ₹${_chatController.userWalletBalance.value.toStringAsFixed(2)}',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
    // For trial InstaTalk - show countdown timer
    else if (widget.isInstaTalk && widget.isTrial) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        color: Colors.amber.withOpacity(0.2),
        child: Row(
          children: [
            const Icon(Icons.timer, color: Colors.amber),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _formatRemainingTime(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 100,
              child: LinearProgressIndicator(
                value: _remainingSeconds / 30,
                backgroundColor: Colors.grey[800],
                color: Colors.amber,
                minHeight: 5,
              ),
            ),
          ],
        ),
      );
    }
    // For Meeting timer banner with scheduled time info
    else {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        color: Colors.blue.withOpacity(0.2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Row(
              children: [
                const Icon(Icons.timer, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatRemainingTime(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: LinearProgressIndicator(
                    value: _meetingStartTime != null && _meetingEndTime != null
                        ? 1 -
                            (_remainingSeconds /
                                (_meetingEndTime!
                                    .difference(_meetingStartTime!)
                                    .inSeconds))
                        : _remainingSeconds / (widget.duration * 60),
                    backgroundColor: Colors.grey[800],
                    color: Colors.blue,
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
  }

  Widget _buildSkeletonLoading() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: 8, // Reduced count for better UX
      itemBuilder: (context, index) {
        final isMe = index % 2 == 0;
        final messageWidth =
            isMe ? 0.7 : 0.6; // Different widths for sent/received messages

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 4,
            bottom: 4,
          ),
          child: Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe) ...[
                // Avatar skeleton
                Shimmer.fromColors(
                  baseColor: Colors.grey[800]!,
                  highlightColor: Colors.grey[700]!,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // Message skeleton
              Flexible(
                child: Shimmer.fromColors(
                  baseColor: Colors.grey[800]!,
                  highlightColor: Colors.grey[700]!,
                  child: Container(
                    width: MediaQuery.of(context).size.width * messageWidth,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Message text skeleton
                        Container(
                          height: 16,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Time skeleton
                        Container(
                          height: 12,
                          width: 60,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 8),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildOnlineIndicator() {
    final userOnlineController = Get.find<UserOnlineController>();

    return Positioned(
      right: 0,
      bottom: 0,
      child: StreamBuilder<bool>(
        stream:
            userOnlineController.getUserStatusStream(widget.profile.sId ?? ''),
        builder: (context, snapshot) {
          final bool isOnline = snapshot.data ?? false;

          return Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: isOnline ? Colors.green : Colors.grey,
              border: Border.all(
                color: AppColors.primaryBackground,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(6),
              boxShadow: isOnline
                  ? [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.4),
                        blurRadius: 4,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildOnlineStatusText() {
    final userOnlineController = Get.find<UserOnlineController>();

    return StreamBuilder<bool>(
      stream:
          userOnlineController.getUserStatusStream(widget.profile.sId ?? ''),
      builder: (context, snapshot) {
        final bool isOnline = snapshot.data ?? false;

        return Text(
          isOnline ? 'Online' : 'Offline',
          style: GoogleFonts.manrope(
            color: isOnline ? Colors.green : Colors.white.withOpacity(0.6),
            fontSize: 12,
          ),
        );
      },
    );
  }
}
