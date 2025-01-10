import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:iftook/core/widgets/charges_bottom_sheet.dart';
import 'package:iftook/features/home/presentation/screens/home_screen.dart';
import 'package:intl/intl.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  DateTime? _selectedDate;
  String _selectedGender = '';
  String _interestedIn = '';
  List<String> _selectedInterests = [];
  String _country = '';
  String _state = '';
  String _city = '';
  List<String> _photos = [];
  @override
  void initState() {
    _getCurrentLocation();
    super.initState();
  }

  final List<String> _genderOptions = ['Male', 'Female', 'Non-binary', 'Other'];
  final List<String> _interestedInOptions = ['Men', 'Women', 'Both'];

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

  // Custom dark theme colors
  final Color _primaryColor = const Color(0xFFE91E63); // Pink
  final Color _surfaceColor = const Color(0xFF1E1E1E);
  final Color _backgroundColor = const Color(0xFF121212);
  final Color _cardColor = const Color(0xFF2A2A2A);
  final Color _chipSelectedColor = const Color(0xFFE91E63);
  final Color _chipUnselectedColor = const Color(0xFF3A3A3A);
  bool _isLoadingLocation = true;
  String _locationError = '';

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

  void _handleRegistration() {
    // Here you would typically send the data to your backend
    // For now, we'll just navigate to the home screen
    Get.offAll(() => const HomeScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Register',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _surfaceColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: _primaryColor,
            secondary: _primaryColor,
            surface: _surfaceColor,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep < 4) {
              setState(() => _currentStep++);
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            }
          },
          controlsBuilder: (context, controls) {
            return Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: controls.onStepCancel,
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
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentStep < 4) {
                          controls.onStepContinue?.call();
                        } else {
                          _handleRegistration(); // Add this
                        }
                      },
                      child: Text(_currentStep < 4 ? 'Continue' : 'Finish'),
                    ),
                  ),
                ],
              ),
            );
          },
          steps: [
            Step(
              title: const Text('Basic Info'),
              content: Column(
                children: [
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
                                setState(() =>
                                    _selectedGender = selected ? gender : '');
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
                ],
              ),
              isActive: _currentStep >= 0,
            ),
            Step(
              title: const Text('Photos'),
              content: Container(
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
                      Icon(Icons.add_photo_alternate,
                          size: 48, color: _primaryColor),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
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
              isActive: _currentStep >= 1,
            ),
            Step(
              title: const Text('Location'),
              content: Column(
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
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      decoration: _getInputDecoration('State'),
                      initialValue: _state,
                      readOnly: true,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      decoration: _getInputDecoration('City'),
                      initialValue: _city,
                      readOnly: true,
                    ),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _getCurrentLocation,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Location'),
                  ),
                ],
              ),
              isActive: _currentStep >= 2,
            ),
            Step(
              title: const Text('Preferences'),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          'Interested In',
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
                          children: _interestedInOptions.map((option) {
                            return ChoiceChip(
                              label: Text(option),
                              selected: _interestedIn == option,
                              onSelected: (selected) {
                                setState(() =>
                                    _interestedIn = selected ? option : '');
                              },
                              selectedColor: _chipSelectedColor,
                              backgroundColor: _chipUnselectedColor,
                              labelStyle: TextStyle(
                                color: _interestedIn == option
                                    ? Colors.white
                                    : Colors.grey[300],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
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
                ],
              ),
              isActive: _currentStep >= 3,
            ),
            Step(
              title: const Text('Charges'),
              content: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Set Your Charges',
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
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text("Set Your Charges"),
                    ),
                  ],
                ),
              ),
              isActive: _currentStep >= 4,
            ),
          ],
        ),
      ),
      floatingActionButton: _currentStep == 5
          ? FloatingActionButton.extended(
              onPressed: _handleRegistration,
              label: const Text('Complete Profile'),
              icon: const Icon(Icons.check),
              backgroundColor: _primaryColor,
              elevation: 4,
            )
          : null,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    super.dispose();
  }
}
