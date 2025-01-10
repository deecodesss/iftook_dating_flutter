import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

Future<bool> _handleLocationPermission() async {
  bool serviceEnabled;
  LocationPermission permission;

  // Check if location services are enabled
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    Get.snackbar(
      "Location Error",
      "Location services are disabled. Please enable them.",
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
    return false;
  }

  // Check permission status
  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      Get.snackbar(
        "Permission Denied",
        "Location permission is denied. Please grant permission to continue.",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }
  }

  if (permission == LocationPermission.deniedForever) {
    Get.snackbar(
      "Permission Denied Forever",
      "Location permission is permanently denied. Please enable it from settings.",
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
    return false;
  }

  return true;
}
