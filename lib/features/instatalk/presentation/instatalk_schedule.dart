import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/core/services/api_service.dart';
import 'package:iftook/core/services/shared_prefs.dart';
import 'package:iftook/features/home/controllers/home_controller.dart';
import 'package:iftook/features/home/data/enums/meeting_type.dart';
import 'package:iftook/features/profile/data/models/user.dart';
import 'package:iftook/helpers/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:iftook/features/friends/controllers/instaTalkController.dart';
import 'package:iftook/features/wallet/presentation/screens/wallet_screen.dart';

class ScheduleInstaTalkScreen extends StatefulWidget {
  final User participant;
  final MeetingType type;

  const ScheduleInstaTalkScreen({
    Key? key,
    required this.participant,
    required this.type,
  }) : super(key: key);

  @override
  State<ScheduleInstaTalkScreen> createState() =>
      _ScheduleInstaTalkScreenState();
}

class _ScheduleInstaTalkScreenState extends State<ScheduleInstaTalkScreen> {
  final HomeController _homeController = Get.find<HomeController>();
  final InstaTalkController _instaTalkController =
      Get.put(InstaTalkController());

  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.now();

  bool isLoading = true;
  bool isTrialUsed = false;
  MeetingType _selectedType = MeetingType.video;
  int durationInMinutes = 1; // Default duration

  double get meetingRate {
    final earnings = widget.participant.earnings;
    if (earnings == null) return 150.0; // Default rate

    switch (_selectedType) {
      case MeetingType.video:
        return earnings.live.toDouble();
      case MeetingType.voice:
        return earnings.live.toDouble();
      case MeetingType.chat:
        return earnings.live.toDouble();
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedType = widget.type;
    _homeController.fetchWalletBalance();
    _checkTrialStatus();
    // Remove any auto-scheduling that might be happening here
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _checkTrialStatus() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Properly await the user ID instead of calling toString() on a Future
      final userId = await SharedPrefs.getUserIdSharedPreference();

      if (userId == null) {
        setState(() {
          isTrialUsed = false;
          isLoading = false;
        });
        return;
      }

      print(
          'Checking trial status with userId: $userId and participantId: ${widget.participant.sId}');

      // Make the API call and properly parse the response
      final response =
          await ApiService.checkIfTrialUsed(widget.participant.sId!, userId);

      // Process response as http.Response
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('Trial check response: ${response.body}');

        // Update to match backend API that returns success: true/false
        // where success: true means a meeting already exists (trial used)
        final trialUsed = responseData['success'] == true;

        setState(() {
          isTrialUsed = trialUsed;
          isLoading = false;
        });
        print('Trial used status set to: $isTrialUsed');
      } else {
        print(
            'Error in trial check: ${response.statusCode} - ${response.body}');
        setState(() {
          isTrialUsed = false; // Default to not used on error
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error checking trial status: $e');
      setState(() {
        isTrialUsed = false; // Assume not used in case of error
        isLoading = false;
      });
    }

    // DO NOT schedule InstaTalk here - just update the UI state
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: Text("InstaTalk with ${widget.participant.name}"),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Combined User Profile & Pricing Card
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color.fromARGB(255, 21, 21, 21)!,
                                const Color.fromARGB(255, 29, 29, 29)!,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color.fromARGB(255, 38, 38, 38)!
                                  .withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Column(children: [
                            // User Profile Header
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: AppColors.primaryColor
                                            .withOpacity(0.3),
                                        width: 2,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 30,
                                      backgroundImage: widget.participant.photos
                                                  ?.isNotEmpty ==
                                              true
                                          ? NetworkImage(
                                              widget.participant.photos!.first)
                                          : null,
                                      child:
                                          widget.participant.photos?.isEmpty ==
                                                  true
                                              ? Icon(Icons.person,
                                                  size: 30,
                                                  color: Colors.grey[400])
                                              : null,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.participant.name ?? 'User',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        if (widget.participant.profession !=
                                            null)
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.work_outline,
                                                color: Colors.grey[400],
                                                size: 16,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                widget.participant.profession!,
                                                style: TextStyle(
                                                  color: Colors.grey[400],
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isTrialUsed
                                                ? Colors.amber.withOpacity(0.1)
                                                : Colors.green.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color: isTrialUsed
                                                  ? Colors.amber
                                                      .withOpacity(0.3)
                                                  : Colors.green
                                                      .withOpacity(0.3),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isTrialUsed
                                                    ? Icons
                                                        .warning_amber_rounded
                                                    : Icons.emoji_events,
                                                color: isTrialUsed
                                                    ? Colors.amber
                                                    : Colors.green,
                                                size: 14,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                isTrialUsed
                                                    ? 'TRIAL USED'
                                                    : 'FREE TRIAL',
                                                style: TextStyle(
                                                  color: isTrialUsed
                                                      ? Colors.amber
                                                      : Colors.green,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Divider
                            Container(
                              height: 1,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.grey[700]!.withOpacity(0.5),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),

                            // Rate and Wallet Section
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(children: [
                                // Rate Section
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.blue[400]!.withOpacity(0.2),
                                            Colors.blue[600]!.withOpacity(0.1),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        Icons.monetization_on_outlined,
                                        color: Colors.blue[300],
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isTrialUsed
                                                ? 'Rate for $durationInMinutes minutes'
                                                : 'Trial Session',
                                            style: TextStyle(
                                              color: Colors.grey[400],
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.baseline,
                                            textBaseline:
                                                TextBaseline.alphabetic,
                                            children: [
                                              Text(
                                                isTrialUsed
                                                    ? '₹${(meetingRate).toStringAsFixed(0)}'
                                                    : 'FREE',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              if (isTrialUsed) ...[
                                                const SizedBox(width: 4),
                                                Text(
                                                  '/min',
                                                  style: TextStyle(
                                                    color: Colors.grey[500],
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                // Wallet Section (only if trial used)
                                if (isTrialUsed) ...[
                                  const SizedBox(height: 16),
                                  Obx(
                                    () {
                                      final hasBalance = _homeController
                                              .userWalletBalance.value >=
                                          (meetingRate *
                                              durationInMinutes /
                                              30);
                                      return Row(children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: hasBalance
                                                  ? [
                                                      Colors.green[400]!
                                                          .withOpacity(0.2),
                                                      Colors.green[600]!
                                                          .withOpacity(0.1),
                                                    ]
                                                  : [
                                                      Colors.orange[400]!
                                                          .withOpacity(0.2),
                                                      Colors.orange[600]!
                                                          .withOpacity(0.1),
                                                    ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          child: Icon(
                                            hasBalance
                                                ? Icons.account_balance_wallet
                                                : Icons
                                                    .account_balance_wallet_outlined,
                                            color: hasBalance
                                                ? Colors.green[300]
                                                : Colors.orange[300],
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Wallet Balance',
                                                  style: TextStyle(
                                                    color: Colors.grey[400],
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                    letterSpacing: 0.3,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    Text(
                                                      '₹${_homeController.userWalletBalance.value.toStringAsFixed(0)}',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 20,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: hasBalance
                                                            ? Colors.green[400]!
                                                                .withOpacity(
                                                                    0.2)
                                                            : Colors
                                                                .orange[400]!
                                                                .withOpacity(
                                                                    0.2),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                      ),
                                                      child: Text(
                                                        hasBalance
                                                            ? 'READY'
                                                            : 'LOW',
                                                        style: TextStyle(
                                                          color: hasBalance
                                                              ? Colors
                                                                  .green[400]
                                                              : Colors
                                                                  .orange[400],
                                                          fontSize: 9,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          letterSpacing: 0.5,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ]),
                                        ),
                                      ]);
                                    },
                                  ),
                                ],
                              ]),
                            ),

                            const SizedBox(height: 24),

                            // Meeting Type Selection Card
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.grey[800]!.withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Select Meeting Type',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildTypeOption(MeetingType.chat,
                                          Icons.chat_bubble_outline, 'Chat'),
                                      _buildTypeOption(MeetingType.voice,
                                          Icons.phone_outlined, 'Voice'),
                                      _buildTypeOption(MeetingType.video,
                                          Icons.videocam_outlined, 'Video'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ]),

                          // const SizedBox(height: 24),

                          // Action Buttons
                        ),
                        const SizedBox(height: 24),
                        if (isTrialUsed &&
                            _homeController.userWalletBalance.value <
                                (meetingRate * durationInMinutes / 30))
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () =>
                                  Get.to(() => const WalletScreen()),
                              child: const Text('Top Up Wallet',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),

                        if (!isTrialUsed ||
                            _homeController.userWalletBalance.value >=
                                (meetingRate * durationInMinutes / 30))
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryColor,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () => _scheduleInstatalk(),
                              child: Text(
                                'Send Request',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTypeOption(MeetingType type, IconData icon, String label) {
    final isSelected = _selectedType == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
        });
      },
      child: Container(
        width: 90,
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    AppColors.primaryColor.withOpacity(0.2),
                    AppColors.primaryColor.withOpacity(0.1),
                  ],
                )
              : LinearGradient(
                  colors: [
                    Colors.grey[800]!.withOpacity(0.3),
                    Colors.grey[800]!.withOpacity(0.1),
                  ],
                ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryColor.withOpacity(0.5)
                : Colors.grey[700]!.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryColor.withOpacity(0.2)
                    : Colors.grey[700]!.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.primaryColor : Colors.grey[400],
                size: 24,
              ),
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[400],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationOption(int minutes, String label) {
    final isSelected = durationInMinutes == minutes;

    return GestureDetector(
      onTap: () {
        setState(() {
          durationInMinutes = minutes;
        });
      },
      child: Container(
        width: 90,
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryColor.withOpacity(0.2)
              : Colors.grey.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primaryColor : Colors.grey,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scheduleInstatalk() async {
    try {
      // Show loading indicator
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isDismissible: false,
        builder: (context) => Container(
          height: 140,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Sending InstaTalk Request....',
                style: TextStyle(color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      );

      // Create InstaTalk request
      final result = await _instaTalkController.createInstaTalk(
        widget.participant.sId!,
        _selectedType.toApiValue(),
      );

      // Remove loading sheet
      Navigator.pop(context);

      // Check if result is not null
      if (result != null) {
        // Show success bottom sheet
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_outline,
                      color: Colors.green, size: 40),
                ),
                const SizedBox(height: 16),
                Text(
                  isTrialUsed ? 'InstaTalk Renewed' : 'InstaTalk Request Sent',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isTrialUsed
                      ? 'Your InstaTalk session has been renewed'
                      : 'You will be notified when ${widget.participant.name} accepts your request',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[400]),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () {
                      Navigator.pop(context); // Close bottom sheet
                      Get.back(); // Go back to previous screen
                    },
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        // Show error bottom sheet only if result is null
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_outline,
                      color: Colors.red, size: 40),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Failed to Send Request',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please try again later',
                  style: TextStyle(color: Colors.grey[400]),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      // Handle errors
      Navigator.pop(context); // Remove loading indicator
      print('Error scheduling InstaTalk: $e');

      // Show error snackbar
      Get.snackbar(
        'Error',
        'Failed to send InstaTalk request. Please try again.',
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }
}
