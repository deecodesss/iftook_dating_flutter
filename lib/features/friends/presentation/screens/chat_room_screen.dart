import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iftook/core/services/shared_prefs.dart';
import 'package:iftook/features/calls/presentation/screens/laoding_voice_call_screen.dart';
import 'package:iftook/features/calls/presentation/screens/loading_video_call_screen.dart';
import 'package:iftook/features/friends/data/message.dart';
import 'package:iftook/features/profile/data/models/user.dart';
import 'package:iftook/features/profile/presentation/screens/add_review_screen.dart';
import 'package:iftook/features/shared/widgets/rating_review_widget.dart';
import 'package:iftook/helpers/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:iftook/features/home/data/enums/meeting_type.dart';
import 'package:iftook/features/home/presentation/screens/schedule_meeting_screen.dart';
import 'package:iftook/features/friends/data/chatroom.dart';

import '../../../../core/services/api_service.dart';
import '../../controllers/chat_controller.dart';

class ChatRoomScreen extends StatefulWidget {
  final User profile;
  final bool isTrial;
  final bool isInstaTalk;
  final int instaTalkDuration;
  final String? existingChatRoomId;
  final Function? onSessionEnd;
  final bool isInstaTalkSender;

  const ChatRoomScreen({
    super.key,
    required this.profile,
    this.isTrial = false,
    this.isInstaTalk = false,
    this.instaTalkDuration = 30,
    this.existingChatRoomId,
    this.onSessionEnd,
    this.isInstaTalkSender = false,
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

  Timer? _instaTimer;
  int _remainingSeconds = 0;
  bool _instaTalkExpired = false;
  bool _showingPaymentPrompt = false;

  bool _hasRenewedSession = false;
  bool _isRenewing = false;

  @override
  void initState() {
    super.initState();
    _initializeChatRoom();
    _focusNode.addListener(_onFocusChange);
    _chatController.messages.listen((_) => _chatController.scrollToBottom());

    if (widget.isInstaTalk && widget.isInstaTalkSender) {
      final liveRate = widget.profile.earnings?.liveRate ?? 0;
      if (!_chatController.isFreeChat(liveRate)) {
        _remainingSeconds = widget.instaTalkDuration;
        _startInstaTimer();
      }
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

  void _startInstaTimer() {
    _instaTimer?.cancel();

    _instaTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _instaTimer?.cancel();
          if (!_showingPaymentPrompt && !_instaTalkExpired) {
            _instaTalkExpired = true;
            _showingPaymentPrompt = true;
            _showContinueChatPrompt();
          }
        }
      });
    });
  }

  void _showContinueChatPrompt() {
    if (_chatController.isFreeChat(widget.profile.earnings?.liveRate)) {
      return;
    }

    _showingPaymentPrompt = true;
    final baseRate = widget.profile.earnings?.liveRate ?? 150.0;
    final perMinuteRate = baseRate;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Session Ended',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your session with ${widget.profile.name} has ended.',
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
            Text(
              '(₹${baseRate.toStringAsFixed(2)} for 30 minutes)',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
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
            onPressed: () => _purchaseChat(minutes: 1),
            child: const Text('Continue (1 min)'),
          ),
        ],
      ),
    );
  }

  void _purchaseChat({int minutes = 1}) async {
    final baseRate = widget.profile.earnings?.chatRate ?? 150.0;
    final perMinuteRate = _chatController.calculatePerMinuteRate(baseRate);
    final finalAmount = perMinuteRate * minutes;

    setState(() => _isRenewing = true);

    try {
      final success = await _chatController.purchaseChatSession(
        widget.profile.sId.toString(),
        baseRate,
        minutes: minutes,
      );

      if (success) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        setState(() {
          _instaTalkExpired = false;
          _hasRenewedSession = true;
          _isRenewing = false;
          _remainingSeconds = minutes * 60;
          _showingPaymentPrompt = false;
        });

        _startInstaTimer();

        Get.snackbar(
          'Success',
          'Session renewed for $minutes minute${minutes > 1 ? 's' : ''}!',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
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
    _instaTimer?.cancel();
    _chatController.stopPolling();
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

  void _showRatingDialog() {
    Future.delayed(const Duration(milliseconds: 300), () {
      Get.dialog(
        Dialog(
          backgroundColor: AppColors.secondaryBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: RatingAndReviewWidget(
            userId: widget.profile.sId ?? "",
            interactionType: "chat",
          ),
        ),
        barrierDismissible: false,
      );
    });
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

                            Navigator.pop(context);
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
              if (!widget.isTrial)
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
                    if (widget.profile.isOnline == true)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            border: Border.all(
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
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
                      Text(
                        widget.profile.isOnline == true ? 'Online' : 'Offline',
                        style: GoogleFonts.manrope(
                          color: widget.profile.isOnline == true
                              ? Colors.green
                              : Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              if (!widget.isInstaTalk) ...[
                _buildActionButton(
                  icon: Icons.videocam,
                  onPressed: () {
                    Get.to(() => VideoCallLoadingScreen(
                          participant: widget.profile,
                          scheduleTime: DateTime.now(),
                          type: "video",
                        ));
                  },
                  label: 'Video Call',
                  color: AppColors.primaryColor,
                ),
                _buildActionButton(
                  icon: Icons.call,
                  onPressed: () {
                    Get.to(() => VoiceCallLoadingScreen(
                          participant: widget.profile,
                          scheduleTime: DateTime.now(),
                          type: "voice",
                        ));
                  },
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
                if (widget.isInstaTalk && widget.isInstaTalkSender) ...[
                  if (_chatController
                      .isFreeChat(widget.profile.earnings?.liveRate))
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 16),
                      color: Colors.green.withOpacity(0.2),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'This is a free chat session',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (!_instaTalkExpired)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 16),
                      color: Colors.amber.withOpacity(0.2),
                      child: Row(
                        children: [
                          const Icon(Icons.timer, color: Colors.amber),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Free trial: $_remainingSeconds seconds remaining',
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
                              value:
                                  _remainingSeconds / widget.instaTalkDuration,
                              backgroundColor: Colors.grey[800],
                              color: Colors.amber,
                              minHeight: 5,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                if (widget.isInstaTalk &&
                    widget.isInstaTalkSender &&
                    _instaTalkExpired)
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
                            'Your free trial has ended. Purchase a chat session to continue.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                          ),
                          onPressed: () => _showContinueChatPrompt(),
                          child: const Text('Continue'),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [],
                  ),
                ),
                Expanded(
                  child: Obx(() {
                    if (_chatController.isLoading.value) {
                      return const Center(child: CircularProgressIndicator());
                    } else {
                      return ListView.builder(
                        controller: _chatController.scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        itemCount: _chatController.messages.length,
                        itemBuilder: (context, index) => _buildMessageBubble(
                            _chatController.messages[index]),
                      );
                    }
                  }),
                ),
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
                            enabled: !(widget.isInstaTalk && _instaTalkExpired),
                            decoration: InputDecoration(
                              hintText: (widget.isInstaTalk &&
                                      _instaTalkExpired)
                                  ? 'Free trial ended. Purchase to continue.'
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
                            color: (widget.isInstaTalk && _instaTalkExpired)
                                ? Colors.grey
                                : AppColors.primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            iconSize: 20,
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.send, color: Colors.white),
                            onPressed: (widget.isInstaTalk && _instaTalkExpired)
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
}
