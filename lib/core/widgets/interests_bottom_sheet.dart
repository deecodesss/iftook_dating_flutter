import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iftook/helpers/app_colors.dart';

class InterestsBottomSheet extends StatefulWidget {
  final List<String> selectedInterests;

  const InterestsBottomSheet({
    Key? key,
    required this.selectedInterests,
  }) : super(key: key);

  @override
  _InterestsBottomSheetState createState() => _InterestsBottomSheetState();
}

class _InterestsBottomSheetState extends State<InterestsBottomSheet> {
  late List<String> _selectedInterests;
  bool _isSaving = false;

  final List<String> _interestAreas = [
    'Dating',
    'Open Relationship',
    'Friendship',
    'Long-term Relationship',
    'Short-term Relationship',
    'Travel Partner',
    'Coffee Date',
    'Date Night',
    'Flirting',
    'Decent Talk Only'
  ];

  @override
  void initState() {
    super.initState();
    _selectedInterests = List.from(widget.selectedInterests);
  }

  Future<void> _saveChanges(BuildContext context) async {
    setState(() {
      _isSaving = true;
    });

    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isSaving = false;
    });

    Navigator.pop(context, _selectedInterests);
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
                'My Interests',
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
                icon: Icon(
                  Icons.close,
                ),
              )
              // const SizedBox(width: 12),
              // Container(
              //   padding:
              //       const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              //   decoration: BoxDecoration(
              //     color: const Color(0xFF2E7D32),
              //     borderRadius: BorderRadius.circular(16),
              //     boxShadow: [
              //       BoxShadow(
              //         color: const Color(0xFF2E7D32).withOpacity(0.3),
              //         blurRadius: 8,
              //         offset: const Offset(0, 2),
              //       ),
              //     ],
              //   ),
              //   child: Text(
              //     '${_selectedInterests.length}/${_interestAreas.length}',
              //     style: const TextStyle(
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
            'Select what you\'re looking for',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[800]!, width: 1),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 12,
              children: _interestAreas.map((interest) {
                final isSelected = _selectedInterests.contains(interest);
                return FilterChip(
                  label: Text(interest),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedInterests.add(interest);
                      } else {
                        _selectedInterests.remove(interest);
                      }
                    });
                  },
                  selectedColor: AppColors.primaryColor,
                  checkmarkColor: Colors.white,
                  backgroundColor: const Color(0xFF3A3A3A),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[300],
                    fontSize: 14,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            margin: const EdgeInsets.only(bottom: 8),
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
                    'Select multiple interests to better match with others',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
}

void showInterestsBottomSheet(BuildContext context) async {
  List<String> currentInterests = [
    'Dating',
    'Open Relationship',
    'Friendship',
    'Long-term Relationship',
    'Short-term Relationship',
    'Travel Partner',
    'Coffee Date',
    'Date Night',
    'Flirting',
    'Decent Talk Only'
  ];
  final result = await showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: InterestsBottomSheet(
          selectedInterests: currentInterests,
        ),
      ),
    ),
  );

  if (result != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text(
              'Interests updated successfully!',
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
