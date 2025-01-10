import 'package:flutter/material.dart';
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

    await Future.delayed(Duration(seconds: 1));

    setState(() {
      _isSaving = false;
    });

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
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
              margin: EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Text(
                'My Charges',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(width: 12),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Color(0xFF2E7D32),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF2E7D32).withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'FREE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Text(
            'Hi Sarah!',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 24,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 32),
          _buildPriceField(
              'Chat (30 min)', _chatController, Icons.chat_bubble_outline),
          _buildPriceField(
              'Voice Call (30 min)', _voiceController, Icons.phone_outlined),
          _buildPriceField(
              'Video Call (30 min)', _videoController, Icons.videocam_outlined),
          _buildPriceField(
              'Live (per min)', _liveController, Icons.live_tv_outlined),
          _buildSubscriptionField(),
          SizedBox(height: 24),
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
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSubscriptionField() {
    return Container(
      margin: EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[800]!, width: 1),
            ),
            child: TextField(
              controller: _subscriptionController,
              keyboardType: TextInputType.number,
              style: TextStyle(
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
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ),
          Container(
            margin: EdgeInsets.only(top: 8),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                SizedBox(width: 8),
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

  Widget _buildPriceField(
      String label, TextEditingController controller, IconData icon) {
    return Container(
      margin: EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!, width: 1),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: TextStyle(
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
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
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
        child: PriceBottomSheet(),
      ),
    ),
  );

  if (result == true) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text(
              'Prices updated successfully!',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        backgroundColor: Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
