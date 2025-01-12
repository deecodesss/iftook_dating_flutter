import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/helpers/app_colors.dart';

class PriceBottomSheet extends StatefulWidget {
  const PriceBottomSheet({Key? key}) : super(key: key);

  @override
  _PriceBottomSheetState createState() => _PriceBottomSheetState();
}

class _PriceBottomSheetState extends State<PriceBottomSheet> {
  final TextEditingController _chatController =
      TextEditingController(text: '150');
  final TextEditingController _voiceController =
      TextEditingController(text: '300');
  final TextEditingController _videoController =
      TextEditingController(text: '450');
  final TextEditingController _liveController =
      TextEditingController(text: '5');
  final TextEditingController _subscriptionController =
      TextEditingController(text: '700');

  // Add state for free checkboxes
  bool _isChatFree = false;
  bool _isVoiceFree = false;
  bool _isVideoFree = false;
  bool _isLiveFree = false;
  bool _isSubscriptionFree = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _chatController.dispose();
    _voiceController.dispose();
    _videoController.dispose();
    _liveController.dispose();
    _subscriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges(BuildContext context) async {
    setState(() {
      _isSaving = true;
    });

    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isSaving = false;
    });

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Earnings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.blueGrey.withOpacity(0.2),
                ),
                onPressed: () {
                  Get.back();
                },
                icon: const Icon(
                  Icons.close,
                ),
              )
              // SizedBox(width: 12),
              // Container(
              //   padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              //   decoration: BoxDecoration(
              //     color: Color(0xFF2E7D32),
              //     borderRadius: BorderRadius.circular(16),
              //     boxShadow: [
              //       BoxShadow(
              //         color: Color(0xFF2E7D32).withOpacity(0.3),
              //         blurRadius: 8,
              //         offset: Offset(0, 2),
              //       ),
              //     ],
              //   ),
              //   child: Text(
              //     'FREE',
              //     style: TextStyle(
              //       color: Colors.white,
              //       fontSize: 14,
              //       fontWeight: FontWeight.w600,
              //       letterSpacing: 0.5,
              //     ),
              //   ),
              // ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Hi Sarah!',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 24,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),
          _buildPriceFieldWithCheckbox(
            'Chat (30 min)',
            _chatController,
            Icons.chat_bubble_outline,
            _isChatFree,
            (value) => setState(() => _isChatFree = value ?? false),
          ),
          _buildPriceFieldWithCheckbox(
            'Voice Call (30 min)',
            _voiceController,
            Icons.phone_outlined,
            _isVoiceFree,
            (value) => setState(() => _isVoiceFree = value ?? false),
          ),
          _buildPriceFieldWithCheckbox(
            'Video Call (30 min)',
            _videoController,
            Icons.videocam_outlined,
            _isVideoFree,
            (value) => setState(() => _isVideoFree = value ?? false),
          ),
          _buildPriceFieldWithCheckbox(
            'Live (per min)',
            _liveController,
            Icons.live_tv_outlined,
            _isLiveFree,
            (value) => setState(() => _isLiveFree = value ?? false),
          ),
          _buildSubscriptionFieldWithCheckbox(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isSaving ? null : () => _saveChanges(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSubscriptionFieldWithCheckbox() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[800]!, width: 1),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _subscriptionController,
                  keyboardType: TextInputType.number,
                  enabled: !_isSubscriptionFree,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Monthly Subscription',
                    labelStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                    prefixIcon: Icon(
                      Icons.star_outline,
                      color: Colors.grey[400],
                      size: 24,
                    ),
                    prefixText: '₹ ',
                    prefixStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.transparent,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        'Make it free',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Switch(
                        value: _isSubscriptionFree,
                        onChanged: (value) {
                          setState(() {
                            _isSubscriptionFree = value;
                            if (value) {
                              _subscriptionController.text = '0';
                            } else {
                              _subscriptionController.text = '700';
                            }
                          });
                        },
                        activeColor: AppColors.primaryColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[800]!.withOpacity(0.3),
              border: Border.all(
                color: Colors.grey[700]!,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.grey[400],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Per month subscription you charge from your followers',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceFieldWithCheckbox(
    String label,
    TextEditingController controller,
    IconData icon,
    bool isFree,
    Function(bool?) onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!, width: 1),
      ),
      child: Column(
        children: [
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            enabled: !isFree,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
              prefixIcon: Icon(
                icon,
                color: Colors.grey[400],
                size: 24,
              ),
              prefixText: '₹ ',
              prefixStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.transparent,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            child: Row(
              children: [
                Text(
                  'Make it free',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: isFree,
                  onChanged: (value) {
                    onChanged(value);
                    if (value) {
                      controller.text = '0';
                    } else {
                      // Reset to default values
                      switch (label) {
                        case 'Chat (30 min)':
                          controller.text = '150';
                          break;
                        case 'Voice Call (30 min)':
                          controller.text = '300';
                          break;
                        case 'Video Call (30 min)':
                          controller.text = '450';
                          break;
                        case 'Live (per min)':
                          controller.text = '5';
                          break;
                      }
                    }
                  },
                  activeColor: AppColors.primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void showPriceBottomSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const PriceBottomSheet(),
      ),
    ),
  );

  if (result == true) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text(
              'Prices updated successfully!',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
