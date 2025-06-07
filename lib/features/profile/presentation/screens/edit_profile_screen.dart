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

  // Add this property to track photos
  List<String> userPhotos = [];

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

        // Initialize photos array
        userPhotos = List<String>.from(currentUser?.photos ?? []);

        // Set initial values
        // _phoneController.text = currentUser?.phone ?? '';
        _aboutController.text = currentUser?.about ?? '';
        _professionController.text = currentUser?.profession ?? '';
        _locationController.text = currentUser?.location?.city ?? '';

        // Safely set the height value - ensure it exists in the heights list
        if (currentUser?.height != null &&
            heights.contains(currentUser!.height)) {
          selectedHeight = currentUser!.height;
        } else {
          selectedHeight = heights.first; // Default to the first height
        }

        selectedLanguages = currentUser?.languages?.toList() ?? [];
        _panController.text = currentUser?.panDetails?.panNumber ?? '';

        // Safely set country
        if (currentUser?.location?.country != null &&
            countries.contains(currentUser!.location!.country)) {
          selectedCountry = currentUser!.location!.country!;
        } else {
          selectedCountry = 'India'; // Default
        }

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

  // Add this method to handle photo deletion
  void _deletePhoto(int index) {
    setState(() {
      userPhotos.removeAt(index);
    });
  }

  // Add this method to handle photo reordering
  void _onReorderPhotos(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final String item = userPhotos.removeAt(oldIndex);
      userPhotos.insert(newIndex, item);
    });
  }

  Future<void> _saveProfile() async {
    try {
      // Show loading indicator
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      // Upload images first if selected
      String? profileImageUrl;
      String? panImageUrl;

      if (profileImagePath != null) {
        // Verify file exists before uploading
        final profileFile = File(profileImagePath!);
        if (!profileFile.existsSync()) {
          throw Exception('Profile image file not found');
        }

        print('Uploading profile image: $profileImagePath');
        final result = await ApiService.uploadImage(profileFile);
        if (result['success']) {
          profileImageUrl = result['imageUrl'];
          print('Profile image uploaded successfully: $profileImageUrl');
        } else {
          throw Exception(
              'Failed to upload profile image: ${result['message']}');
        }
      }

      if (panImagePath != null) {
        // Verify file exists before uploading
        final panFile = File(panImagePath!);
        if (!panFile.existsSync()) {
          throw Exception('ID document file not found');
        }

        print('Uploading ID document: $panImagePath');
        final result = await ApiService.uploadImage(panFile);
        if (result['success']) {
          panImageUrl = result['imageUrl'];
          print('ID document uploaded successfully: $panImageUrl');
        } else {
          throw Exception('Failed to upload ID document: ${result['message']}');
        }
      }

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

      // Create or update photos array with new profile image URL
      if (profileImageUrl != null) {
        // Add the new photo to our tracked photos array
        if (!userPhotos.contains(profileImageUrl)) {
          userPhotos.insert(0, profileImageUrl);
        }
      }

      // Use the user's reordered photos array
      updateData['photos'] = userPhotos;

      // Set the first photo as the profile image for compatibility
      if (userPhotos.isNotEmpty) {
        updateData['image'] = userPhotos[0];
      }

      // Add PAN/Government ID image URL if uploaded
      if (panImageUrl != null) {
        updateData['panDetails']['panImage'] = panImageUrl;
      }

      print('Sending profile update data: $updateData');
      final response = await ApiService.updateProfile(updateData);
      print(
          'Profile update response: ${response.statusCode} - ${response.body}');

      // Remove loading dialog
      Get.back();

      if (response.statusCode == 200) {
        Get.snackbar(
          'Success',
          'Profile updated successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );

        // Reload profile data to show updated information
        await _loadCurrentProfile();

        Get.back(); // Go back to previous screen
      } else {
        throw Exception(
            jsonDecode(response.body)['message'] ?? 'Failed to update profile');
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

                // Photos Gallery
                _buildPhotoGallery(),

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

  // Add this new method to build the photo gallery
  Widget _buildPhotoGallery() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My Photos',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Drag to reorder. First photo will be your profile picture.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 120,
            child: userPhotos.isEmpty
                ? Center(
                    child: Text(
                      'No photos yet. Add some photos!',
                      style: TextStyle(color: Colors.white.withOpacity(0.7)),
                    ),
                  )
                : ReorderableListView(
                    scrollDirection: Axis.horizontal,
                    onReorder: _onReorderPhotos,
                    children: List.generate(userPhotos.length, (index) {
                      return Container(
                        key: Key('photo-$index'),
                        margin: const EdgeInsets.only(right: 12),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                userPhotos[index],
                                width: 100,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 100,
                                    height: 120,
                                    color: Colors.grey[800],
                                    child: const Icon(
                                      Icons.error_outline,
                                      color: Colors.white,
                                    ),
                                  );
                                },
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.only(
                                    bottomLeft: Radius.circular(8),
                                  ),
                                ),
                                child: IconButton(
                                  icon: Icon(Icons.delete,
                                      color: Colors.white, size: 18),
                                  padding: EdgeInsets.all(4),
                                  constraints: BoxConstraints(),
                                  onPressed: () => _deletePhoto(index),
                                ),
                              ),
                            ),
                            if (index == 0)
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 4),
                                  color:
                                      AppColors.primaryColor.withOpacity(0.8),
                                  child: Text(
                                    'Profile Photo',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ),
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton.icon(
              onPressed: () => _pickImage(true),
              icon: const Icon(Icons.add_photo_alternate),
              label: Text('Add New Photo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: AppColors.primaryColor),
              ),
            ),
          ),
        ],
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
              // Show local image preview if available, otherwise show first photo from the reordered list
              CircleAvatar(
                radius: 50,
                backgroundImage: profileImagePath != null
                    ? FileImage(File(profileImagePath!))
                    : (userPhotos.isNotEmpty
                        ? NetworkImage(userPhotos[0])
                        : null),
                child: (profileImagePath == null && userPhotos.isEmpty)
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
    // Safety check - ensure selectedCountry is in the list
    final String safeSelectedCountry =
        countries.contains(selectedCountry) ? selectedCountry : 'India';

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
        safeSelectedCountry,
        style: TextStyle(
          color: Colors.white
              .withOpacity(0.7), // Slightly dimmed to show disabled state
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildHeightDropdown() {
    // Safety check - ensure selectedHeight is in the list
    final String safeSelectedHeight =
        (selectedHeight != null && heights.contains(selectedHeight))
            ? selectedHeight!
            : heights.first;

    return DropdownButtonFormField<String>(
      value: safeSelectedHeight,
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
