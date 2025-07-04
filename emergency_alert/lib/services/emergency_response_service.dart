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

class EmergencyResponseService {
  static final EmergencyResponseService _instance =
      EmergencyResponseService._internal();
  factory EmergencyResponseService() => _instance;
  EmergencyResponseService._internal();

  Timer? _emergencyCountdown;
  Alert? _currentAlert;
  bool _isEmergencyActive = false;

  // Service instances for proper cleanup
  final AudioService _audioService = AudioService();
  final FlashlightService _flashlightService = FlashlightService();
  final VibrationService _vibrationService = VibrationService();

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

    try {
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
  Future<void> cancelEmergency() async {
    if (!_isEmergencyActive || _currentAlert == null) {
      return;
    }

    try {
      LoggerService.info('Emergency cancelled by user');

      // Cancel countdown timer immediately
      _emergencyCountdown?.cancel();

      // Stop all emergency responses immediately
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

      LoggerService.info(
        'Emergency cancelled successfully - all alerts stopped',
      );
    } catch (e) {
      LoggerService.error('Error cancelling emergency: $e');
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
      LoggerService.info('Starting immediate emergency response...');

      // Start each service and wait for them to actually start
      // This ensures they're properly initialized before we can stop them
      final List<Future> serviceFutures = [];

      serviceFutures.add(
        _audioService.playEmergencyAlarm().catchError((e) {
          LoggerService.error('Audio service error: $e');
        }),
      );

      serviceFutures.add(
        _vibrationService.vibrateEmergency().catchError((e) {
          LoggerService.error('Vibration service error: $e');
        }),
      );

      serviceFutures.add(
        _flashlightService.startEmergencyFlashing().catchError((e) {
          LoggerService.error('Flashlight service error: $e');
        }),
      );

      // Wait for all services to start (with timeout)
      await Future.wait(serviceFutures).timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          LoggerService.warning('Service startup timeout - continuing anyway');
          return <dynamic>[];
        },
      );

      LoggerService.info('Emergency response services started');
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

    _emergencyCountdown = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) async {
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

  /// Stop all emergency responses
  Future<void> _stopEmergencyResponse() async {
    try {
      LoggerService.info('Stopping all emergency responses...');

      await Future.wait([
        _audioService.stopAlarm(),
        _flashlightService.stopFlashing(),
        _vibrationService.stopVibration(),
      ]);

      // Double-check audio stopped, use emergency reset if needed
      await Future.delayed(const Duration(milliseconds: 100));
      if (_audioService.isPlaying) {
        LoggerService.warning(
          'Audio still playing after stop - using emergency reset',
        );
        await _audioService.emergencyReset();
      }

      LoggerService.info('All emergency responses stopped');
    } catch (e) {
      LoggerService.error('Error stopping emergency response: $e');
      // Emergency fallback
      try {
        await _audioService.emergencyReset();
        LoggerService.info('Emergency reset completed as fallback');
      } catch (resetError) {
        LoggerService.error('Emergency reset also failed: $resetError');
      }
    }
  }

  /// Stop only local alerts (audio, vibration, flashlight) without canceling emergency
  Future<void> stopLocalAlerts() async {
    try {
      LoggerService.info('🚫 Stopping local alerts only...');

      // Check initial states
      LoggerService.debug('Audio playing: ${_audioService.isPlaying}');
      LoggerService.debug('Vibration active: ${_vibrationService.isVibrating}');
      LoggerService.debug(
        'Flashlight active: ${_flashlightService.isFlashing}',
      );

      // FIRST: Perform an emergency audio reset immediately
      // This ensures any current audio is silenced right away
      await _audioService.emergencyReset().timeout(
        const Duration(seconds: 1),
        onTimeout: () {
          LoggerService.warning('Audio emergency reset timed out');
          return;
        },
      );

      // SECOND: Stop all other alerts in parallel
      final stopFutures = [
        _flashlightService.stopFlashing(),
        _vibrationService.stopVibration(),
      ];

      await Future.wait(stopFutures).timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          LoggerService.warning('Normal stop timeout for non-audio services');
          return <dynamic>[];
        },
      );

      // THIRD: Wait a moment and verify services actually stopped
      await Future.delayed(const Duration(milliseconds: 100));

      // Check states after stop attempt
      bool audioStillPlaying = _audioService.isPlaying;
      bool vibrationStillActive = _vibrationService.isVibrating;
      bool flashlightStillActive = _flashlightService.isFlashing;

      LoggerService.debug(
        'After stop - Audio: $audioStillPlaying, Vibration: $vibrationStillActive, Flashlight: $flashlightStillActive',
      );

      // FOURTH: Do another round of emergency resets for any service still active
      List<Future> secondaryStopFutures = [];

      // Always do another audio emergency reset regardless of reported state
      LoggerService.info(
        'Performing secondary audio emergency reset for certainty',
      );
      secondaryStopFutures.add(_audioService.emergencyReset());

      if (vibrationStillActive) {
        LoggerService.warning('Vibration still active - force stopping');
        secondaryStopFutures.add(_vibrationService.stopVibration());
      }

      if (flashlightStillActive) {
        LoggerService.warning('Flashlight still active - force stopping');
        secondaryStopFutures.add(_flashlightService.stopFlashing());
      }

      // Execute secondary stops
      await Future.wait(secondaryStopFutures).timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          LoggerService.warning('Secondary stops timed out');
          return <dynamic>[];
        },
      );

      // FIFTH: Verify final state
      await Future.delayed(const Duration(milliseconds: 200));

      // Final state check
      final finalAudioState = _audioService.isPlaying;
      final finalVibrationState = _vibrationService.isVibrating;
      final finalFlashlightState = _flashlightService.isFlashing;

      LoggerService.debug(
        'FINAL STATE - Audio: $finalAudioState, Vibration: $finalVibrationState, Flashlight: $finalFlashlightState',
      );

      if (finalAudioState || finalVibrationState || finalFlashlightState) {
        LoggerService.warning(
          'Some alerts still active after multiple stop attempts',
        );
        // One final attempt at stopping everything
        await Future.wait([
          _audioService.emergencyReset(),
          _vibrationService.stopVibration(),
          _flashlightService.stopFlashing(),
        ]);
      }

      LoggerService.info(
        '✅ Local alerts stopped - emergency countdown continues',
      );
    } catch (e) {
      LoggerService.error('❌ Error stopping local alerts: $e');
      // As a last resort, try emergency reset for all services
      try {
        LoggerService.warning(
          '🧨 Using nuclear option - emergency reset all services',
        );
        await Future.wait([
          _audioService.emergencyReset(),
          _vibrationService.stopVibration(),
          _flashlightService.stopFlashing(),
        ]);
        LoggerService.info('✅ Emergency reset completed as fallback');
      } catch (resetError) {
        LoggerService.error('❌ Emergency reset also failed: $resetError');
      }
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

  /// Immediate manual emergency trigger (for panic button - starts local alerts immediately)
  Future<void> triggerImmediateManualEmergency() async {
    if (_isEmergencyActive) {
      LoggerService.warning('Emergency already active, ignoring trigger');
      return;
    }

    try {
      LoggerService.info(
        'Panic button triggered - starting immediate response',
      );

      // Create a temporary alert immediately for immediate response
      final tempAlert = Alert(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: AlertType.manual,
        severity: AlertSeverity.critical,
        status: AlertStatus.triggered,
        timestamp: DateTime.now(),
        customMessage: 'Panic button pressed - immediate assistance needed',
      );

      _currentAlert = tempAlert;
      _isEmergencyActive = true;

      // Immediately broadcast the emergency state and start countdown
      _currentAlertController.add(tempAlert);
      _emergencyActiveController.add(true);
      _countdownController.add(AppConstants.alertCountdownSeconds);

      // Start immediate emergency response (audio, vibration, flashlight) FIRST
      await _startImmediateResponse();

      // Now get contacts and location in background (this can take time)
      _handleBackgroundDataGathering(tempAlert);
    } catch (e) {
      LoggerService.error('Error triggering immediate manual emergency: $e');
      await _cleanup();
    }
  }

  /// Handle background data gathering for immediate emergency
  Future<void> _handleBackgroundDataGathering(Alert tempAlert) async {
    try {
      // Get emergency contacts
      final contacts = await _getEmergencyContacts();
      if (contacts.isEmpty) {
        LoggerService.warning('No emergency contacts configured');
        // Still keep the emergency active for local alerts
        return;
      }

      // Get current location
      final locationService = LocationService();
      final location = await locationService.getLocationWithAddress();

      // Update alert with location data
      final updatedAlert = tempAlert.copyWith(
        latitude: location?.latitude,
        longitude: location?.longitude,
        address: location?.address,
      );

      _currentAlert = updatedAlert;
      _currentAlertController.add(updatedAlert);

      // Start countdown for UI display
      await _startCountdown(updatedAlert, contacts, location?.address);
    } catch (e) {
      LoggerService.error('Error in background data gathering: $e');
      // Continue with basic alert even if data gathering fails
    }
  }

  /// Dispose service and clean up
  void dispose() {
    _emergencyCountdown?.cancel();
    _currentAlertController.close();
    _countdownController.close();
    _emergencyActiveController.close();
  }
}
