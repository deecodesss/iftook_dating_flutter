import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:iftook/core/widgets/charges_bottom_sheet.dart';
import 'package:iftook/features/home/presentation/screens/home_screen.dart';
import 'package:iftook/helpers/app_colors.dart';
import 'package:intl/intl.dart';

import '../../controllers/auth_controller.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthController _authController = Get.put(AuthController());
  final PageController _pageController = PageController();
  final _formKey = GlobalKey<FormState>();
  int _currentPage = 0;

  // Controllers and variables remain the same as your original code
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _aboutController = TextEditingController();
  final TextEditingController _professionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _panController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  DateTime? _selectedDate;
  String _selectedGender = '';
  String _interestedIn = '';
  List<String> _selectedInterests = [
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
  String _country = '';
  String _state = '';
  String _city = '';
  List<String> _photos = [];
  bool _isLoadingLocation = true;
  String _locationError = '';
  final List<String> _genderOptions = ['Male', 'Female'];
  final List<String> _interestedInOptions = ['Men', 'Women'];
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

  // Add missing variables for Google Sign-in
  bool _isFromGoogle = false;
  Map<String, dynamic>? _googleData;

  // Add missing variables for email verification
  bool _isEmailVerified = false;
  final TextEditingController _otpController = TextEditingController();
  bool _showOtpInput = false;
  String? _sentOtp;

  // Theme colors
  final Color _primaryColor = const Color(0xFFE91E63);
  final Color _surfaceColor = const Color(0xFF1E1E1E);
  final Color _backgroundColor = const Color(0xFF121212);
  final Color _cardColor = const Color(0xFF2A2A2A);
  final Color _chipSelectedColor = const Color(0xFFE91E63);
  final Color _chipUnselectedColor = const Color(0xFF3A3A3A);

  @override
  void initState() {
    _getCurrentLocation();

    // Check if coming from Google Sign-in
    final args = Get.arguments;
    if (args != null && args['fromGoogle'] == true) {
      _isFromGoogle = true;
      _googleData = args['googleData'];
      _prefillGoogleData();
    }

    super.initState();
  }

  void _prefillGoogleData() {
    if (_googleData != null) {
      _nameController.text = _googleData!['name'] ?? '';
      _emailController.text = _googleData!['email'] ?? '';
      _isEmailVerified = true;
      _authController.setEmailVerified(true);

      // Update the controller values
      _authController.name.value = _googleData!['name'] ?? '';
      _authController.email.value = _googleData!['email'] ?? '';
    }
  }

  String? selectedHeight;
  List<String> selectedLanguages = [];
  String? profileImagePath;
  String? panImagePath;
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

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = '';
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = 'Location services are disabled';
          _isLoadingLocation = false;
        });
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationError = 'Location permission denied';
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError = 'Location permissions permanently denied';
          _isLoadingLocation = false;
        });
        return;
      }

      // Get the current position
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      // Perform reverse geocoding
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        setState(() {
          _country = place.country ?? '';
          _state = place.administrativeArea ?? '';
          _city = place.locality ?? '';
          _isLoadingLocation = false;
        });
        print('Location retrieved: $_country, $_state, $_city'); // Debug print
      }
    } catch (e) {
      setState(() {
        _locationError = 'Error getting location: $e';
        _isLoadingLocation = false;
      });
      print('Location error: $e'); // Debug print
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 6570)),
      firstDate: DateTime.now().subtract(const Duration(days: 36500)),
      lastDate: DateTime.now().subtract(const Duration(days: 6570)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: _primaryColor,
              surface: _surfaceColor,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: _surfaceColor,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = DateFormat('MMM dd, yyyy').format(picked);
      });
    }
  }
  //
  // void _nextPage() {
  //   if (_currentPage < 5) {
  //     _pageController.nextPage(
  //       duration: const Duration(milliseconds: 300),
  //       curve: Curves.easeInOut,
  //     );
  //     setState(() {
  //       _currentPage++;
  //     });
  //   } else {
  //     _handleRegistration();
  //   }
  // }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentPage--;
      });
    }
  }

  void _nextPage() {
    bool isValid = true;

    // Validate the current step based on the current page index
    switch (_currentPage) {
      case 0:
        isValid = _validateBasicInfo();
        break;
      case 1:
        isValid = _validateAdditionalInfo();
        break;
      case 2:
        isValid = _validatePhotos();
        break;
      case 3:
        isValid = _validateLocation();
        break;
      case 4:
        isValid = _validatePreferences();
        break;
      case 5:
        isValid = _validateEarnings();
        break;
    }

    if (isValid) {
      if (_currentPage < 5) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        setState(() {
          _currentPage++;
        });
      } else {
        _handleRegistration();
      }
    }
  }

  bool _validateBasicInfo() {
    if (_nameController.text.isEmpty) {
      Get.snackbar('Error', 'Please enter your full name',
          backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
    if (_dobController.text.isEmpty) {
      Get.snackbar('Error', 'Please select your date of birth',
          backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
    if (_selectedGender.isEmpty) {
      Get.snackbar('Error', 'Please select your gender',
          backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
    if (_emailController.text.isEmpty ||
        !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
            .hasMatch(_emailController.text)) {
      Get.snackbar('Error', 'Please enter a valid email',
          backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
    if (!_isEmailVerified && !_isFromGoogle) {
      Get.snackbar('Error', 'Please verify your email address first',
          backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }

    // Skip password validation for Google users
    if (!_isFromGoogle) {
      if (_passwordController.text.isEmpty ||
          _passwordController.text.length < 8) {
        Get.snackbar('Error', 'Password must be at least 8 characters',
            backgroundColor: Colors.red, colorText: Colors.white);
        return false;
      }
      if (_confirmPasswordController.text.isEmpty ||
          _confirmPasswordController.text != _passwordController.text) {
        Get.snackbar('Error', 'Passwords do not match',
            backgroundColor: Colors.red, colorText: Colors.white);
        return false;
      }
    }

    return true;
  }

  bool _validateAdditionalInfo() {
    if (_aboutController.text.isEmpty) {
      Get.snackbar('Error', 'Please enter something about yourself',
          backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
    if (selectedHeight == null) {
      Get.snackbar('Error', 'Please select your height',
          backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
    if (selectedLanguages.isEmpty) {
      Get.snackbar('Error', 'Please select at least one language',
          backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
    if (_professionController.text.isEmpty) {
      Get.snackbar('Error', 'Please enter your profession',
          backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
    return true;
  }

  bool _validatePhotos() {
    // if (_photos.length < 2) {
    //   Get.snackbar('Error', 'Please add at least 2 photos',
    //       backgroundColor: Colors.red, colorText: Colors.white);
    //   return false;
    // }
    return true;
  }

  bool _validateLocation() {
    if (_country.isEmpty || _state.isEmpty || _city.isEmpty) {
      Get.snackbar('Error', 'Please ensure your location is correctly set',
          backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
    return true;
  }

  bool _validatePreferences() {
    if (_selectedInterests.isEmpty) {
      Get.snackbar('Error', 'Please select at least one interest',
          backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
    return true;
  }

  bool _validateEarnings() {
    // Add validation logic for earnings if needed
    return true;
  }

  void _handleRegistration() {
    _authController.name.value = _nameController.text;
    _authController.email.value = _emailController.text;
    _authController.password.value = _passwordController.text;
    _authController.dob.value = _dobController.text;
    _authController.gender.value = _selectedGender;
    _authController.about.value = _aboutController.text;
    _authController.profession.value = _professionController.text;
    _authController.height.value = selectedHeight ?? '';
    _authController.languages.value = selectedLanguages;
    _authController.location.value = {
      'country': _country,
      'state': _state,
      'city': _city
    };
    _authController.interests.value = _selectedInterests;
    _authController.panDetails.value = {
      'panNumber': _panController.text,
      'panImage': ''
    };

    _authController
        .register(
      isGoogleSignup: _isFromGoogle,
      googleData: _googleData,
    )
        .then((_) {
      if (_authController.errorMessage.isEmpty) {
        Get.offAll(() => const HomeScreen());
        Get.snackbar('Success', 'Registration successful!',
            backgroundColor: Colors.green, colorText: Colors.white);
      } else {
        Get.snackbar('Error', _authController.errorMessage.value,
            backgroundColor: Colors.red, colorText: Colors.white);
      }
    });
  }

  // Your existing input decoration method
  InputDecoration _getInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _primaryColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _primaryColor, width: 2),
      ),
      filled: true,
      fillColor: _cardColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Future<void> _sendOtp() async {
    if (_emailController.text.isEmpty) {
      Get.snackbar(
        'Errorr',
        'Please enter an email address',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      final result = await _authController.sendOtp(_emailController.text);

      if (result['success']) {
        setState(() {
          _showOtpInput = true;
          _sentOtp = result['otp'].toString();
        });
      } else {
        Get.snackbar(
          'Error',
          result['message'] ?? 'Failed to send OTP',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to send OTP. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _verifyOtp(String enteredOtp) {
    if (enteredOtp == _sentOtp) {
      setState(() {
        _isEmailVerified = true;
        _showOtpInput = false;
      });
      _authController.setEmailVerified(true);
      Get.snackbar(
        'Success',
        'Email verified successfully!',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } else {
      Get.snackbar(
        'Error',
        'Invalid OTP',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Widget _buildEmailSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _emailController,
                enabled: !_isEmailVerified &&
                    !_isFromGoogle, // Disable for Google users
                decoration: _getInputDecoration('Email').copyWith(
                  suffixIcon: _isEmailVerified || _isFromGoogle
                      ? Icon(Icons.verified, color: Colors.green)
                      : null,
                ),
                style: TextStyle(
                  color: (_isEmailVerified || _isFromGoogle)
                      ? Colors.grey
                      : Colors.white,
                ),
                keyboardType: TextInputType.emailAddress,
                validator: _validateEmail,
              ),
            ),
            if (!_isEmailVerified && !_isFromGoogle) ...[
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onPressed: _authController.isLoading.value ? null : _sendOtp,
                child: _authController.isLoading.value
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Verify'),
              ),
            ],
          ],
        ),
        if (_isFromGoogle) ...[
          const SizedBox(height: 8),
          Text(
            'Email verified via Google',
            style: TextStyle(
              color: Colors.green[400],
              fontSize: 12,
            ),
          ),
        ],
        if (_showOtpInput && !_isEmailVerified && !_isFromGoogle) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _otpController,
                  decoration: _getInputDecoration('Enter OTP').copyWith(
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.check),
                      onPressed: () => _verifyOtp(_otpController.text),
                      color: AppColors.primaryColor,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Please verify your email to continue',
            style: TextStyle(
              color: Colors.yellow[700],
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Step ${_currentPage + 1} of 6',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        leading: _currentPage > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _previousPage,
              )
            : null,
      ),
      body: PageView(
        // Replace the Obx widget with direct PageView
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildBasicInfoPage(),
          _buildAdditionalInfoPage(),
          _buildPhotosPage(),
          _buildLocationPage(),
          _buildPreferencesPage(),
          _buildEarningsPage(),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            if (_currentPage > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _previousPage,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: _primaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Back'),
                ),
              ),
            if (_currentPage > 0) const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _nextPage,
                child: Text(_currentPage < 4 ? 'Continue' : 'Finish'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Individual page builders
  Widget _buildBasicInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerTitle("Basics"),
            TextFormField(
              controller: _nameController,
              decoration: _getInputDecoration('Full Name'),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _dobController,
              readOnly: true,
              onTap: () => _selectDate(context),
              decoration: _getInputDecoration('Date of Birth').copyWith(
                suffixIcon: Icon(
                  Icons.calendar_today,
                  color: _primaryColor,
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gender',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _genderOptions.map((gender) {
                      return ChoiceChip(
                        label: Text(gender),
                        selected: _selectedGender == gender,
                        onSelected: (selected) {
                          setState(
                              () => _selectedGender = selected ? gender : '');
                        },
                        selectedColor: _chipSelectedColor,
                        backgroundColor: _chipUnselectedColor,
                        labelStyle: TextStyle(
                          color: _selectedGender == gender
                              ? Colors.white
                              : Colors.grey[300],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildEmailSection(),
            if (!_isFromGoogle) ...[
              const SizedBox(height: 20),
              TextFormField(
                controller: _passwordController,
                decoration: _getInputDecoration('Password').copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: _primaryColor,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                obscureText: _obscurePassword,
                validator: _validatePassword,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: _getInputDecoration('Confirm Password').copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: _primaryColor,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                obscureText: _obscureConfirmPassword,
                validator: _validateConfirmPassword,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerTitle("Additional Information"),

            // About Me
            TextFormField(
              controller: _aboutController,
              decoration: _getInputDecoration('About Me'),
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
            ),
            const SizedBox(height: 20),

            // Height Selection
            DropdownButtonFormField<String>(
              value: selectedHeight,
              items: heights.map((height) {
                return DropdownMenuItem(
                  value: height,
                  child: Text(height),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedHeight = value;
                });
              },
              style: const TextStyle(color: Colors.white),
              dropdownColor: _cardColor,
              decoration: _getInputDecoration('Height'),
            ),
            const SizedBox(height: 20),

            // Languages
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Languages',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: languages.map((language) {
                      return FilterChip(
                        label: Text(language),
                        selected: selectedLanguages.contains(language),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              selectedLanguages.add(language);
                            } else {
                              selectedLanguages.remove(language);
                            }
                          });
                        },
                        backgroundColor: _chipUnselectedColor,
                        selectedColor: _chipSelectedColor,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Profession
            TextFormField(
              controller: _professionController,
              decoration: _getInputDecoration('Profession'),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 20),

            // PAN Details
            // TextFormField(
            //   controller: _panController,
            //   decoration: _getInputDecoration('PAN Number (Optional)'),
            //   style: const TextStyle(color: Colors.white),
            // ),
            // const SizedBox(height: 8),
            // OutlinedButton.icon(
            //   onPressed: () {
            //     // Implement PAN photo upload logic
            //   },
            //   icon: const Icon(Icons.upload_file),
            //   label: const Text('Upload PAN Photo (Optional)'),
            //   style: OutlinedButton.styleFrom(
            //     foregroundColor: Colors.white,
            //     side: BorderSide(color: Colors.grey[700]!),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosPage() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade800),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate, size: 48, color: _primaryColor),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  // Implement photo upload logic
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Photos'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add at least 2 photos',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationPage() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            if (_isLoadingLocation)
              const Center(
                child: CircularProgressIndicator(),
              )
            else if (_locationError.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _locationError,
                  style: const TextStyle(color: Colors.red),
                ),
              )
            else ...[
              TextFormField(
                decoration: _getInputDecoration('Country'),
                initialValue: _country,
                readOnly: true,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 20),
              TextFormField(
                decoration: _getInputDecoration('State'),
                initialValue: _state,
                readOnly: true,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 20),
              TextFormField(
                decoration: _getInputDecoration('City'),
                initialValue: _city,
                readOnly: true,
                style: const TextStyle(color: Colors.white),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: _getCurrentLocation,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Location'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Looking for',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _interestAreas.map((interest) {
                  return FilterChip(
                    label: Text(interest),
                    selected: _selectedInterests.contains(interest),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedInterests.add(interest);
                        } else {
                          _selectedInterests.remove(interest);
                        }
                      });
                    },
                    selectedColor: _chipSelectedColor,
                    checkmarkColor: Colors.white,
                    backgroundColor: _chipUnselectedColor,
                    labelStyle: TextStyle(
                      color: _selectedInterests.contains(interest)
                          ? Colors.white
                          : Colors.grey[300],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEarningsPage() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set Your Earnings',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Define your charges for different services',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                showPriceBottomSheet(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text("Set Your Earnings"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _dobController.dispose();
    super.dispose();
  }
}
