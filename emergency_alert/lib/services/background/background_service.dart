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
import '../logger/logger_service.dart';
import '../emergency_state_manager.dart';
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

  bool _isRunning = false;
  bool get isRunning => _isRunning;
  // Track active emergency responses to allow cancellation
  static bool _isEmergencyResponseActive = false;
  static Timer? _emergencyResponseTimer;

  // Cooldown mechanism to prevent immediate re-triggering after cancellation
  static DateTime? _lastCancellationTime;
  static const int _cooldownMinutes = 5; // 5-minute cooldown period
  @pragma('vm:entry-point')
  BackgroundService._internal();

  /// Cancel any active background emergency response
  static Future<void> cancelBackgroundEmergency() async {
    try {
      LoggerService.info(
        'Cancelling background emergency response with state coordination',
      );

      // Cancel timer first to prevent any SMS sending
      if (_emergencyResponseTimer != null) {
        _emergencyResponseTimer!.cancel();
        _emergencyResponseTimer = null;
      }

      // Mark as inactive immediately
      _isEmergencyResponseActive = false;

      // Set cooldown time to prevent immediate re-triggering
      _lastCancellationTime = DateTime.now();

      // Cancel emergency in global state manager
      EmergencyStateManager.cancelEmergency('background');

      // Stop all emergency alerts
      await Future.wait([
        AudioService().stopAlarm(),
        VibrationService().stopVibration(),
        FlashlightService().stopFlashing(),
      ]);

      LoggerService.info(
        'Background emergency response cancelled successfully with state coordination',
      );
    } catch (e) {
      LoggerService.error('Error stopping background emergency alerts: $e');
      // Ensure we still mark as inactive and start cooldown even if stopping fails
      _isEmergencyResponseActive = false;
      _lastCancellationTime = DateTime.now();
      EmergencyStateManager.cancelEmergency('background');
    }
  }

  /// Check if background emergency response is active
  static bool get isBackgroundEmergencyActive => _isEmergencyResponseActive;

  /// Check if emergency detection is currently in cooldown period
  static bool get isInCooldownPeriod => _isInCooldownPeriod();

  /// Get remaining cooldown time in minutes (for debugging/UI display)
  static int get cooldownTimeRemainingMinutes {
    if (_lastCancellationTime == null) return 0;

    final now = DateTime.now();
    final timeSinceCancellation = now.difference(_lastCancellationTime!);
    final remaining = _cooldownMinutes - timeSinceCancellation.inMinutes;

    return remaining > 0 ? remaining : 0;
  }

  /// Check if we're in cooldown period after cancellation
  static bool _isInCooldownPeriod() {
    if (_lastCancellationTime == null) return false;

    final now = DateTime.now();
    final timeSinceCancellation = now.difference(_lastCancellationTime!);

    return timeSinceCancellation.inMinutes < _cooldownMinutes;
  }

  /// Reset cooldown period (for manual emergency triggers)
  static void resetCooldown() {
    _lastCancellationTime = null;
    LoggerService.info('Emergency detection cooldown reset');
  }

  Future<void> initialize() async {
    // Initialize the notification helper first
    LoggerService.info('Initializing background service');
    await NotificationHelper().initialize();
    await _initializeFlutterBackgroundService();
  }

  Future<void> _initializeFlutterBackgroundService() async {
    final service = FlutterBackgroundService();
    LoggerService.debug('Configuring background service');
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
      LoggerService.info('Starting background service...');
      final service = FlutterBackgroundService();
      await service.startService();
      LoggerService.info('Background service started successfully');

      // Instead, we'll use a Timer for periodic background checks
      Timer.periodic(
        Duration(minutes: AppConstants.backgroundServiceInterval),
        (_) => _performBackgroundCheck(),
      );

      _isRunning = true;
      LoggerService.info('Background service is now running');
    } catch (e) {
      LoggerService.error('Error starting background service: $e');
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
      LoggerService.error('Error stopping background service: $e');
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
        LoggerService.info('Setting up foreground service notification...');

        // First set up a notification channel and show a notification
        final notificationHelper = NotificationHelper();
        await notificationHelper.showForegroundServiceNotification(
          id: 888,
          title: "Emergency Alert Active",
          body: "Monitoring for emergencies",
        );
        LoggerService.info('Foreground notification created');

        // Then switch to foreground mode
        await service.setAsForegroundService();
        LoggerService.info('Service set as foreground service');

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
            LoggerService.error('Error updating notification: $e');
          }
        });
      } catch (e) {
        LoggerService.error('Error setting up foreground service: $e');
        LoggerService.error('Stack trace: ${StackTrace.current}');
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

      // Check global emergency state - if emergency is active or recently cancelled, ignore
      if (EmergencyStateManager.isGlobalEmergencyActive) {
        LoggerService.info(
          'Emergency already active globally, ignoring background detection',
        );
        return;
      }

      if (EmergencyStateManager.isEmergencyCancelled) {
        LoggerService.info(
          'Emergency recently cancelled, ignoring background detection',
        );
        return;
      }

      // Check if we're in cooldown period after recent cancellation
      if (_isInCooldownPeriod()) {
        final timeRemaining =
            _cooldownMinutes -
            DateTime.now().difference(_lastCancellationTime!).inMinutes;
        LoggerService.info(
          'Emergency detection blocked - in cooldown period ($timeRemaining minutes remaining)',
        );
        return;
      }

      // Check if enough time has passed since last cancellation for state manager
      if (!EmergencyStateManager.canStartNewEmergency()) {
        final timeSince = EmergencyStateManager.getTimeSinceCancellation();
        LoggerService.info(
          'Emergency detection blocked - state manager cooldown ($timeSince seconds since cancellation)',
        );
        return;
      }

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

      // Mark emergency as active in global state before starting response
      EmergencyStateManager.startEmergency(alert.id);

      // Save alert to history
      await _saveAlertToHistory(alert);

      // Start countdown and emergency response
      await _startEmergencyResponse(alert, contacts, location?.address);
    } catch (e) {
      LoggerService.error('Error handling emergency: $e');
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
      LoggerService.error('Error saving alert to history: $e');
    }
  }

  static Future<void> _startEmergencyResponse(
    Alert alert,
    List<EmergencyContact> contacts,
    String? locationInfo,
  ) async {
    try {
      // Mark emergency response as active
      _isEmergencyResponseActive = true;

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

      // Use a cancellable timer instead of Future.delayed
      _emergencyResponseTimer = Timer(
        Duration(seconds: AppConstants.alertCountdownSeconds),
        () async {
          // Only proceed if emergency response is still active
          if (_isEmergencyResponseActive) {
            try {
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

              // Clean up after sending
              _isEmergencyResponseActive = false;
              _emergencyResponseTimer = null;
            } catch (e) {
              LoggerService.error('Error sending background emergency SMS: $e');
              _isEmergencyResponseActive = false;
              _emergencyResponseTimer = null;
            }
          }
        },
      );
    } catch (e) {
      LoggerService.error('Error in emergency response: $e');
      _isEmergencyResponseActive = false;
      _emergencyResponseTimer = null;
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
