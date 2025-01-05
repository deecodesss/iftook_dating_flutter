import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppThemes {
  // Light Mode Color Palette
  static final Map<String, Color> AppColors = {
    // Light background with soft, warm undertones
    'primaryBackground': const Color(0xFFF5F7FA),
    // Soft, muted blue for secondary background
    'secondaryBackground': const Color(0xFFE6EAF0),
    // Deep blue-gray for accent, maintaining the original theme's spirit
    'accentColor': const Color(0xFF2C3E50),
    // Lighter, softer version of the original secondary accent
    'secondaryAccent': const Color(0xFF4A6FA5),
    // Slightly softer highlight color
    'highlightColor': const Color(0xFF4A90E2),
    // Softer primary color
    'primaryColor': const Color(0xFF5A9CFF),
    // Soft, less intense red
    'redColor': const Color(0xFFFF6B6B),
    // Softer green
    'greenColor': const Color(0xFF4ECDC4)
  };

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: AppColors['primaryColor'],
    scaffoldBackgroundColor: AppColors['primaryBackground'],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: AppColors['accentColor'],
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: AppColors['accentColor']),
    ),
    buttonTheme: ButtonThemeData(
      buttonColor: AppColors['primaryColor'],
      textTheme: ButtonTextTheme.primary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors['primaryColor'],
        foregroundColor: Colors.white,
      ),
    ),
    textTheme: GoogleFonts.robotoTextTheme().apply(
      bodyColor: AppColors['accentColor'],
      displayColor: AppColors['accentColor'],
    ),
    colorScheme: ColorScheme.light(
      primary: AppColors['primaryColor']!,
      secondary: AppColors['highlightColor']!,
      background: AppColors['primaryBackground']!,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: AppColors['secondaryAccent']!.withOpacity(0.3),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: AppColors['secondaryAccent']!.withOpacity(0.3),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: AppColors['primaryColor']!,
          width: 2,
        ),
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: const Color(0xff487FD9),
    scaffoldBackgroundColor: const Color(0xff090A0C),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        // color: Theme.of(context).colorScheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    buttonTheme: const ButtonThemeData(
      buttonColor: Color(0xff487FD9),
      textTheme: ButtonTextTheme.primary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xff487FD9),
      ),
    ),
    textTheme: GoogleFonts.robotoTextTheme().apply(),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xff487FD9),
      secondary: Color.fromARGB(255, 60, 162, 236),
      background: Color.fromRGBO(18, 18, 18, 1),
    ),
  );
}
