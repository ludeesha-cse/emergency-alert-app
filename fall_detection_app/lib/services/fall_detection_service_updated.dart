// Fall detection service with comprehensive fall detection algorithm
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:torch_light/torch_light.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/settings_model.dart';
import 'fall_detection_algorithm.dart';
import 'settings_service.dart';
import 'sms_service.dart';

class FallDetectionService {
  // Singleton instance
  static final FallDetectionService _instance =
      FallDetectionService._internal();
  factory FallDetectionService() => _instance;
  FallDetectionService._internal();

  // Fall detection algorithm
  late FallDetectionAlgorithm _fallDetectionAlgorithm;

  // Streams
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;

  // Audio player for alarm
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Timer for checking falls periodically and cooldown timer to prevent multiple alerts
  Timer? _fallDetectionTimer;
  Timer? _cooldownTimer;
  bool _inCooldown = false;

  // Service status
  bool _isRunning = false;

  // Settings
  AppSettings? _settings;

  // Sampling rate for sensor data (in milliseconds)
  double _samplingRateMs = 500; // Default sampling rate in ms

  // Getters
  bool get isRunning => _isRunning;

  // Initialize the service
  Future<bool> initialize() async {
    // Request permissions
    final status = await _requestPermissions();
    if (!status) {
      debugPrint('Permissions not granted.');
      return false;
    }

    // Load settings
    _settings = await SettingsService.getSettings();

    // Initialize algorithm with sensitivity from settings
    _fallDetectionAlgorithm = FallDetectionAlgorithm(
      sensitivity: _settings?.fallDetectionSensitivity ?? 0.5,
    );

    return true;
  }

  // Request all required permissions
  Future<bool> _requestPermissions() async {
    final permissions = [
      Permission.locationAlways,
      Permission.locationWhenInUse,
      Permission.microphone,
      Permission.sms,
      Permission.activityRecognition,
      Permission.notification, // Add notification permission for Android 13+
    ];
    final statuses = await permissions.request();
    // Check if all permissions are granted
    return statuses.values.every(
      (status) => status == PermissionStatus.granted,
    );
  }

  // Start monitoring for falls
  Future<bool> startMonitoring() async {
    if (_isRunning) return true;

    try {
      // Initialize or refresh settings
      _settings = await SettingsService.getSettings();

      // Update algorithm sensitivity
      _fallDetectionAlgorithm = FallDetectionAlgorithm(
        sensitivity: _settings?.fallDetectionSensitivity ?? 0.5,
      );

      // Initialize background service
      final service = FlutterBackgroundService();
      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onServiceStart,
          autoStart: true,
          isForegroundMode: true,
          notificationChannelId: 'fall_detection_channel',
          initialNotificationTitle: 'Fall Detection',
          initialNotificationContent: 'Monitoring for falls',
          foregroundServiceNotificationId: 888,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: true,
          onForeground: onServiceStart,
          onBackground: onBackgroundStart,
        ),
      );

      // Start sensor monitoring
      _startSensorMonitoring();

      _isRunning = true;
      debugPrint('Fall detection service started');
      return true;
    } catch (e) {
      debugPrint('Error starting service: $e');
      return false;
    }
  }

  // Stop monitoring
  Future<void> stopMonitoring() async {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _gyroscopeSubscription?.cancel();
    _gyroscopeSubscription = null;
    _fallDetectionTimer?.cancel();
    _fallDetectionTimer = null;
    _cooldownTimer?.cancel();
    _cooldownTimer = null;

    final service = FlutterBackgroundService();
    service.invoke('stopService');

    _isRunning = false;
    debugPrint('Fall detection service stopped');
  }

  // Start monitoring sensors for fall detection
  void _startSensorMonitoring() {
    // Listen to accelerometer events
    _accelerometerSubscription = accelerometerEvents.listen((
      AccelerometerEvent event,
    ) {
      // Feed data to algorithm
      _fallDetectionAlgorithm.addAccelerometerEvent(event);
    });

    // Listen to gyroscope events
    _gyroscopeSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
      // Feed data to algorithm
      _fallDetectionAlgorithm.addGyroscopeEvent(event);
    });

    // Start periodic checking for falls
    _fallDetectionTimer = Timer.periodic(
      Duration(milliseconds: _samplingRateMs.round()),
      (_) {
        if (!_inCooldown && _fallDetectionAlgorithm.detectFall()) {
          _handleFallDetected();
        }
      },
    );
  }

  // Simulate a fall (for testing)
  void simulateFall() {
    if (_isRunning && !_inCooldown) {
      _handleFallDetected();
    } else {
      debugPrint('Cannot simulate fall: service not running or in cooldown');
    }
  }

  // Handle a detected fall
  Future<void> _handleFallDetected() async {
    debugPrint('FALL DETECTED!');

    // Prevent multiple consecutive alerts
    _inCooldown = true;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(const Duration(seconds: 30), () {
      _inCooldown = false;
    });

    // Refresh settings
    _settings = await SettingsService.getSettings();

    // Sound alarm if enabled
    if (_settings?.playAlarmOnFall == true) {
      await _playAlarm();
    }

    // Flash light if enabled
    if (_settings?.flashLightOnFall == true) {
      await _toggleFlashlight(true);

      // Turn off flashlight after 10 seconds
      Future.delayed(const Duration(seconds: 10), () {
        _toggleFlashlight(false);
      });
    }

    // Vibrate phone if enabled
    if (_settings?.vibrateOnFall == true) {
      await _vibratePhone();
    }

    // Get location
    final position = await _getCurrentLocation();

    // Get emergency contacts from settings
    final contacts = _settings?.emergencyContacts ?? [];
    if (contacts.isNotEmpty) {
      // Convert to list of phone numbers
      final phoneNumbers = contacts
          .map((contact) => contact.phoneNumber)
          .toList();

      // Send SMS with location
      await SmsService.sendSms(
        recipients: phoneNumbers,
        message:
            _settings?.emergencyMessage ?? "I've fallen and need assistance.",
        position: position,
      );
    }
  }

  // Play alarm sound
  Future<void> _playAlarm() async {
    try {
      await _audioPlayer.setSource(AssetSource('alarm.mp3'));
      await _audioPlayer.resume();

      // Stop alarm after 30 seconds
      Future.delayed(const Duration(seconds: 30), () {
        _audioPlayer.stop();
      });
    } catch (e) {
      debugPrint('Error playing alarm sound: $e');
    }
  }

  // Toggle flashlight
  Future<void> _toggleFlashlight(bool enable) async {
    try {
      if (enable) {
        await TorchLight.enableTorch();
      } else {
        await TorchLight.disableTorch();
      }
    } catch (e) {
      debugPrint('Error controlling flashlight: $e');
    }
  }

  // Vibrate the phone
  Future<void> _vibratePhone() async {
    try {
      if (await Vibration.hasVibrator() == true) {
        // Vibrate with a pattern for better notification
        await Vibration.vibrate(pattern: [500, 1000, 500, 2000]);
      }
    } catch (e) {
      debugPrint('Error vibrating phone: $e');
    }
  }

  // Get current location
  Future<Position?> _getCurrentLocation() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  // Update sensitivity
  Future<void> updateSensitivity(double sensitivity) async {
    _settings = await SettingsService.getSettings();
    await SettingsService.updateSensitivity(sensitivity);

    // Update algorithm with new sensitivity
    _fallDetectionAlgorithm = FallDetectionAlgorithm(sensitivity: sensitivity);
  }

  // Allow setting the sampling rate from UI
  void setSamplingRate(double ms) {
    _samplingRateMs = ms;
    // Restart timer if running
    if (_isRunning) {
      _fallDetectionTimer?.cancel();
      _fallDetectionTimer = Timer.periodic(
        Duration(milliseconds: _samplingRateMs.round()),
        (_) {
          if (!_inCooldown && _fallDetectionAlgorithm.detectFall()) {
            _handleFallDetected();
          }
        },
      );
    }
  }
}

// Background service handlers defined outside the class
@pragma('vm:entry-point')
Future<bool> onServiceStart(ServiceInstance service) async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  // This would handle background processing
  // For demo purposes, we'll just have a periodic check
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    try {
      // In a real app, this would continue monitoring sensors
      // and running the fall detection algorithm
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "Fall Detection Running",
          content: "Monitoring for falls in background",
        );
      }
      service.invoke('update');
    } catch (e, stack) {
      // Log any errors to help with debugging
      debugPrint('Error in background service timer: '
          'Error: '
          'Stack: $stack');
    }
  });
  return true;
}

@pragma('vm:entry-point')
Future<bool> onBackgroundStart(ServiceInstance service) async {
  return await onServiceStart(service);
}
