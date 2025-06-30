import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';

/// A service that manages ringtone playback based on device sound settings
class RingtoneService {
  static final RingtoneService _instance = RingtoneService._internal();
  factory RingtoneService() => _instance;
  RingtoneService._internal();

  bool _isRingtonePlaying = false;
  bool _isVibrating = false;
  Timer? _vibrateTimer;

  // Current ringtone intensity (0.0 to 1.0)
  double _volume = 0.8;

  /// Initialize the ringtone service
  Future<void> initialize() async {
    // Can add any initialization code here if needed
  }

  /// Play ringtone based on device ringer mode
  Future<void> playRingtone({bool asIncomingCall = true}) async {
    if (_isRingtonePlaying) {
      debugPrint('🔊 Ringtone already playing, ignoring request');
      return;
    }

    try {
      // Check the device's ringer mode
      final RingerModeStatus ringerStatus = await SoundMode.ringerModeStatus;
      debugPrint('🔊 Device ringer status: $ringerStatus');

      switch (ringerStatus) {
        case RingerModeStatus.silent:
          debugPrint('🔊 Device is in silent mode, not playing sound');
          // In silent mode, we don't play sound but might vibrate depending on device settings
          if (Platform.isAndroid) {
            _startVibrating();
          }
          break;

        case RingerModeStatus.vibrate:
          debugPrint('🔊 Device is in vibrate mode, vibrating only');
          // In vibrate mode, only vibrate
          _startVibrating();
          break;

        case RingerModeStatus.normal:
          debugPrint('🔊 Device is in normal mode, playing ringtone');
          // In normal mode, play sound and vibrate
          await _playAudioRingtone(asIncomingCall);
          _startVibrating();
          break;

        default:
          debugPrint(
              '🔊 Unknown ringer mode: $ringerStatus, using normal mode behavior');
          // Default to normal mode behavior
          await _playAudioRingtone(asIncomingCall);
          _startVibrating();
          break;
      }

      _isRingtonePlaying = true;
    } catch (e) {
      debugPrint('❌ Error playing ringtone: $e');
    }
  }

  /// Start device vibration for call alert
  void _startVibrating() {
    if (_isVibrating) return;

    try {
      _isVibrating = true;

      // Create a vibration pattern using a timer
      _vibrateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        if (Platform.isAndroid) {
          FlutterRingtonePlayer().play(
            android: AndroidSounds.notification,
            ios: IosSounds.glass,
            looping: false,
            volume: 0,
            asAlarm: false,
          );
        } else if (Platform.isIOS) {
          // iOS doesn't need special handling for vibration only
          FlutterRingtonePlayer().play(
            ios: IosSounds.bell,
            looping: false,
          );
        }
      });
    } catch (e) {
      debugPrint('❌ Error starting vibration: $e');
    }
  }

  /// Play the audio part of the ringtone
  Future<void> _playAudioRingtone(bool asIncomingCall) async {
    try {
      await FlutterRingtonePlayer().play(
        android: asIncomingCall
            ? AndroidSounds.ringtone
            : AndroidSounds.notification,
        ios: asIncomingCall ? IosSounds.electronic : IosSounds.triTone,
        looping: asIncomingCall, // Only loop for actual calls
        volume: _volume,
        asAlarm:
            asIncomingCall, // Use alarm channel for calls to bypass some silencing
      );
    } catch (e) {
      debugPrint('❌ Error playing audio ringtone: $e');
    }
  }

  /// Stop the ringtone and vibration
  Future<void> stopRingtone() async {
    if (!_isRingtonePlaying && !_isVibrating) {
      return;
    }

    try {
      // Stop audio
      await FlutterRingtonePlayer().stop();

      // Stop vibration
      _vibrateTimer?.cancel();
      _vibrateTimer = null;

      _isRingtonePlaying = false;
      _isVibrating = false;

      debugPrint('🔊 Ringtone and vibration stopped');
    } catch (e) {
      debugPrint('❌ Error stopping ringtone: $e');
    }
  }

  /// Set the volume for ringtone playback
  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
  }

  /// Clean up resources
  void dispose() {
    stopRingtone();
  }
}
