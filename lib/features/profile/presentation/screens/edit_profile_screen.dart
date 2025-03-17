import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:iftook/helpers/app_colors.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';

import '../../../../core/services/api_service.dart';
import 'package:iftook/features/profile/data/models/user.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _aboutController = TextEditingController();
  final TextEditingController _professionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _panController = TextEditingController();

  // Bank details controllers
  final TextEditingController _accountHolderNameController =
      TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _accountNumberController =
      TextEditingController();
  final TextEditingController _ifscCodeController = TextEditingController();
  final TextEditingController _swiftCodeController = TextEditingController();
  final TextEditingController _ibanController = TextEditingController();
  final TextEditingController _routingNumberController =
      TextEditingController();

  String? selectedHeight;
  List<String> selectedLanguages = [];
  String? profileImagePath;
  String? panImagePath;
  String selectedCountry = 'India'; // Default country

  bool isLoading = true;
  User? currentUser;

  // Country list
  final List<String> countries = [
    'India',
    'United States',
    'United Kingdom',
    'Canada',
    'Australia',
    'Germany',
    'France',
    'Japan',
    'China',
    'Other',
  ];

  final List<String> heights = List.generate(
    81, // 4'10" to 7'0"
    (index) => "${(4 + (index ~/ 12))}' ${(index % 12)}\"",
  );

  final List<String> languages = [
    'English',
    'Hindi',
    'Marathi',
    'Punjabi',
    'Gujarati',
    'Tamil',
    'Telugu',
    'Bengali',
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  Future<void> _loadCurrentProfile() async {
    try {
      setState(() => isLoading = true);
      final response = await ApiService.fetchMyProfile();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        currentUser = User.fromJson(data['user']);

        // Set initial values
        // _phoneController.text = currentUser?.phone ?? '';
        _aboutController.text = currentUser?.about ?? '';
        _professionController.text = currentUser?.profession ?? '';
        _locationController.text = currentUser?.location?.city ?? '';
        selectedHeight = currentUser?.height;
        selectedLanguages = currentUser?.languages?.toList() ?? [];
        _panController.text = currentUser?.panDetails?.panNumber ?? '';

        // Set country
        selectedCountry = currentUser?.location?.country ?? 'India';

        // Load bank details if available
        if (currentUser?.bankDetails != null) {
          _accountHolderNameController.text =
              currentUser?.bankDetails?.accountHolderName ?? '';
          _bankNameController.text = currentUser?.bankDetails?.bankName ?? '';
          _accountNumberController.text =
              currentUser?.bankDetails?.accountNumber ?? '';
          _ifscCodeController.text = currentUser?.bankDetails?.ifscCode ?? '';
          _swiftCodeController.text = currentUser?.bankDetails?.swiftCode ?? '';
          _ibanController.text = currentUser?.bankDetails?.iban ?? '';
          _routingNumberController.text =
              currentUser?.bankDetails?.routingNumber ?? '';
        }

        // Update state
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('Error loading profile: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _pickImage(bool isProfile) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        if (isProfile) {
          profileImagePath = image.path;
        } else {
          panImagePath = image.path;
        }
      });
    }
  }

  Future<void> _saveProfile() async {
    try {
      // Show loading indicator
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      // Prepare the data
      Map<String, dynamic> updateData = {
        'phone': _phoneController.text,
        'about': _aboutController.text,
        'profession': _professionController.text,
        'height': selectedHeight,
        'languages': selectedLanguages,
        'location': {
          'country': selectedCountry,
          'state': 'State',
          'city': _locationController.text,
        },
        'panDetails': {
          'panNumber': _panController.text,
        },
        'bankDetails': {
          'accountType':
              selectedCountry == 'India' ? 'indian' : 'international',
          'accountHolderName': _accountHolderNameController.text,
          'bankName': _bankNameController.text,
          'accountNumber': _accountNumberController.text,
        }
      };

      // Add country-specific bank details
      if (selectedCountry == 'India') {
        updateData['bankDetails']['ifscCode'] = _ifscCodeController.text;
      } else {
        updateData['bankDetails']['swiftCode'] = _swiftCodeController.text;
        updateData['bankDetails']['iban'] = _ibanController.text;
        updateData['bankDetails']['routingNumber'] =
            _routingNumberController.text;
      }

      // Add profile image if selected
      if (profileImagePath != null) {
        final bytes = await File(profileImagePath!).readAsBytes();
        final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        updateData['image'] = base64Image;
      }

      // Add PAN/Government ID image if selected
      if (panImagePath != null) {
        final bytes = await File(panImagePath!).readAsBytes();
        final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        updateData['panDetails']['panImage'] = base64Image;
      }

      final response = await ApiService.updateProfile(updateData);

      // Remove loading dialog
      Get.back();

      if (response.statusCode == 200) {
        Get.snackbar(
          'Success',
          'Profile updated successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        Get.back(); // Go back to previous screen
      } else {
        throw Exception(jsonDecode(response.body)['message']);
      }
    } catch (e) {
      Get.back(); // Remove loading dialog
      Get.snackbar(
        'Error',
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey[900]?.withOpacity(0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(16),
            labelStyle: const TextStyle(color: Colors.white), // White labels
            hintStyle: const TextStyle(color: Colors.white70), // White hints
          ),
          textTheme: Theme.of(context).textTheme.apply(
                bodyColor: Colors.white,
                displayColor: Colors.white,
              ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.8),
                Colors.black.withOpacity(0.9),
              ],
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Profile Header
                _buildProfileHeader(),

                // Form Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic Info Card
                      _buildCard('Basic Information', [
                        _buildTextField(
                          label: 'About',
                          controller: _aboutController,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          label: 'Profession',
                          controller: _professionController,
                        ),
                        const SizedBox(height: 16),
                        _buildHeightDropdown(),
                      ]),

                      const SizedBox(height: 16),

                      // Contact Card
                      _buildCard('Contact Details', [
                        _buildCountryDropdown(),
                        const SizedBox(height: 16),
                        _buildTextField(
                          label: 'Location',
                          controller: _locationController,
                          prefix: const Icon(Icons.location_on_outlined,
                              color: Colors.white70),
                          enabled: false, // Make the field uneditable
                        ),
                      ]),

                      const SizedBox(height: 16),

                      // Languages Card
                      _buildCard('Languages', [
                        _buildLanguagesSelector(),
                      ]),

                      const SizedBox(height: 16),

                      // Bank Details Card
                      _buildCard('Bank Account Details', [
                        _buildBankDetails(),
                      ]),

                      const SizedBox(height: 16),

                      // Verification Card
                      _buildCard('Verification', [
                        _buildPanVerification(),
                      ]),

                      const SizedBox(height: 32),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Save Changes',
                            style: GoogleFonts.inter(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryColor.withOpacity(0.2),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundImage: currentUser?.photos?.isNotEmpty == true
                    ? NetworkImage(currentUser!.photos!.first)
                    : null,
                child: currentUser?.photos?.isEmpty ?? true
                    ? const Icon(Icons.person, size: 50)
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primaryColor,
                  child: IconButton(
                    icon: const Icon(Icons.camera_alt, size: 18),
                    onPressed: () => _pickImage(true),
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            currentUser?.name ?? 'Your Name',
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Text(
            currentUser?.email ?? 'email@example.com',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900]?.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    Widget? prefix,
    bool enabled = true, // Add enabled parameter with default true
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      enabled: enabled, // Use the parameter
      style: TextStyle(
        color: enabled
            ? Colors.white
            : Colors.white.withOpacity(0.7), // Dim the text if disabled
        fontSize: 16,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefix,
        labelStyle: const TextStyle(color: Colors.white70),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primaryColor),
        ),
        fillColor: enabled
            ? Colors.grey[900]?.withOpacity(0.5)
            : Colors.grey[900]?.withOpacity(0.3), // Darker when disabled
      ),
    );
  }

  Widget _buildCountryDropdown() {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Country',
        labelStyle: const TextStyle(color: Colors.white70),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        filled: true,
        fillColor:
            Colors.grey[900]?.withOpacity(0.3), // Darker to indicate disabled
        contentPadding: const EdgeInsets.all(16),
      ),
      child: Text(
        selectedCountry,
        style: TextStyle(
          color: Colors.white
              .withOpacity(0.7), // Slightly dimmed to show disabled state
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildHeightDropdown() {
    return DropdownButtonFormField<String>(
      value: selectedHeight,
      dropdownColor: Colors.grey[900],
      style: const TextStyle(color: Colors.white),
      items: heights.map((height) {
        return DropdownMenuItem(
          value: height,
          child: Text(
            height,
            style: const TextStyle(color: Colors.white),
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          selectedHeight = value;
        });
      },
      decoration: const InputDecoration(
        labelText: 'Height',
        labelStyle: TextStyle(color: Colors.white70),
      ),
    );
  }

  Widget _buildLanguagesSelector() {
    return Wrap(
      spacing: 8,
      children: languages.map((language) {
        final isSelected = selectedLanguages.contains(language);
        return FilterChip(
          label: Text(
            language,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
            ),
          ),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                selectedLanguages.add(language);
              } else {
                selectedLanguages.remove(language);
              }
            });
          },
          backgroundColor: Colors.grey[850]?.withOpacity(0.5),
          selectedColor: AppColors.primaryColor.withOpacity(0.8),
          checkmarkColor: Colors.white,
        );
      }).toList(),
    );
  }

  Widget _buildBankDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          label: 'Account Holder Name',
          controller: _accountHolderNameController,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Bank Name',
          controller: _bankNameController,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Account Number',
          controller: _accountNumberController,
        ),
        const SizedBox(height: 16),
        // Conditional fields based on country
        if (selectedCountry == 'India')
          _buildTextField(
            label: 'IFSC Code',
            controller: _ifscCodeController,
          )
        else ...[
          _buildTextField(
            label: 'SWIFT Code',
            controller: _swiftCodeController,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            label: 'IBAN',
            controller: _ibanController,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            label: 'Routing Number',
            controller: _routingNumberController,
          ),
        ],
      ],
    );
  }

  Widget _buildPanVerification() {
    final isIndian = selectedCountry == 'India';
    final documentLabel = isIndian ? 'PAN Number' : 'Government ID Number';
    final uploadLabel = isIndian ? 'Upload PAN Photo' : 'Upload Government ID';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          label: documentLabel,
          controller: _panController,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => _pickImage(false),
          icon: const Icon(Icons.upload_file),
          label: Text(uploadLabel),
        ),
      ],
    );
  }
}
