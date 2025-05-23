// Local Alert Service for triggering on-device alerts during fall detection
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:torch_light/torch_light.dart';
import 'settings_service.dart';

/// A service class for managing local device alerts when falls are detected.
/// Provides functionality for vibration, alarm sounds, and flashlight alerts.
class LocalAlertService {
  // Singleton pattern
  static final LocalAlertService _instance = LocalAlertService._internal();
  factory LocalAlertService() => _instance;
  LocalAlertService._internal();

  // Audio player for alarm sounds
  late AudioPlayer _audioPlayer;

  // Alert control
  bool _isAlerting = false;
  Timer? _flashlightTimer;
  Timer? _alertDurationTimer;
  bool _flashlightOn = false;

  // Alert durations and patterns
  static const int _maxAlertDurationSeconds =
      30; // Max duration to conserve battery
  static const List<int> _vibrationPattern = [
    500,
    1000,
    500,
    1000,
    500,
  ]; // On-off pattern in milliseconds
  static const int _flashlightToggleMs = 500; // Flashlight toggle interval

  /// Initialize the service and prepare resources
  Future<void> initialize() async {
    try {
      debugPrint('Initializing LocalAlertService');
      _audioPlayer = AudioPlayer();

      // Pre-load the alarm sound for faster playback
      await _audioPlayer.setSource(AssetSource('alarm.mp3'));
      await _audioPlayer.setReleaseMode(
        ReleaseMode.loop,
      ); // Loop the alarm sound
      await _audioPlayer.setVolume(1.0); // Max volume

      debugPrint('LocalAlertService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing LocalAlertService: $e');
    }
  }

  /// Start all configured alerts based on user settings
  Future<void> startAlerts() async {
    if (_isAlerting) return; // Prevent multiple alert sequences

    _isAlerting = true;
    final settings = await SettingsService.getSettings();

    debugPrint(
      'Starting local alerts with settings: '
      'vibrate=${settings.vibrateOnFall}, '
      'alarm=${settings.playAlarmOnFall}, '
      'flashlight=${settings.flashLightOnFall}',
    );

    // Start each alert type based on settings
    if (settings.vibrateOnFall) {
      _startVibration();
    }

    if (settings.playAlarmOnFall) {
      _playAlarm();
    }

    if (settings.flashLightOnFall) {
      _startFlashlight();
    }

    // Set a timer to stop all alerts after maximum duration to conserve battery
    _alertDurationTimer = Timer(
      Duration(seconds: _maxAlertDurationSeconds),
      () {
        stopAllAlerts();
      },
    );
  }

  /// Stop all alerts
  Future<void> stopAllAlerts() async {
    if (!_isAlerting) return;

    debugPrint('Stopping all local alerts');
    _isAlerting = false;

    // Cancel timers
    _alertDurationTimer?.cancel();
    _flashlightTimer?.cancel();

    // Stop vibration
    await Vibration.cancel();

    // Stop alarm
    await _audioPlayer.stop();

    // Turn off flashlight
    await _turnOffFlashlight();
  }

  /// Start device vibration with pattern
  Future<void> _startVibration() async {
    try {
      final hasVibrator = await Vibration.hasVibrator() ?? false;
      if (hasVibrator) {
        await Vibration.vibrate(
          pattern: _vibrationPattern,
          repeat: 0,
        ); // 0 means repeat indefinitely
        debugPrint('Vibration started with pattern');
      } else {
        debugPrint('Device does not have vibrator capability');
      }
    } catch (e) {
      debugPrint('Error starting vibration: $e');
    }
  }

  /// Play the alarm sound
  Future<void> _playAlarm() async {
    try {
      await _audioPlayer.resume();
      debugPrint('Alarm sound started');
    } catch (e) {
      debugPrint('Error playing alarm sound: $e');
    }
  }

  /// Start flashlight toggling
  Future<void> _startFlashlight() async {
    try {
      bool hasFlashlight = await _checkFlashlightAvailability();

      if (!hasFlashlight) {
        debugPrint('Flashlight not available on this device');
        return;
      }

      // Clear any existing timer
      _flashlightTimer?.cancel();

      // Create a new timer that toggles the flashlight on/off
      _flashlightTimer = Timer.periodic(
        Duration(milliseconds: _flashlightToggleMs),
        (timer) async {
          if (!_isAlerting) {
            timer.cancel();
            return;
          }

          if (_flashlightOn) {
            await _turnOffFlashlight();
          } else {
            await _turnOnFlashlight();
          }
        },
      );

      // Start with flashlight on
      await _turnOnFlashlight();
    } catch (e) {
      debugPrint('Error controlling flashlight: $e');
    }
  }

  /// Check if flashlight is available
  Future<bool> _checkFlashlightAvailability() async {
    try {
      return await TorchLight.isTorchAvailable();
    } catch (e) {
      debugPrint('Error checking flashlight availability: $e');
      return false;
    }
  }

  /// Turn on the flashlight
  Future<void> _turnOnFlashlight() async {
    try {
      await TorchLight.enableTorch();
      _flashlightOn = true;
    } catch (e) {
      debugPrint('Error turning on flashlight: $e');
    }
  }

  /// Turn off the flashlight
  Future<void> _turnOffFlashlight() async {
    try {
      await TorchLight.disableTorch();
      _flashlightOn = false;
    } catch (e) {
      debugPrint('Error turning off flashlight: $e');
    }
  }

  /// Update settings for local alerts
  Future<bool> updateAlertSettings({
    bool? vibrateOnFall,
    bool? playAlarmOnFall,
    bool? flashLightOnFall,
  }) async {
    try {
      final settings = await SettingsService.getSettings();

      return SettingsService.saveSettings(
        settings.copyWith(
          vibrateOnFall: vibrateOnFall,
          playAlarmOnFall: playAlarmOnFall,
          flashLightOnFall: flashLightOnFall,
        ),
      );
    } catch (e) {
      debugPrint('Error updating alert settings: $e');
      return false;
    }
  }

  /// Dispose of resources
  Future<void> dispose() async {
    try {
      await stopAllAlerts();
      await _audioPlayer.dispose();
    } catch (e) {
      debugPrint('Error disposing LocalAlertService: $e');
    }
  }
}
