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
  int durationInMinutes = 30; // Default duration

  double get meetingRate {
    final earnings = widget.participant.earnings;
    if (earnings == null) return 150.0; // Default rate

    switch (_selectedType) {
      case MeetingType.video:
        return earnings.videoRate;
      case MeetingType.voice:
        return earnings.voiceRate;
      case MeetingType.chat:
        return earnings.chatRate;
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
                        // Participant Info
                        Card(
                          child: ListTile(
                            title: Text(widget.participant.name ?? 'User'),
                            subtitle: Text(widget.participant.profession ?? ''),
                            leading: CircleAvatar(
                              backgroundImage:
                                  widget.participant.photos?.isNotEmpty == true
                                      ? NetworkImage(
                                          widget.participant.photos!.first)
                                      : null,
                              child: widget.participant.photos?.isEmpty == true
                                  ? Icon(Icons.person)
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Trial Status
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isTrialUsed
                                ? Colors.amber.withOpacity(0.2)
                                : Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isTrialUsed ? Colors.amber : Colors.green,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isTrialUsed
                                    ? Icons.warning_amber_rounded
                                    : Icons.emoji_events,
                                color:
                                    isTrialUsed ? Colors.amber : Colors.green,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  isTrialUsed
                                      ? 'You have already used your free trial with this person'
                                      : 'You have a free trial available with this person!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Meeting Type Selection
                        Text(
                          'Select Meeting Type',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildTypeOption(MeetingType.chat,
                                Icons.chat_bubble_outline, 'Chat'),
                            _buildTypeOption(MeetingType.voice,
                                Icons.phone_outlined, 'Voice'),
                            _buildTypeOption(MeetingType.video,
                                Icons.videocam_outlined, 'Video'),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Duration Selection (only for non-trial)
                        if (isTrialUsed) ...[
                          Text(
                            'Select Duration',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildDurationOption(5, '5 min'),
                              _buildDurationOption(10, '10 min'),
                              _buildDurationOption(30, '30 min'),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Rate Card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isTrialUsed
                                      ? 'Rate for $durationInMinutes minutes'
                                      : 'Trial (free)',
                                  style: TextStyle(color: Colors.white),
                                ),
                                Text(
                                  isTrialUsed
                                      ? '₹${(meetingRate * durationInMinutes / 30).toStringAsFixed(0)}'
                                      : 'FREE',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isTrialUsed
                                        ? AppColors.primaryColor
                                        : Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Wallet Balance (only show if not free trial)
                        if (isTrialUsed)
                          Obx(() => Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Wallet Balance',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      Text(
                                        '₹${_homeController.userWalletBalance.value.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: _homeController
                                                      .userWalletBalance
                                                      .value >=
                                                  (meetingRate *
                                                      durationInMinutes /
                                                      30)
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )),

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
                              ),
                              onPressed: () =>
                                  Get.to(() => const WalletScreen()),
                              child: const Text('Top Up Wallet',
                                  style: TextStyle(color: Colors.white)),
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
                              ),
                              onPressed: () =>
                                  _scheduleInstatalk(), // This should be the only call to schedule
                              child: Text(
                                'Send Request',
                                style: const TextStyle(color: Colors.white),
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
            Icon(
              icon,
              color: isSelected ? AppColors.primaryColor : Colors.grey,
              size: 28,
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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

      bool success = false;

      if (isTrialUsed) {
        // Calculate the payment amount based on selected duration and rate
        final amount = meetingRate * durationInMinutes / 30;

        // Handle paid InstaTalk through controller
        final result = await _instaTalkController.createInstaTalk(
            widget.participant.sId!, _selectedType.toApiValue());

        success = result != null;
      } else {
        // Handle free trial InstaTalk
        // The createInstaTalk method returns a Map<String, dynamic>?, not a bool
        final result = await _instaTalkController.createInstaTalk(
          widget.participant.sId!,
          _selectedType.toApiValue(),
        );

        // Set success based on whether result is not null
        success = result != null;
      }

      // Remove loading sheet
      Navigator.pop(context);

      // There is no 'res' variable, use the 'success' boolean we set above
      if (success) {
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
                const Text(
                  'InstaTalk Request Sent',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You will be notified when ${widget.participant.name} accepts your request',
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
        // Show error bottom sheet
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
