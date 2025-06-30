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
    // Show modern scheduling flow modal
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      isScrollControlled: true,
      builder: (context) => _SchedulingFlowModal(
        participant: widget.participant,
        selectedType: _selectedType,
        isTrialUsed: isTrialUsed,
        meetingRate: meetingRate,
        durationInMinutes: durationInMinutes,
        onSchedule: () async {
          return await _instaTalkController.createInstaTalk(
            widget.participant.sId!,
            _selectedType.toApiValue(),
          );
        },
        onComplete: () {
          Get.back(); // Go back to previous screen
        },
      ),
    );
  }
}

class _SchedulingFlowModal extends StatefulWidget {
  final User participant;
  final MeetingType selectedType;
  final bool isTrialUsed;
  final double meetingRate;
  final int durationInMinutes;
  final Future<dynamic> Function() onSchedule;
  final VoidCallback onComplete;

  const _SchedulingFlowModal({
    required this.participant,
    required this.selectedType,
    required this.isTrialUsed,
    required this.meetingRate,
    required this.durationInMinutes,
    required this.onSchedule,
    required this.onComplete,
  });

  @override
  State<_SchedulingFlowModal> createState() => _SchedulingFlowModalState();
}

enum SchedulingState { loading, success, error }

class _SchedulingFlowModalState extends State<_SchedulingFlowModal>
    with TickerProviderStateMixin {
  SchedulingState _currentState = SchedulingState.loading;
  late AnimationController _scaleController;
  late AnimationController _slideController;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400), // Reduced from 800ms
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300), // Reduced from 600ms
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8, // Changed from 0.0 to 0.8 for less dramatic scaling
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves
          .easeOutCubic, // Changed from Curves.elasticOut for gentler animation
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1), // Reduced from 0.3 to 0.1 for subtle slide
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves
          .easeOut, // Changed from Curves.easeOutQuart for smoother animation
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
      // Wait for at least 1.5 seconds to show loading state (reduced from 2 seconds)
      await Future.wait([
        widget.onSchedule(),
        Future.delayed(const Duration(milliseconds: 1500)),
      ]);

      // Check if widget is still mounted
      if (mounted) {
        setState(() {
          _currentState = SchedulingState.success;
        });

        // Reset and replay animations for success state with reduced intensity
        _scaleController.reset();
        _slideController.reset();

        // Use faster, subtler animations for state transitions
        _scaleController.duration = const Duration(milliseconds: 200);
        _slideController.duration = const Duration(milliseconds: 200);

        _scaleController.forward();
        _slideController.forward();
      }
    } catch (e) {
      print('Error scheduling InstaTalk: $e');
      if (mounted) {
        setState(() {
          _currentState = SchedulingState.error;
        });

        // Reset and replay animations for error state with reduced intensity
        _scaleController.reset();
        _slideController.reset();

        // Use faster, subtler animations for state transitions
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
      case SchedulingState.loading:
        return _buildLoadingState();
      case SchedulingState.success:
        return _buildSuccessState();
      case SchedulingState.error:
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
                  Icons.send_outlined,
                  color: AppColors.primaryColor,
                  size: 24,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Sending Request',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Preparing your InstaTalk request...',
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
          // Success icon with animation
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
            widget.isTrialUsed ? 'InstaTalk Renewed!' : 'Request Sent!',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            widget.isTrialUsed
                ? 'Your InstaTalk session with ${widget.participant.name} has been renewed successfully.'
                : 'Your InstaTalk request has been sent to ${widget.participant.name}. You\'ll be notified when they respond.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 32),

          // Session details card
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
                      widget.selectedType == MeetingType.video
                          ? Icons.videocam_outlined
                          : widget.selectedType == MeetingType.voice
                              ? Icons.phone_outlined
                              : Icons.chat_bubble_outline,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.selectedType.value.toUpperCase()} Session',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (widget.isTrialUsed) ...[
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
                        '₹${widget.meetingRate.toStringAsFixed(0)} for ${widget.durationInMinutes} minute${widget.durationInMinutes > 1 ? 's' : ''}',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
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

          const Text(
            'Request Failed',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'We couldn\'t send your InstaTalk request. Please check your connection and try again.',
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
                              _ScheduleInstaTalkScreenState>()
                          ?._scheduleInstatalk();
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
