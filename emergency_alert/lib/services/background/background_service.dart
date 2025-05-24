import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../sensor/sensor_service.dart';
import '../location/location_service.dart';
import '../sms/sms_service.dart';
import '../audio/audio_service.dart';
import '../flashlight/flashlight_service.dart';
import '../vibration/vibration_service.dart';
import '../notification/notification_helper.dart';
import '../../models/alert.dart';
import '../../models/contact.dart';
import '../../utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// Entry point annotation required for AOT compilation
@pragma('vm:entry-point')
class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;

  @pragma('vm:entry-point')
  BackgroundService._internal();

  bool _isRunning = false;
  bool get isRunning => _isRunning;
  Future<void> initialize() async {
    // Initialize the notification helper first
    await NotificationHelper().initialize();
    await _initializeFlutterBackgroundService();
  }

  Future<void> _initializeFlutterBackgroundService() async {
    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false, // Changed to false to manually control start
        isForegroundMode: true,
        notificationChannelId:
            AppConstants.backgroundServiceNotificationChannelId,
        initialNotificationTitle: 'Emergency Alert',
        initialNotificationContent: 'Monitoring for emergencies',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  Future<void> startService() async {
    if (_isRunning) return;

    try {
      print('Starting background service...');
      final service = FlutterBackgroundService();
      await service.startService();
      print('Background service started successfully');

      // Instead, we'll use a Timer for periodic background checks
      Timer.periodic(
        Duration(minutes: AppConstants.backgroundServiceInterval),
        (_) => _performBackgroundCheck(),
      );

      _isRunning = true;
      print('Background service is now running');
    } catch (e) {
      print('Error starting background service: $e');
      _isRunning = false;
      rethrow;
    }
  }

  Future<void> stopService() async {
    if (!_isRunning) return;
    try {
      final service = FlutterBackgroundService();
      service.invoke('stop');

      _isRunning = false;
    } catch (e) {
      print('Error stopping background service: $e');
    }
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    final sensorService = SensorService();
    final locationService = LocationService();
    // Initialize services that might be used later in listeners
    SmsService();
    AudioService();
    FlashlightService();
    VibrationService();

    // Start monitoring services
    await sensorService.startMonitoring();
    await locationService.startTracking();

    // Listen for emergency events
    sensorService.fallDetectedStream.listen((detected) async {
      if (detected) {
        await _handleEmergencyDetected(AlertType.fall);
      }
    });

    sensorService.impactDetectedStream.listen((detected) async {
      if (detected) {
        await _handleEmergencyDetected(AlertType.impact);
      }
    }); // Set up proper notification for foreground service
    if (service is AndroidServiceInstance) {
      try {
        print('Setting up foreground service notification...');

        // First set up a notification channel and show a notification
        final notificationHelper = NotificationHelper();
        await notificationHelper.showForegroundServiceNotification(
          id: 888,
          title: "Emergency Alert Active",
          body: "Monitoring for emergencies",
        );
        print('Foreground notification created');

        // Then switch to foreground mode
        await service.setAsForegroundService();
        print('Service set as foreground service');

        // Update notification periodically
        Timer.periodic(Duration(seconds: 30), (timer) async {
          try {
            final timeString = DateTime.now().toString().substring(11, 19);
            await notificationHelper.updateForegroundServiceNotification(
              id: 888,
              title: "Emergency Alert Active",
              body: "Last check: $timeString",
            );
          } catch (e) {
            print('Error updating notification: $e');
          }
        });
      } catch (e) {
        print('Error setting up foreground service: $e');
        print('Stack trace: ${StackTrace.current}');
      }
    }

    service.on('stop').listen((event) {
      sensorService.stopMonitoring();
      locationService.stopTracking();
      service.stopSelf();
    });

    // Add periodic background check
    Timer.periodic(Duration(minutes: 15), (_) async {
      await _performBackgroundCheck();
    });
  }

  static Future<void> _handleEmergencyDetected(AlertType alertType) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if app is enabled
      final isEnabled = prefs.getBool(AppConstants.keyAppEnabled) ?? true;
      if (!isEnabled) return;

      // Get emergency contacts
      final contactsJson =
          prefs.getStringList(AppConstants.keyEmergencyContacts) ?? [];
      final contacts = contactsJson
          .map((json) => EmergencyContact.fromJson(jsonDecode(json)))
          .toList();

      if (contacts.isEmpty) return;

      // Get current location
      final locationService = LocationService();
      final location = await locationService.getLocationWithAddress();

      // Create alert
      final alert = Alert(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: alertType,
        severity: AlertSeverity.high,
        status: AlertStatus.triggered,
        timestamp: DateTime.now(),
        latitude: location?.latitude,
        longitude: location?.longitude,
        address: location?.address,
        sensorData: SensorService().getCurrentSensorData()?.toJson(),
      );

      // Save alert to history
      await _saveAlertToHistory(alert);

      // Start countdown and emergency response
      await _startEmergencyResponse(alert, contacts, location?.address);
    } catch (e) {
      print('Error handling emergency: $e');
    }
  }

  static Future<void> _saveAlertToHistory(Alert alert) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson =
          prefs.getStringList(AppConstants.keyAlertHistory) ?? [];

      historyJson.add(jsonEncode(alert.toJson()));

      // Keep only last 100 alerts
      if (historyJson.length > 100) {
        historyJson.removeAt(0);
      }

      await prefs.setStringList(AppConstants.keyAlertHistory, historyJson);
    } catch (e) {
      print('Error saving alert to history: $e');
    }
  }

  static Future<void> _startEmergencyResponse(
    Alert alert,
    List<EmergencyContact> contacts,
    String? locationInfo,
  ) async {
    try {
      final audioService = AudioService();
      final flashlightService = FlashlightService();
      final vibrationService = VibrationService();
      final smsService = SmsService();

      // Start emergency alerts (audio, vibration, flashlight)
      await Future.wait([
        audioService.playEmergencyAlarm(),
        vibrationService.vibrateEmergency(),
        flashlightService.startEmergencyFlashing(),
      ]);

      // Wait for countdown period
      await Future.delayed(
        Duration(seconds: AppConstants.alertCountdownSeconds),
      );

      // Send SMS alerts
      await smsService.sendEmergencyAlert(
        contacts: contacts,
        alert: alert,
        locationInfo: locationInfo,
      );

      // Update alert status
      final updatedAlert = alert.copyWith(
        status: AlertStatus.sent,
        sentToContacts: contacts.map((c) => c.id).toList(),
      );

      await _saveAlertToHistory(updatedAlert);
    } catch (e) {
      print('Error in emergency response: $e');
    }
  }

  static Future<void> _performBackgroundCheck() async {
    // Check if app is still responsive
    // Perform health checks
    // Update location if needed
    // Check for inactivity alerts

    final prefs = await SharedPreferences.getInstance();
    final lastCheckIn = prefs.getInt('last_check_in') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Check for inactivity (if enabled)
    final inactivityEnabled =
        prefs.getBool('inactivity_detection_enabled') ?? false;
    if (inactivityEnabled) {
      final hoursSinceCheckIn = (now - lastCheckIn) / (1000 * 60 * 60);

      if (hoursSinceCheckIn > AppConstants.inactivityThresholdHours) {
        // Trigger inactivity alert
        await _handleEmergencyDetected(AlertType.inactivity);
      }
    }
  }
}
