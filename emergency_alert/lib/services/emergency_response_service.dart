import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alert.dart';
import '../models/contact.dart';
import '../utils/constants.dart';
import 'audio/audio_service.dart';
import 'flashlight/flashlight_service.dart';
import 'vibration/vibration_service.dart';
import 'sms/sms_service.dart';
import 'location/location_service.dart';
import 'logger/logger_service.dart';
import 'background/background_service.dart';
import 'emergency_state_manager.dart';

class EmergencyResponseService {
  static final EmergencyResponseService _instance =
      EmergencyResponseService._internal();
  factory EmergencyResponseService() => _instance;
  EmergencyResponseService._internal();
  Timer? _emergencyCountdown;
  Alert? _currentAlert;
  Alert? _lastSentAlert;
  bool _isEmergencyActive = false;

  // Stream controllers for emergency state
  final StreamController<Alert?> _currentAlertController =
      StreamController<Alert?>.broadcast();
  final StreamController<int> _countdownController =
      StreamController<int>.broadcast();
  final StreamController<bool> _emergencyActiveController =
      StreamController<bool>.broadcast();

  Stream<Alert?> get currentAlertStream => _currentAlertController.stream;
  Stream<int> get countdownStream => _countdownController.stream;
  Stream<bool> get emergencyActiveStream => _emergencyActiveController.stream;
  bool get isEmergencyActive => _isEmergencyActive;
  Alert? get currentAlert => _currentAlert;

  /// Check if cancellation is allowed (within 10 minutes of last sent alert OR if emergency is currently active)
  bool get isCancellationAllowed {
    // Allow cancellation if there's currently an active emergency
    if (_isEmergencyActive && _currentAlert != null) {
      return true;
    }

    // Allow cancellation if there's a recent sent alert within 10 minutes
    if (_lastSentAlert == null) return false;

    final now = DateTime.now();
    final timeDifference = now.difference(_lastSentAlert!.timestamp);

    return timeDifference.inMinutes <= 10 &&
        _lastSentAlert!.status == AlertStatus.sent;
  }

  /// Get time remaining for cancellation (in minutes)
  int? get cancellationTimeRemaining {
    if (_lastSentAlert == null) return null;

    final now = DateTime.now();
    final timeDifference = now.difference(_lastSentAlert!.timestamp);
    final remaining = 10 - timeDifference.inMinutes;

    return remaining > 0 ? remaining : null;
  }

  /// Trigger an emergency alert with countdown
  Future<void> triggerEmergency({
    required AlertType alertType,
    String? customMessage,
    AlertSeverity severity = AlertSeverity.high,
  }) async {
    if (_isEmergencyActive) {
      LoggerService.warning('Emergency already active, ignoring trigger');
      return;
    }

    // Check global emergency state
    if (EmergencyStateManager.isGlobalEmergencyActive) {
      LoggerService.warning('Global emergency active, ignoring trigger');
      return;
    }

    // Check if emergency was recently cancelled
    if (EmergencyStateManager.isEmergencyCancelled) {
      LoggerService.warning('Emergency recently cancelled, ignoring trigger');
      return;
    }

    try {
      // Reset any emergency detection cooldown for manual triggers
      if (alertType == AlertType.manual) {
        BackgroundService.resetCooldown();
        EmergencyStateManager.resetState(); // Reset state for manual trigger
      }

      // Get emergency contacts
      final contacts = await _getEmergencyContacts();
      if (contacts.isEmpty) {
        LoggerService.warning('No emergency contacts configured');
        return;
      }

      // Get current location
      final locationService = LocationService();
      final location = await locationService.getLocationWithAddress();

      // Create alert
      final alert = Alert(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: alertType,
        severity: severity,
        status: AlertStatus.triggered,
        timestamp: DateTime.now(),
        customMessage: customMessage,
        latitude: location?.latitude,
        longitude: location?.longitude,
        address: location?.address,
      );

      _currentAlert = alert;
      _isEmergencyActive = true;

      // Mark emergency as active in global state
      EmergencyStateManager.startEmergency(alert.id);

      _currentAlertController.add(alert);
      _emergencyActiveController.add(true);

      // Start immediate emergency response (audio, vibration, flashlight)
      await _startImmediateResponse();

      // Start countdown
      await _startCountdown(alert, contacts, location?.address);
    } catch (e) {
      LoggerService.error('Error triggering emergency: $e');
      await _cleanup();
    }
  }

  /// Cancel the current emergency
  Future<void> cancelEmergency({bool sendCancellationMessage = false}) async {
    if (!_isEmergencyActive || _currentAlert == null) {
      return;
    }

    try {
      LoggerService.info('Cancelling emergency with state synchronization');

      // STEP 1: Mark emergency as cancelled in global state FIRST
      EmergencyStateManager.cancelEmergency(_currentAlert!.id);

      // STEP 2: Immediately mark emergency as inactive and cancel countdown
      _isEmergencyActive = false;
      _emergencyActiveController.add(false);
      _emergencyCountdown?.cancel();

      // STEP 3: Stop emergency responses FIRST - this is critical
      await _stopEmergencyResponse();

      // STEP 4: Cancel background emergency responses and wait for complete stop
      await BackgroundService.cancelBackgroundEmergency();

      // STEP 5: Wait a moment to ensure background service has fully stopped
      await Future.delayed(const Duration(milliseconds: 200));

      // STEP 6: Update alert status
      final cancelledAlert = _currentAlert!.copyWith(
        status: AlertStatus.cancelled,
        resolvedAt: DateTime.now(),
      );

      // STEP 7: Save to history
      await _saveAlertToHistory(cancelledAlert);

      // STEP 8: Send cancellation SMS only if explicitly requested
      if (sendCancellationMessage &&
          _currentAlert!.status == AlertStatus.sent) {
        await _sendCancellationSms(cancelledAlert);
      }

      // STEP 9: Final cleanup
      await _cleanup();

      LoggerService.info(
        'Emergency cancelled successfully with state synchronization',
      );
    } catch (e) {
      LoggerService.error('Error cancelling emergency: $e');
      // Even if there's an error, ensure we mark as inactive
      _isEmergencyActive = false;
      _emergencyActiveController.add(false);
      if (_currentAlert != null) {
        EmergencyStateManager.cancelEmergency(_currentAlert!.id);
      }
    }
  }

  /// Send emergency alert immediately (skip countdown)
  Future<void> sendEmergencyImmediately() async {
    if (!_isEmergencyActive || _currentAlert == null) {
      return;
    }

    try {
      // Cancel countdown timer
      _emergencyCountdown?.cancel();

      // Get emergency contacts
      final contacts = await _getEmergencyContacts();
      final locationService = LocationService();
      final location = await locationService.getLocationWithAddress();

      // Send emergency alerts
      await _sendEmergencyAlerts(_currentAlert!, contacts, location?.address);

      LoggerService.info('Emergency sent immediately');
    } catch (e) {
      LoggerService.error('Error sending emergency immediately: $e');
    }
  }

  /// Start immediate emergency response (audio, vibration, flashlight)
  Future<void> _startImmediateResponse() async {
    try {
      // Check settings to see which services are enabled
      final prefs = await SharedPreferences.getInstance();
      final audioEnabled = prefs.getBool('audio_alerts_enabled') ?? true;
      final vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
      final flashlightEnabled = prefs.getBool('flashlight_enabled') ?? true;

      final futures = <Future>[];

      // Only start enabled services
      if (audioEnabled) {
        final audioService = AudioService();
        futures.add(audioService.playEmergencyAlarm());
      }

      if (vibrationEnabled) {
        final vibrationService = VibrationService();
        futures.add(vibrationService.vibrateEmergency());
      }

      if (flashlightEnabled) {
        final flashlightService = FlashlightService();
        futures.add(flashlightService.startEmergencyFlashing());
      }

      // Start enabled emergency alerts concurrently
      if (futures.isNotEmpty) {
        await Future.wait(futures);
      }

      LoggerService.info(
        'Started emergency response - Audio: $audioEnabled, Vibration: $vibrationEnabled, Flashlight: $flashlightEnabled',
      );
    } catch (e) {
      LoggerService.error('Error starting immediate response: $e');
    }
  }

  /// Start countdown timer
  Future<void> _startCountdown(
    Alert alert,
    List<EmergencyContact> contacts,
    String? locationInfo,
  ) async {
    int remainingSeconds = AppConstants.alertCountdownSeconds;

    // Emit initial countdown value immediately
    _countdownController.add(remainingSeconds);
    _emergencyCountdown = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) async {
      // Check if emergency is still active (not cancelled)
      if (!_isEmergencyActive) {
        timer.cancel();
        return;
      }

      remainingSeconds--;

      if (remainingSeconds <= 0) {
        timer.cancel();
        _countdownController.add(0);

        // Double-check emergency is still active before sending
        if (_isEmergencyActive && _currentAlert != null) {
          // Send emergency alerts after countdown
          await _sendEmergencyAlerts(alert, contacts, locationInfo);
        }
      } else {
        _countdownController.add(remainingSeconds);
      }
    });
  }

  /// Send emergency alerts via SMS and update status
  Future<void> _sendEmergencyAlerts(
    Alert alert,
    List<EmergencyContact> contacts,
    String? locationInfo,
  ) async {
    try {
      final smsService = SmsService();

      // Send SMS alerts
      final success = await smsService.sendEmergencyAlert(
        contacts: contacts,
        alert: alert,
        locationInfo: locationInfo,
      ); // Update alert status
      final updatedAlert = alert.copyWith(
        status: success ? AlertStatus.sent : AlertStatus.failed,
        sentToContacts: contacts.map((c) => c.id).toList(),
      );

      _currentAlert = updatedAlert;
      _currentAlertController.add(updatedAlert);

      // Store last sent alert for cancellation tracking
      if (success) {
        _lastSentAlert = updatedAlert;
      }

      // Save to history
      await _saveAlertToHistory(updatedAlert);

      // Keep emergency response active for a while even after sending
      Future.delayed(const Duration(minutes: 2), () async {
        await _cleanup();
      });
    } catch (e) {
      LoggerService.error('Error sending emergency alerts: $e');

      // Mark as failed
      final failedAlert = alert.copyWith(status: AlertStatus.failed);
      _currentAlert = failedAlert;
      _currentAlertController.add(failedAlert);
      await _saveAlertToHistory(failedAlert);
    }
  }

  /// Send cancellation SMS to contacts
  Future<void> _sendCancellationSms(Alert alert) async {
    try {
      final contacts = await _getEmergencyContacts();
      final smsService = SmsService();

      await smsService.sendCancellationMessage(
        contacts: contacts,
        alert: alert,
      );
    } catch (e) {
      LoggerService.error('Error sending cancellation SMS: $e');
    }
  }

  /// Send manual cancellation message for previous alert
  Future<bool> sendManualCancellationMessage() async {
    // Check if cancellation is allowed
    if (!isCancellationAllowed) {
      LoggerService.warning(
        'Cancellation not allowed - no recent alert or outside 10-minute window',
      );
      return false;
    }

    try {
      final contacts = await _getEmergencyContacts();
      if (contacts.isEmpty) {
        LoggerService.warning('No emergency contacts configured');
        return false;
      }

      // IMPORTANT: Stop any ongoing emergency responses first
      // This ensures that if there are still active alarms/vibrations/flashlight
      // from the previous alert, they get stopped when user cancels
      await _stopEmergencyResponse();
      await BackgroundService.cancelBackgroundEmergency();

      // If there's an active emergency, mark it as cancelled
      if (_isEmergencyActive && _currentAlert != null) {
        _isEmergencyActive = false;
        _emergencyActiveController.add(false);
        _emergencyCountdown?.cancel();

        final cancelledAlert = _currentAlert!.copyWith(
          status: AlertStatus.cancelled,
          resolvedAt: DateTime.now(),
        );
        _currentAlert = cancelledAlert;
        _currentAlertController.add(cancelledAlert);
        await _saveAlertToHistory(cancelledAlert);
      }

      final smsService = SmsService();

      // Use the last sent alert for cancellation (or current alert if active)
      final alertToCancel = _currentAlert ?? _lastSentAlert!;
      await smsService.sendCancellationMessage(
        contacts: contacts,
        alert: alertToCancel,
      );

      // Update the alert status to cancelled
      if (_lastSentAlert != null) {
        _lastSentAlert = _lastSentAlert!.copyWith(
          status: AlertStatus.cancelled,
          resolvedAt: DateTime.now(),
        );
        await _saveAlertToHistory(_lastSentAlert!);
      }

      LoggerService.info(
        'Manual cancellation message sent successfully and emergency responses stopped',
      );
      return true;
    } catch (e) {
      LoggerService.error('Error sending manual cancellation SMS: $e');
      return false;
    }
  }

  /// Stop all emergency responses - both local and background services
  Future<void> _stopEmergencyResponse() async {
    try {
      LoggerService.info('Stopping emergency responses');

      final audioService = AudioService();
      final flashlightService = FlashlightService();
      final vibrationService = VibrationService();

      await Future.wait([
        audioService.stopAlarm(),
        flashlightService.stopFlashing(),
        vibrationService.stopVibration(),
      ]);

      LoggerService.info('Emergency responses stopped');
    } catch (e) {
      LoggerService.error('Error stopping emergency response: $e');
    }
  }

  /// Get emergency contacts from storage
  Future<List<EmergencyContact>> _getEmergencyContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contactsJson =
          prefs.getStringList(AppConstants.keyEmergencyContacts) ?? [];

      return contactsJson
          .map((json) => EmergencyContact.fromJson(jsonDecode(json)))
          .toList();
    } catch (e) {
      LoggerService.error('Error getting emergency contacts: $e');
      return [];
    }
  }

  /// Save alert to history
  Future<void> _saveAlertToHistory(Alert alert) async {
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

  /// Clean up emergency state
  Future<void> _cleanup() async {
    _emergencyCountdown?.cancel();
    _emergencyCountdown = null;
    _currentAlert = null;
    _isEmergencyActive = false;

    _currentAlertController.add(null);
    _emergencyActiveController.add(false);
    _countdownController.add(0);

    // Stop all emergency responses
    await _stopEmergencyResponse();
  }

  /// Manual emergency trigger (for emergency button)
  Future<void> triggerManualEmergency() async {
    await triggerEmergency(
      alertType: AlertType.manual,
      customMessage: 'Manual emergency button pressed',
      severity: AlertSeverity.critical,
    );
  }

  /// Dispose service and clean up
  void dispose() {
    _emergencyCountdown?.cancel();
    _currentAlertController.close();
    _countdownController.close();
    _emergencyActiveController.close();
  }
}
