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
  DateTime _displayedMonth = DateTime.now();

  // Add scroll controllers for time pickers
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

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
      _hourController =
          FixedExtentScrollController(initialItem: selectedTime.hour);
      _minuteController =
          FixedExtentScrollController(initialItem: selectedTime.minute);
    } else {
      // Always start with 6 minutes from now as default
      final now = DateTime.now();
      final defaultTime = now.add(const Duration(minutes: 6));
      selectedDate =
          DateTime(defaultTime.year, defaultTime.month, defaultTime.day);
      selectedTime =
          TimeOfDay(hour: defaultTime.hour, minute: defaultTime.minute);

      // Initialize scroll controllers with the calculated time
      _hourController =
          FixedExtentScrollController(initialItem: selectedTime.hour);
      _minuteController =
          FixedExtentScrollController(initialItem: selectedTime.minute);
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
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  // Add method to get formatted date time display
  String get formattedDateTime {
    final dateFormat = DateFormat('EEEE, d MMMM yyyy');
    final timeFormat = DateFormat('h:mm a');
    final selectedDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
    return '${dateFormat.format(selectedDate)} at ${timeFormat.format(selectedDateTime)}';
  }

  // Add method to check if selected time is valid
  bool get isTimeValid {
    final now = DateTime.now();
    final selectedDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    // If it's today, check if time is at least 5 minutes from now
    if (selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day) {
      return selectedDateTime.isAfter(now.add(const Duration(minutes: 5)));
    }

    return true; // For future dates, any time is valid
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
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
                    child: Column(
                      children: [
                        // User Profile Header
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color:
                                        AppColors.primaryColor.withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 30,
                                  backgroundImage:
                                      widget.participant.photos?.isNotEmpty ==
                                              true
                                          ? NetworkImage(
                                              widget.participant.photos!.first)
                                          : null,
                                  child:
                                      widget.participant.photos?.isEmpty == true
                                          ? Icon(Icons.person,
                                              size: 30, color: Colors.grey[400])
                                          : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                    if (widget.participant.location?.city !=
                                        null)
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.location_on_outlined,
                                            color: Colors.grey[400],
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            widget.participant.location!.city!,
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
                                        color: AppColors.primaryColor
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: AppColors.primaryColor
                                              .withOpacity(0.3),
                                        ),
                                      ),
                                      child: Text(
                                        widget.type.value.toUpperCase(),
                                        style: TextStyle(
                                          color: AppColors.primaryColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
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
                          margin: const EdgeInsets.symmetric(horizontal: 20),
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
                          child: Column(
                            children: [
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
                                          'Session Rate',
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
                                          textBaseline: TextBaseline.alphabetic,
                                          children: [
                                            Text(
                                              '₹${meetingRate.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 20,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '/30min',
                                              style: TextStyle(
                                                color: Colors.grey[500],
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Wallet Section
                              Obx(() {
                                final hasBalance =
                                    _homeController.userWalletBalance.value >=
                                        meetingRate;
                                return Row(
                                  children: [
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
                                        borderRadius: BorderRadius.circular(14),
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
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: hasBalance
                                                      ? Colors.green[400]!
                                                          .withOpacity(0.2)
                                                      : Colors.orange[400]!
                                                          .withOpacity(0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  hasBalance ? 'READY' : 'LOW',
                                                  style: TextStyle(
                                                    color: hasBalance
                                                        ? Colors.green[400]
                                                        : Colors.orange[400],
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Replace old date/time pickers with embedded version
                  if (!widget.isInstant) ...[
                    _buildEmbeddedDateTimePicker(),
                  ] else ...[
                    // Instant Session card
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

                  // Free trial timer
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

                  // Update button condition to check time validity
                  if (_homeController.userWalletBalance.value >= meetingRate &&
                      (widget.isInstant || isTimeValid))
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

                  // Show message if time is invalid
                  if (_homeController.userWalletBalance.value >= meetingRate &&
                      !widget.isInstant &&
                      !isTimeValid)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Text(
                        'Please select a valid time to schedule the meeting',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
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

  Widget _buildEmbeddedDateTimePicker() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Date & Time',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),

            // Selected Date & Time Display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event,
                    color: AppColors.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formattedDateTime,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isTimeValid)
                    Icon(
                      Icons.warning,
                      color: Colors.orange,
                      size: 20,
                    ),
                ],
              ),
            ),

            if (!isTimeValid)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Please select a time at least 5 minutes from now',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // Calendar Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _displayedMonth = DateTime(
                        _displayedMonth.year,
                        _displayedMonth.month - 1,
                      );
                    });
                  },
                  icon: const Icon(Icons.chevron_left,
                      color: AppColors.primaryColor),
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_displayedMonth),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _displayedMonth = DateTime(
                        _displayedMonth.year,
                        _displayedMonth.month + 1,
                      );
                    });
                  },
                  icon: const Icon(Icons.chevron_right,
                      color: AppColors.primaryColor),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Days of week header
            Row(
              children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                  .map((day) => Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),

            const SizedBox(height: 8),

            // Calendar Grid
            _buildCalendarGrid(),

            const SizedBox(height: 24),

            // Time Picker Section
            const Text(
              'Select Time',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 16),

            _buildTimePicker(),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth =
        DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final lastDayOfMonth =
        DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday % 7;
    final daysInMonth = lastDayOfMonth.day;

    final today = DateTime.now();
    final isCurrentMonth = _displayedMonth.year == today.year &&
        _displayedMonth.month == today.month;

    return SizedBox(
      height: 240,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: 1,
        ),
        itemCount: 42, // 6 weeks * 7 days
        itemBuilder: (context, index) {
          final dayIndex = index - firstWeekday + 1;

          if (dayIndex < 1 || dayIndex > daysInMonth) {
            return const SizedBox(); // Empty cells
          }

          final date =
              DateTime(_displayedMonth.year, _displayedMonth.month, dayIndex);
          final isSelected = date.year == selectedDate.year &&
              date.month == selectedDate.month &&
              date.day == selectedDate.day;
          final isToday = isCurrentMonth && dayIndex == today.day;
          final isPast =
              date.isBefore(DateTime.now().subtract(const Duration(days: 1)));

          return GestureDetector(
            onTap: isPast
                ? null
                : () {
                    setState(() {
                      selectedDate = date;
                    });
                  },
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryColor
                    : isToday
                        ? AppColors.primaryColor.withOpacity(0.2)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isToday && !isSelected
                    ? Border.all(color: AppColors.primaryColor, width: 1)
                    : null,
              ),
              child: Center(
                child: Text(
                  dayIndex.toString(),
                  style: TextStyle(
                    color: isPast
                        ? Colors.grey[600]
                        : isSelected
                            ? Colors.white
                            : Colors.white,
                    fontWeight: isSelected || isToday
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimePicker() {
    final now = DateTime.now();
    final isToday = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;

    // Calculate minimum hour and minute for today
    final minHour = isToday ? now.hour : 0;
    final minMinute =
        isToday && selectedTime.hour == now.hour ? (now.minute + 5) : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Hour picker
          Expanded(
            child: Column(
              children: [
                Text(
                  'Hour',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 120,
                  child: ListWheelScrollView(
                    controller: _hourController,
                    itemExtent: 40,
                    perspective: 0.005,
                    diameterRatio: 1.2,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (index) {
                      // Validate hour selection for today
                      if (isToday && index < minHour) {
                        return;
                      }

                      setState(() {
                        selectedTime = TimeOfDay(
                          hour: index,
                          minute: selectedTime.minute,
                        );

                        // If selecting current hour on today, ensure minute is valid
                        if (isToday &&
                            index == now.hour &&
                            selectedTime.minute <= now.minute + 5) {
                          selectedTime = TimeOfDay(
                            hour: index,
                            minute: now.minute + 5,
                          );
                          _minuteController.animateToItem(
                            now.minute + 5,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      });
                    },
                    children: List.generate(24, (hour) {
                      final isSelected = hour == selectedTime.hour;
                      final isDisabled = isToday && hour < minHour;

                      return Center(
                        child: Text(
                          hour.toString().padLeft(2, '0'),
                          style: TextStyle(
                            fontSize: isSelected ? 18 : 14,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isDisabled
                                ? Colors.grey[600]
                                : isSelected
                                    ? AppColors.primaryColor
                                    : Colors.white70,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),

          Text(
            ':',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[400],
            ),
          ),

          // Minute picker (continuous)
          Expanded(
            child: Column(
              children: [
                Text(
                  'Minute',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 120,
                  child: ListWheelScrollView(
                    controller: _minuteController,
                    itemExtent: 40,
                    perspective: 0.005,
                    diameterRatio: 1.2,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (index) {
                      // Validate minute selection for today's current hour
                      if (isToday &&
                          selectedTime.hour == now.hour &&
                          index <= now.minute + 5) {
                        return;
                      }

                      setState(() {
                        selectedTime = TimeOfDay(
                          hour: selectedTime.hour,
                          minute: index,
                        );
                      });
                    },
                    children: List.generate(60, (minute) {
                      final isSelected = minute == selectedTime.minute;
                      final isDisabled = isToday &&
                          selectedTime.hour == now.hour &&
                          minute <= now.minute + 5;

                      return Center(
                        child: Text(
                          minute.toString().padLeft(2, '0'),
                          style: TextStyle(
                            fontSize: isSelected ? 18 : 14,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isDisabled
                                ? Colors.grey[600]
                                : isSelected
                                    ? AppColors.primaryColor
                                    : Colors.white70,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _scheduleMeeting() async {
    final DateTime scheduleTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    // Show modern scheduling flow modal
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      isScrollControlled: true,
      builder: (context) => _MeetingSchedulingFlowModal(
        participant: widget.participant,
        meetingType: widget.type,
        scheduleTime: scheduleTime,
        meetingRate: meetingRate,
        isInstant: widget.isInstant,
        onSchedule: () async {
          return await _homeController.createMeeting(
            widget.participant.sId!,
            widget.type.toApiValue(),
            scheduleTime,
            meetingRate,
          );
        },
        onComplete: () {
          Get.back(); // Go back to previous screen
        },
      ),
    );
  }
}

class _MeetingSchedulingFlowModal extends StatefulWidget {
  final User participant;
  final MeetingType meetingType;
  final DateTime scheduleTime;
  final double meetingRate;
  final bool isInstant;
  final Future<bool> Function() onSchedule;
  final VoidCallback onComplete;

  const _MeetingSchedulingFlowModal({
    required this.participant,
    required this.meetingType,
    required this.scheduleTime,
    required this.meetingRate,
    required this.isInstant,
    required this.onSchedule,
    required this.onComplete,
  });

  @override
  State<_MeetingSchedulingFlowModal> createState() =>
      _MeetingSchedulingFlowModalState();
}

enum MeetingSchedulingState { loading, success, error }

class _MeetingSchedulingFlowModalState
    extends State<_MeetingSchedulingFlowModal> with TickerProviderStateMixin {
  MeetingSchedulingState _currentState = MeetingSchedulingState.loading;
  late AnimationController _scaleController;
  late AnimationController _slideController;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutCubic,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));

    // Start animations
    _scaleController.forward();
    _slideController.forward();

    // Start the scheduling process
    _performScheduling();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _performScheduling() async {
    try {
      // Wait for at least 1.5 seconds to show loading state
      final results = await Future.wait([
        widget.onSchedule(),
        Future.delayed(const Duration(milliseconds: 1500)),
      ]);

      final success = results[0] as bool;

      // Check if widget is still mounted
      if (mounted) {
        setState(() {
          _currentState = success
              ? MeetingSchedulingState.success
              : MeetingSchedulingState.error;
        });

        // Reset and replay animations for state transition
        _scaleController.reset();
        _slideController.reset();

        _scaleController.duration = const Duration(milliseconds: 200);
        _slideController.duration = const Duration(milliseconds: 200);

        _scaleController.forward();
        _slideController.forward();
      }
    } catch (e) {
      print('Error scheduling meeting: $e');
      if (mounted) {
        setState(() {
          _currentState = MeetingSchedulingState.error;
        });

        // Reset and replay animations for error state
        _scaleController.reset();
        _slideController.reset();

        _scaleController.duration = const Duration(milliseconds: 200);
        _slideController.duration = const Duration(milliseconds: 200);

        _scaleController.forward();
        _slideController.forward();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
      ),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.grey[900]!,
                Colors.grey[850]!,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.grey[800]!.withOpacity(0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SlideTransition(
            position: _slideAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: _buildContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_currentState) {
      case MeetingSchedulingState.loading:
        return _buildLoadingState();
      case MeetingSchedulingState.success:
        return _buildSuccessState();
      case MeetingSchedulingState.error:
        return _buildErrorState();
    }
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated loading indicator
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primaryColor,
                    ),
                  ),
                ),
                Icon(
                  widget.isInstant
                      ? Icons.flash_on_outlined
                      : Icons.schedule_outlined,
                  color: AppColors.primaryColor,
                  size: 24,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Text(
            widget.isInstant ? 'Starting Session' : 'Scheduling Meeting',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            widget.isInstant
                ? 'Preparing your instant session...'
                : 'Setting up your meeting...',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 24),

          // Progress indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildProgressDot(true),
              _buildProgressLine(true),
              _buildProgressDot(false),
              _buildProgressLine(false),
              _buildProgressDot(false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Success icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 48,
            ),
          ),

          const SizedBox(height: 24),

          Text(
            widget.isInstant ? 'Session Started!' : 'Meeting Scheduled!',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            widget.isInstant
                ? 'Your instant ${widget.meetingType.value} session with ${widget.participant.name} has started successfully.'
                : 'Your ${widget.meetingType.value} meeting with ${widget.participant.name} has been scheduled successfully.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 32),

          // Meeting details card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[800]!.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.green.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      widget.meetingType == MeetingType.video
                          ? Icons.videocam_outlined
                          : widget.meetingType == MeetingType.voice
                              ? Icons.phone_outlined
                              : Icons.chat_bubble_outline,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.meetingType.value.toUpperCase()} Session',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (!widget.isInstant) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_outlined,
                        color: Colors.grey[400],
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('MMM d, yyyy - h:mm a')
                            .format(widget.scheduleTime),
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.payments_outlined,
                      color: Colors.grey[400],
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '₹${widget.meetingRate.toStringAsFixed(0)} for 30 minutes',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.pop(context);
                widget.onComplete();
              },
              child: const Text(
                'Done',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Error icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
          ),

          const SizedBox(height: 24),

          Text(
            widget.isInstant ? 'Session Failed' : 'Scheduling Failed',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            widget.isInstant
                ? 'We couldn\'t start your session. Please check your connection and try again.'
                : 'We couldn\'t schedule your meeting. Please check your connection and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 32),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Colors.grey[600]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    // Retry by calling the original function again
                    Future.delayed(const Duration(milliseconds: 300), () {
                      (context as Element)
                          .findAncestorStateOfType<
                              _ScheduleMeetingScreenState>()
                          ?._scheduleMeeting();
                    });
                  },
                  child: const Text(
                    'Retry',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressDot(bool isActive) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? AppColors.primaryColor : Colors.grey[700],
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildProgressLine(bool isActive) {
    return Container(
      width: 20,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primaryColor : Colors.grey[700],
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}
