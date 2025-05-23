import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import 'package:permission_handler/permission_handler.dart';

import '../models/settings_model.dart';
import 'settings_service.dart';
import 'emergency_alert_service.dart';
import 'local_alert_service.dart';

class FallDetectionService {
  // Singleton instance
  static final FallDetectionService _instance =
      FallDetectionService._internal();
  factory FallDetectionService() => _instance;
  FallDetectionService._internal();

  // Streams
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>?
  _gyroscopeSubscription; // Local alert service for handling all local alerts
  late LocalAlertService _localAlertService;
  // Thresholds for detection
  final double _accelerometerThreshold =
      20.0; // A typical threshold for fall detection

  // Timer for checking falls periodically
  Timer? _fallDetectionTimer;

  // Service status
  bool _isRunning = false;

  // Settings
  AppSettings? _settings; // Getters
  bool get isRunning => _isRunning;
  AppSettings? get settings => _settings;

  // Get emergency contacts from EmergencyAlertService
  // This ensures backward compatibility with existing code
  List<String> get emergencyContacts {
    // Return contacts as phone numbers for compatibility
    final contacts = _settings?.emergencyContacts ?? [];
    return contacts.map((contact) => contact.phoneNumber).toList();
  }

  // Update the sensitivity of the fall detection algorithm
  Future<bool> updateSensitivity(double sensitivity) async {
    if (sensitivity < 0.0 || sensitivity > 1.0) {
      debugPrint(
        'Invalid sensitivity value: $sensitivity. Must be between 0.0 and 1.0',
      );
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
    } // Initialize settings
    _settings = await SettingsService.getSettings();

    // Initialize the emergency alert service
    final emergencyService = EmergencyAlertService();
    await emergencyService.initialize();

    // Initialize the local alert service
    _localAlertService = LocalAlertService();
    await _localAlertService.initialize();

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
  // Emergency contacts are now managed by EmergencyAlertService

  // Start sensor subscriptions
  void _startSensorSubscriptions() {
    // Listen to accelerometer events
    _accelerometerSubscription = accelerometerEventStream().listen((
      AccelerometerEvent event,
    ) {
      // Calculate magnitude of acceleration
      final double magnitude = _calculateMagnitude(event.x, event.y, event.z);

      if (magnitude > _accelerometerThreshold) {
        // Potential fall detected, check with gyroscope data
        debugPrint('High acceleration detected');
        _checkForFall();
      }
    }); // Listen to gyroscope events
    _gyroscopeSubscription = gyroscopeEventStream().listen((
      GyroscopeEvent event,
    ) {
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

    // Use LocalAlertService to handle all local alerts (sound, vibration, flashlight)
    // The service checks settings internally to determine which alerts to trigger
    await _localAlertService.startAlerts();

    // Get location immediately
    final position = await _getCurrentLocation();

    // Show confirmation dialog and handle response
    await _showFallConfirmationDialog(position, settings.emergencyMessage);
  }

  // Show fall confirmation dialog (this would be called through a callback to the UI)
  Future<void> _showFallConfirmationDialog(
    Position? position,
    String customMessage,
  ) async {
    // This method would typically trigger a UI callback
    // For now, we'll implement a timer-based approach

    debugPrint('Fall confirmation dialog would show here');

    // Wait for 30 seconds (simulating confirmation dialog timeout)
    bool userCancelled = false;

    // In a real implementation, this would be handled by the UI layer
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (timer.tick >= 30) {
        timer.cancel();
        if (!userCancelled) {
          await _proceedWithEmergencyResponse(position, customMessage);
        }
      }
    });

    // For demo purposes, we'll proceed immediately
    // In production, this would wait for user input
    await _proceedWithEmergencyResponse(position, customMessage);
  }

  /// Cancel alerts if the user indicates it was a false alarm
  Future<void> cancelFallAlert() async {
    // Cancel local alerts
    await _localAlertService.stopAllAlerts();

    // Cancel any emergency alerts in progress
    final emergencyService = EmergencyAlertService();
    await emergencyService.cancelEmergencyAlerts();

    debugPrint('Fall alert cancelled by user');
  }

  // Proceed with emergency response after confirmation or timeout
  Future<void> _proceedWithEmergencyResponse(
    Position? position,
    String customMessage,
  ) async {
    // Use the EmergencyAlertService to send alerts
    // Note: The EmergencyAlertService already starts local alerts as well
    final emergencyService = EmergencyAlertService();

    // Send SMS with custom message if available
    final success = await emergencyService.sendEmergencyAlerts(
      customMessage: customMessage,
    );

    if (success) {
      debugPrint('Emergency SMS sent successfully');
    } else {
      debugPrint('Failed to send emergency SMS or no contacts configured');
    }

    // Stop all local alerts (vibration, alarm, flashlight)
    await _localAlertService.stopAllAlerts();
  }
  // This method has been replaced by EmergencyAlertService.sendEmergencyAlerts
  // Note: These methods have been moved to LocalAlertService
  // to centralize alert management and optimize battery usage

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

  // Set sensor sampling rate for battery optimization
  void setSamplingRate(double samplingRateMs) {
    debugPrint('Setting sensor sampling rate to: ${samplingRateMs}ms');
    // Note: sensors_plus doesn't support changing sampling rate directly
    // This method is here for UI consistency and future implementation
    // In a real app, you might adjust the processing frequency instead
  }

  /// Test the alert system without actually detecting a fall
  /// This is useful for testing and debugging
  Future<void> testAlertSystem() async {
    debugPrint('Testing alert system');
    await _localAlertService.startAlerts();

    // Set a timer to stop all alerts after 5 seconds to avoid disruption
    Timer(const Duration(seconds: 5), () async {
      await _localAlertService.stopAllAlerts();
      debugPrint('Test alert stopped after 5 seconds');
    });
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
