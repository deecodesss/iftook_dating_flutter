import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/features/home/data/enums/meeting_type.dart';
import 'package:iftook/features/profile/data/models/user.dart';
import 'package:iftook/helpers/app_colors.dart';
import 'package:intl/intl.dart';
import '../../controllers/home_controller.dart';
import 'package:iftook/features/wallet/presentation/screens/wallet_screen.dart';

class ScheduleMeetingScreen extends StatefulWidget {
  final User participant;
  final MeetingType type;
  final bool isInstant; // Add this parameter
  final bool isFreeTrialMode; // New parameter for free trial
  final int trialDurationSeconds; // Trial duration in seconds

  const ScheduleMeetingScreen({
    Key? key,
    required this.participant,
    required this.type,
    this.isInstant = false, // Default to false for scheduled meetings
    this.isFreeTrialMode = false,
    this.trialDurationSeconds = 30,
  }) : super(key: key);

  @override
  State<ScheduleMeetingScreen> createState() => _ScheduleMeetingScreenState();
}

class _ScheduleMeetingScreenState extends State<ScheduleMeetingScreen> {
  final HomeController _homeController = Get.find<HomeController>();
  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.now();
  Timer? _trialTimer;
  int _remainingSeconds = 0;
  bool _showingPaymentPrompt = false;

  double get meetingRate {
    final earnings = widget.participant.earnings;
    if (earnings == null) return 150.0; // Default rate

    switch (widget.type) {
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
    _homeController.fetchWalletBalance();

    // If this is an instant meeting, set the date/time to now
    if (widget.isInstant) {
      selectedDate = DateTime.now();
      selectedTime = TimeOfDay.now();
    }

    // If this is a free trial mode, start the timer
    if (widget.isFreeTrialMode) {
      _remainingSeconds = widget.trialDurationSeconds;
      _startTrialTimer();
    }
  }

  void _startTrialTimer() {
    _trialTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _trialTimer?.cancel();
          if (!_showingPaymentPrompt) {
            _showPaymentPrompt();
          }
        }
      });
    });
  }

  void _showPaymentPrompt() {
    _showingPaymentPrompt = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Free Trial Ended',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your 30-second free trial with ${widget.participant.name} has ended.',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Text(
              'Would you like to continue this ${widget.type.value} session?',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Text(
              'Rate: ₹${meetingRate.toStringAsFixed(0)} for 30 minutes',
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
              Get.back(); // Return to previous screen
            },
            child: const Text('End Session'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              // Continue the session with payment
              _scheduleMeeting();
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _trialTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isFreeTrialMode
            ? '${widget.type.value.toUpperCase()} - Free Trial'
            : (widget.isInstant
                ? 'Instant ${widget.type.value.toUpperCase()}'
                : 'Schedule ${widget.type.value.toUpperCase()}')),
      ),
      body: SingleChildScrollView(
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
                                ? NetworkImage(widget.participant.photos!.first)
                                : null,
                        child: widget.participant.photos?.isEmpty == true
                            ? Icon(Icons.person)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Rate Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Rate per 30 minutes',
                            style: TextStyle(color: Colors.white),
                          ),
                          Text(
                            '₹${meetingRate.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Wallet Balance
                  Obx(() => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                  color:
                                      _homeController.userWalletBalance.value >=
                                              meetingRate
                                          ? Colors.green
                                          : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )),

                  // Hide date/time pickers for instant meetings
                  if (!widget.isInstant) ...[
                    // Date Selection
                    ListTile(
                      title: const Text('Date'),
                      subtitle: Text(
                        "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: _selectDate,
                      ),
                    ),

                    // Time Selection
                    ListTile(
                      title: const Text('Time'),
                      subtitle: Text(selectedTime.format(context)),
                      trailing: IconButton(
                        icon: const Icon(Icons.access_time),
                        onPressed: _selectTime,
                      ),
                    ),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Card(
                        color: Colors.grey[850],
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Instant Session',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'This session will start immediately after confirmation.',
                                style: TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Icon(Icons.access_time,
                                      color: AppColors.primaryColor),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Duration: 30 minutes',
                                    style: TextStyle(color: Colors.grey[300]),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.payments_outlined,
                                      color: AppColors.primaryColor),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Rate: ₹${meetingRate.toStringAsFixed(0)}/30m',
                                    style: TextStyle(color: Colors.grey[300]),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Add free trial timer if in trial mode
                  if (widget.isFreeTrialMode) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orangeAccent.withOpacity(0.5),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'FREE TRIAL',
                            style: TextStyle(
                              color: Colors.orangeAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Time remaining: $_remainingSeconds seconds',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value:
                                _remainingSeconds / widget.trialDurationSeconds,
                            backgroundColor: Colors.grey[800],
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.orangeAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  if (_homeController.userWalletBalance.value < meetingRate)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () => Get.to(() => const WalletScreen()),
                        child: const Text('Top Up Wallet',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),

                  if (_homeController.userWalletBalance.value >= meetingRate)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _scheduleMeeting,
                        child: Text(
                          widget.isInstant ? 'Start Now' : 'Schedule Meeting',
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

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );
    if (picked != null) {
      setState(() => selectedTime = picked);
    }
  }

  void _scheduleMeeting() async {
    final DateTime scheduleTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    try {
      // Replace the dialog with a bottom loading indicator
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
                'Scheduling meeting...',
                style: TextStyle(color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      );

      final success = await _homeController.createMeeting(
        widget.participant.sId!,
        widget.type.toApiValue(),
        scheduleTime,
        meetingRate,
      );

      // Remove loading sheet
      Navigator.pop(context);

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
                  'Meeting Scheduled Successfully',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your meeting has been scheduled for ${DateFormat('MMM d, yyyy - h:mm a').format(scheduleTime)}',
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
                    child: const Text(
                      'Done',
                      style: TextStyle(color: Colors.white),
                    ),
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
                  'Failed to Schedule Meeting',
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
      Navigator.pop(context); // Remove loading indicator
      print('Error scheduling meeting: $e');
    }
  }
}
