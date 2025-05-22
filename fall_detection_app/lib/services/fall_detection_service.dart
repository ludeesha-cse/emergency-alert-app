import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:torch_light/torch_light.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/settings_model.dart';
import 'settings_service.dart';
import 'sms_service.dart';

class FallDetectionService {
  // Singleton instance
  static final FallDetectionService _instance =
      FallDetectionService._internal();
  factory FallDetectionService() => _instance;
  FallDetectionService._internal();

  // Streams
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;

  // Audio player for alarm
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Emergency contacts
  final List<String> _emergencyContacts = [];

  // Thresholds for detection
  final double _accelerometerThreshold =
      20.0; // A typical threshold for fall detection

  // Timer for checking falls periodically
  Timer? _fallDetectionTimer;

  // Service status
  bool _isRunning = false;

  // Settings
  AppSettings? _settings;

  // Getters
  bool get isRunning => _isRunning;
  List<String> get emergencyContacts => List.unmodifiable(_emergencyContacts);
  AppSettings? get settings => _settings;

  // Update the sensitivity of the fall detection algorithm
  Future<bool> updateSensitivity(double sensitivity) async {
    if (sensitivity < 0.0 || sensitivity > 1.0) {
      debugPrint('Invalid sensitivity value: $sensitivity. Must be between 0.0 and 1.0');
      return false;
    }
    
    // Update the local settings
    if (_settings != null) {
      _settings = _settings!.copyWith(fallDetectionSensitivity: sensitivity);
      
      // Adjust the accelerometer threshold based on sensitivity
      // Higher sensitivity means lower threshold (detect more falls)
      _adjustThresholds(sensitivity);
      
      debugPrint('Fall detection sensitivity updated to: $sensitivity');
    } else {
      // If settings not loaded, load them first
      _settings = await SettingsService.getSettings();
      _settings = _settings!.copyWith(fallDetectionSensitivity: sensitivity);
      _adjustThresholds(sensitivity);
    }
    
    return true;
  }
  
  // Adjust thresholds based on sensitivity
  void _adjustThresholds(double sensitivity) {
    // Adjust thresholds based on sensitivity (0.0-1.0)
    // Lower sensitivity means higher thresholds (fewer false positives)
    // This is a basic formula, can be refined with testing
    double newThreshold = 25.0 - (sensitivity * 10.0);
    // Don't let threshold go below 10.0 for safety
    if (newThreshold < 10.0) newThreshold = 10.0;
    
    debugPrint('Adjusting accelerometer threshold to: $newThreshold');
  }

  // Initialize the service
  Future<bool> initialize() async {
    // Request permissions
    final status = await _requestPermissions();
    if (!status) {
      debugPrint('Permissions not granted.');
      return false;
    }

    // Initialize settings
    _settings = await SettingsService.getSettings();

    // Use settings for configuring the service
    if (_settings != null) {
      // You could adjust thresholds based on settings here if needed
      debugPrint(
        'Service initialized with sensitivity: ${_settings!.fallDetectionSensitivity}',
      );
    }

    return true;
  }

  // Request all required permissions
  Future<bool> _requestPermissions() async {
    final permissions = await [
      Permission.location,
      Permission.locationAlways,
      Permission.locationWhenInUse,
      Permission.microphone,
      Permission.sms,
      Permission.sensors,
    ].request();

    // Check if all permissions are granted
    return permissions.values.every(
      (status) => status == PermissionStatus.granted,
    );
  }

  // Start monitoring for falls
  Future<bool> startMonitoring() async {
    if (_isRunning) return true;

    try {
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

      // Start the sensor subscriptions
      _startSensorSubscriptions();

      // Start periodic checks
      _startPeriodicChecks();

      _isRunning = true;
      debugPrint('Fall detection service started');
      return true;
    } catch (e) {
      debugPrint('Error starting service');
      return false;
    }
  }

  // Start periodic checks
  void _startPeriodicChecks() {
    _fallDetectionTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      // Perform any periodic checks required
      debugPrint('Performing periodic fall detection checks');
    });
  }

  // Stop monitoring
  Future<void> stopMonitoring() async {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _gyroscopeSubscription?.cancel();
    _gyroscopeSubscription = null;

    _fallDetectionTimer?.cancel();
    _fallDetectionTimer = null;

    final service = FlutterBackgroundService();
    service.invoke('stopService');

    _isRunning = false;
    debugPrint('Service stopped');
  }

  // Add emergency contact
  void addEmergencyContact(String phoneNumber) {
    if (!_emergencyContacts.contains(phoneNumber)) {
      _emergencyContacts.add(phoneNumber);
    }
  }

  // Remove emergency contact
  void removeEmergencyContact(String phoneNumber) {
    _emergencyContacts.remove(phoneNumber);
  }

  // Start sensor subscriptions
  void _startSensorSubscriptions() {
    // Listen to accelerometer events
    _accelerometerSubscription = accelerometerEvents.listen((
      AccelerometerEvent event,
    ) {
      // Calculate magnitude of acceleration
      final double magnitude = _calculateMagnitude(event.x, event.y, event.z);

      if (magnitude > _accelerometerThreshold) {
        // Potential fall detected, check with gyroscope data
        debugPrint('High acceleration detected');
        _checkForFall();
      }
    });

    // Listen to gyroscope events
    _gyroscopeSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
      // This would be used in conjunction with accelerometer data
      // to improve fall detection accuracy
    });
  }

  // Calculate magnitude of a 3D vector
  double _calculateMagnitude(double x, double y, double z) {
    return math.sqrt(x * x + y * y + z * z);
  }

  // Check if a fall occurred
  void _checkForFall() {
    // In a real app, this would use a more sophisticated algorithm
    // combining accelerometer and gyroscope data with time windows

    // For demo purposes, we'll simulate fall detection
    _handleFallDetected();
  }

  // Handle a detected fall
  Future<void> _handleFallDetected() async {
    debugPrint('FALL DETECTED!');

    // Use settings to determine what actions to take
    final settings = _settings ?? AppSettings();

    // Sound alarm if enabled
    if (settings.playAlarmOnFall) {
      await _playAlarm();
    }

    // Flash light if enabled
    if (settings.flashLightOnFall) {
      await _toggleFlashlight(true);
    }

    // Vibrate phone if enabled
    if (settings.vibrateOnFall) {
      await _vibratePhone();
    }

    // Get location
    final position = await _getCurrentLocation();

    // Send SMS if we have emergency contacts and a position
    if (_emergencyContacts.isNotEmpty && position != null) {
      await _sendEmergencySMS(position, settings.emergencyMessage);
    }

    // In a real app, we would wait for user confirmation or timeout
    // before sending SMS. For now, we'll just log it.
    debugPrint('Emergency SMS would be sent to contacts');
  }

  // Send emergency SMS
  Future<void> _sendEmergencySMS(
    Position position,
    String customMessage,
  ) async {
    final message = '$customMessage';

    await SmsService.sendSms(
      recipients: _emergencyContacts,
      message: message,
      position: position,
    );
  }

  // Play alarm sound
  Future<void> _playAlarm() async {
    // In a real app, you would use a real alarm sound from assets
    await _audioPlayer.setSource(AssetSource('alarm.mp3'));
    await _audioPlayer.resume();
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
      debugPrint('Error controlling flashlight');
    }
  }

  // Vibrate the phone
  Future<void> _vibratePhone() async {
    if (await Vibration.hasVibrator() == true) {
      // Vibrate with a pattern for better notification
      await Vibration.vibrate(pattern: [500, 1000, 500, 2000]);
    }
  }

  // Get current location
  Future<Position?> _getCurrentLocation() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      debugPrint('Error getting location');
      return null;
    }
  }
}

// Background service handlers defined outside the class
@pragma('vm:entry-point')
Future<bool> onServiceStart(ServiceInstance service) async {
  // This would handle background processing
  // For demo purposes, we'll just have a periodic check

  Timer.periodic(const Duration(seconds: 1), (timer) async {
    // In a real app, this would continue monitoring sensors
    // and running the fall detection algorithm
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "Fall Detection Running",
        content: "Monitoring for falls in background",
      );
    }

    service.invoke('update');
  });

  return true;
}

@pragma('vm:entry-point')
Future<bool> onBackgroundStart(ServiceInstance service) async {
  return await onServiceStart(service);
}
