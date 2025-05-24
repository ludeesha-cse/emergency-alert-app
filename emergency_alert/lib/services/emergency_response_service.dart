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
import 'alert_storage_service.dart';

class EmergencyResponseService {
  static final EmergencyResponseService _instance = EmergencyResponseService._internal();
  factory EmergencyResponseService() => _instance;
  EmergencyResponseService._internal();

  Timer? _emergencyCountdown;
  Alert? _currentAlert;
  bool _isEmergencyActive = false;

  // Stream controllers for emergency state
  final StreamController<Alert?> _currentAlertController = StreamController<Alert?>.broadcast();
  final StreamController<int> _countdownController = StreamController<int>.broadcast();
  final StreamController<bool> _emergencyActiveController = StreamController<bool>.broadcast();

  Stream<Alert?> get currentAlertStream => _currentAlertController.stream;
  Stream<int> get countdownStream => _countdownController.stream;
  Stream<bool> get emergencyActiveStream => _emergencyActiveController.stream;

  bool get isEmergencyActive => _isEmergencyActive;
  Alert? get currentAlert => _currentAlert;

  /// Trigger an emergency alert with countdown
  Future<void> triggerEmergency({
    required AlertType alertType,
    String? customMessage,
    AlertSeverity severity = AlertSeverity.high,
  }) async {
    if (_isEmergencyActive) {
      print('Emergency already active, ignoring trigger');
      return;
    }

    try {
      // Get emergency contacts
      final contacts = await _getEmergencyContacts();
      if (contacts.isEmpty) {
        print('No emergency contacts configured');
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
      
      _currentAlertController.add(alert);
      _emergencyActiveController.add(true);

      // Start immediate emergency response (audio, vibration, flashlight)
      await _startImmediateResponse();

      // Start countdown
      await _startCountdown(alert, contacts, location?.address);

    } catch (e) {
      print('Error triggering emergency: $e');
      await _cleanup();
    }
  }

  /// Cancel the current emergency
  Future<void> cancelEmergency() async {
    if (!_isEmergencyActive || _currentAlert == null) {
      return;
    }

    try {
      // Cancel countdown timer
      _emergencyCountdown?.cancel();

      // Stop all emergency responses
      await _stopEmergencyResponse();

      // Update alert status
      final cancelledAlert = _currentAlert!.copyWith(
        status: AlertStatus.cancelled,
        resolvedAt: DateTime.now(),
      );

      // Save to history
      await _saveAlertToHistory(cancelledAlert);

      // Send cancellation SMS if alert was already sent
      if (_currentAlert!.status == AlertStatus.sent) {
        await _sendCancellationSms(cancelledAlert);
      }

      await _cleanup();

      print('Emergency cancelled successfully');
    } catch (e) {
      print('Error cancelling emergency: $e');
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

      print('Emergency sent immediately');
    } catch (e) {
      print('Error sending emergency immediately: $e');
    }
  }

  /// Start immediate emergency response (audio, vibration, flashlight)
  Future<void> _startImmediateResponse() async {
    try {
      final audioService = AudioService();
      final flashlightService = FlashlightService();
      final vibrationService = VibrationService();

      // Start emergency alerts concurrently
      await Future.wait([
        audioService.playEmergencyAlarm(),
        vibrationService.vibrateEmergency(),
        flashlightService.startEmergencyFlashing(),
      ]);
    } catch (e) {
      print('Error starting immediate response: $e');
    }
  }

  /// Start countdown timer
  Future<void> _startCountdown(Alert alert, List<EmergencyContact> contacts, String? locationInfo) async {
    int remainingSeconds = AppConstants.alertCountdownSeconds;
    
    _emergencyCountdown = Timer.periodic(const Duration(seconds: 1), (timer) async {
      remainingSeconds--;
      _countdownController.add(remainingSeconds);

      if (remainingSeconds <= 0) {
        timer.cancel();
        
        // Send emergency alerts after countdown
        await _sendEmergencyAlerts(alert, contacts, locationInfo);
      }
    });
  }

  /// Send emergency alerts via SMS and update status
  Future<void> _sendEmergencyAlerts(Alert alert, List<EmergencyContact> contacts, String? locationInfo) async {
    try {
      final smsService = SmsService();

      // Send SMS alerts
      final success = await smsService.sendEmergencyAlert(
        contacts: contacts,
        alert: alert,
        locationInfo: locationInfo,
      );

      // Update alert status
      final updatedAlert = alert.copyWith(
        status: success ? AlertStatus.sent : AlertStatus.failed,
        sentToContacts: contacts.map((c) => c.id).toList(),
      );

      _currentAlert = updatedAlert;
      _currentAlertController.add(updatedAlert);

      // Save to history
      await _saveAlertToHistory(updatedAlert);

      // Keep emergency response active for a while even after sending
      Future.delayed(const Duration(minutes: 2), () async {
        await _cleanup();
      });

    } catch (e) {
      print('Error sending emergency alerts: $e');
      
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
      print('Error sending cancellation SMS: $e');
    }
  }

  /// Stop all emergency responses
  Future<void> _stopEmergencyResponse() async {
    try {
      final audioService = AudioService();
      final flashlightService = FlashlightService();
      final vibrationService = VibrationService();

      await Future.wait([
        audioService.stopAlarm(),
        flashlightService.stopFlashing(),
        vibrationService.stopVibration(),
      ]);
    } catch (e) {
      print('Error stopping emergency response: $e');
    }
  }

  /// Get emergency contacts from storage
  Future<List<EmergencyContact>> _getEmergencyContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contactsJson = prefs.getStringList(AppConstants.keyEmergencyContacts) ?? [];
      
      return contactsJson
          .map((json) => EmergencyContact.fromJson(jsonDecode(json)))
          .toList();
    } catch (e) {
      print('Error getting emergency contacts: $e');
      return [];
    }
  }

  /// Save alert to history
  Future<void> _saveAlertToHistory(Alert alert) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList(AppConstants.keyAlertHistory) ?? [];

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
