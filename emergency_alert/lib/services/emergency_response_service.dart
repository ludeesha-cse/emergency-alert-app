import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alert.dart';
import '../models/contact.dart';
import '../models/sensor_data.dart';
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
      LoggerService.warning(
        'Attempted to send emergency immediately but no active alert',
      );
      print('⚠️ Attempted to send emergency immediately but no active alert');
      return;
    }

    try {
      LoggerService.info(
        '🚨 SENDING EMERGENCY IMMEDIATELY - Bypassing countdown',
      );
      print('🚨 User pressed Send Now - Sending emergency immediately');

      // Cancel countdown timer
      _emergencyCountdown?.cancel();

      // Get emergency contacts
      final contacts = await _getEmergencyContacts();
      if (contacts.isEmpty) {
        LoggerService.warning(
          'No emergency contacts configured - cannot send alerts',
        );
        print('⚠️ No emergency contacts configured - cannot send alerts');
        return;
      }

      print('📞 Found ${contacts.length} emergency contacts');
      LoggerService.info(
        'Found ${contacts.length} emergency contacts: ${contacts.map((c) => c.name).join(", ")}',
      );

      // Get current location - handle possible errors
      LocationData? location;
      String? locationInfo;

      try {
        final locationService = LocationService();
        location = await locationService.getLocationWithAddress();

        if (location != null) {
          locationInfo =
              location.address ??
              'Location: ${location.latitude}, ${location.longitude}';
          if (location.isFallback) {
            locationInfo = '(Last known $locationInfo)';
          }
          print('📍 Location retrieved: ${locationInfo}');
        } else {
          print('⚠️ Could not retrieve current location');
          // Use last known location from alert if available
          if (_currentAlert!.latitude != null &&
              _currentAlert!.longitude != null) {
            locationInfo =
                'Last known location: ${_currentAlert!.latitude}, ${_currentAlert!.longitude}';
            if (_currentAlert!.address != null) {
              locationInfo = '${_currentAlert!.address}';
            }
            print('📍 Using cached location: $locationInfo');
          } else {
            locationInfo = 'Location unavailable';
            print('⚠️ No location data available');
          }
        }
      } catch (e) {
        LoggerService.error('Error getting location: $e');
        print('⚠️ Error getting location: $e');
        locationInfo = 'Location unavailable due to error';
      }

      // Double-check SMS permission at this critical point
      final smsService = SmsService();
      final hasPermission = await smsService.checkPermissions();

      if (!hasPermission) {
        LoggerService.error('❌ SMS permission not granted at critical moment!');
        print('❌ SMS permission not granted at critical moment!');
        // We'll attempt to request permission again
        final permissionRetry = await smsService.checkPermissions();
        if (!permissionRetry) {
          print('❌ SMS permission retry failed - still trying to send');
        } else {
          print('✅ SMS permission granted on retry');
        }
      }

      // Send emergency alerts with more retries
      bool success = false;
      int attempts = 0;
      const maxAttempts = 5; // Increased from 3 to 5 attempts

      while (!success && attempts < maxAttempts) {
        attempts++;
        LoggerService.info('Sending emergency alerts - attempt $attempts');
        print('📤 Sending emergency alerts - attempt $attempts');

        // Try with increased timeout between retries
        success = await _sendEmergencyAlerts(
          _currentAlert!,
          contacts,
          locationInfo,
        );

        if (!success && attempts < maxAttempts) {
          // Wait longer between retries
          final delay = attempts * 2; // Increasing delay with each retry
          print('⏱️ Waiting $delay seconds before retry ${attempts + 1}');
          await Future.delayed(Duration(seconds: delay));
        }
      }

      if (success) {
        LoggerService.info('✅ Emergency sent immediately - SUCCESS');
        print('✅ Emergency alerts sent successfully');

        // Update alert status
        final updatedAlert = _currentAlert!.copyWith(
          status: AlertStatus.sent,
          sentToContacts: contacts.map((c) => c.id).toList(),
        );
        _currentAlert = updatedAlert;
        _currentAlertController.add(updatedAlert);

        // Ensure it's saved to history
        await _saveAlertToHistory(updatedAlert);
      } else {
        LoggerService.warning(
          '⚠️ All attempts to send emergency alerts failed',
        );
        print('⚠️ All ${maxAttempts} attempts to send emergency alerts failed');

        // Update alert status to failed
        final failedAlert = _currentAlert!.copyWith(status: AlertStatus.failed);
        _currentAlert = failedAlert;
        _currentAlertController.add(failedAlert);

        // Save failed status to history
        await _saveAlertToHistory(failedAlert);
      }
    } catch (e) {
      LoggerService.error('Error sending emergency immediately: $e');
      print('❌ Error sending emergency immediately: $e');

      // Update alert status to failed on exception
      if (_currentAlert != null) {
        final failedAlert = _currentAlert!.copyWith(status: AlertStatus.failed);
        _currentAlert = failedAlert;
        _currentAlertController.add(failedAlert);

        // Save failed status to history
        await _saveAlertToHistory(failedAlert);
      }
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
    try {
      // Get user's configured alert delay or use default
      final prefs = await SharedPreferences.getInstance();
      int remainingSeconds = prefs.getInt('alert_delay_seconds') ?? AppConstants.alertCountdownSeconds;

      _emergencyCountdown = Timer.periodic(const Duration(seconds: 1), (
        timer,
      ) async {
        try {
          remainingSeconds--;
          _countdownController.add(remainingSeconds);

          if (remainingSeconds <= 0) {
            timer.cancel();

            // Send emergency alerts after countdown
            LoggerService.info('Countdown finished - sending emergency alerts');
            print(
              '⏱️ Countdown finished - sending emergency alerts automatically',
            );

            // Ensure the alert wasn't cancelled during countdown
            if (_isEmergencyActive && _currentAlert != null) {
              // Send emergency alerts with retries
              bool success = false;
              int attempts = 0;
              const maxAttempts = 3;

              while (!success && attempts < maxAttempts) {
                attempts++;
                LoggerService.info(
                  'Sending automatic emergency alerts - attempt $attempts',
                );
                print(
                  '📤 Sending automatic emergency alerts - attempt $attempts',
                );

                success = await _sendEmergencyAlerts(
                  alert,
                  contacts,
                  locationInfo,
                );

                if (!success && attempts < maxAttempts) {
                  // Wait between retries
                  await Future.delayed(Duration(seconds: 2));
                }
              }

              if (!success) {
                LoggerService.error(
                  'Failed to send automatic emergency alerts after $maxAttempts attempts',
                );
                print(
                  '❌ Failed to send automatic emergency alerts after $maxAttempts attempts',
                );
              }
            } else {
              LoggerService.info(
                'Emergency was cancelled during countdown - not sending alerts',
              );
              print(
                '🛑 Emergency was cancelled during countdown - not sending alerts',
              );
            }
          }
        } catch (timerError) {
          // Prevent timer callback errors from crashing the app
          LoggerService.error('Error in countdown timer callback: $timerError');
          print('❌ Error in countdown timer: $timerError');

          // Cancel the timer if there's an error to prevent repeated errors
          timer.cancel();

          // Try to send alerts anyway if we had an error during countdown
          try {
            await _sendEmergencyAlerts(alert, contacts, locationInfo);
          } catch (sendError) {
            LoggerService.error(
              'Error sending emergency alerts after timer error: $sendError',
            );
          }
        }
      });
    } catch (e) {
      LoggerService.error('Error starting countdown timer: $e');
      print('❌ Error starting countdown: $e');

      // Try to send alerts anyway if we couldn't set up the countdown
      try {
        await _sendEmergencyAlerts(alert, contacts, locationInfo);
      } catch (sendError) {
        LoggerService.error(
          'Error sending emergency alerts after countdown setup error: $sendError',
        );
      }
    }
  }

  /// Send emergency alerts via SMS and update status
  /// Returns true if SMS was sent successfully to all contacts
  Future<bool> _sendEmergencyAlerts(
    Alert alert,
    List<EmergencyContact> contacts,
    String? locationInfo,
  ) async {
    try {
      LoggerService.info(
        'Sending emergency alerts to ${contacts.length} contacts',
      );
      print('📱 Attempting to send SMS to ${contacts.length} contacts');

      if (contacts.isEmpty) {
        LoggerService.warning('No emergency contacts to send alerts to');
        print('⚠️ No emergency contacts to send alerts to');
        return false;
      }

      // Double-check SMS permission before sending
      final smsService = SmsService();
      final hasPermission = await smsService.checkPermissions();

      if (!hasPermission) {
        LoggerService.error(
          'SMS permission not granted - trying to request it',
        );
        print('⚠️ SMS permission not granted - trying to request it');

        // Try to request permission again
        final permissionRetry = await smsService.checkPermissions();
        if (!permissionRetry) {
          LoggerService.error(
            'SMS permission denied after retry - attempting to send anyway',
          );
          print(
            '⚠️ SMS permission denied after retry - attempting to send anyway',
          );
        }
      }

      // Send SMS alerts
      final success = await smsService.sendEmergencyAlert(
        contacts: contacts,
        alert: alert,
        locationInfo: locationInfo,
      );

      if (success) {
        LoggerService.info('✅ Emergency SMS alerts sent successfully');
        print('✅ Emergency SMS alerts sent successfully');
      } else {
        LoggerService.error('❌ Failed to send emergency SMS alerts');
        print('❌ Failed to send emergency SMS alerts');
      }

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
        if (_isEmergencyActive) {
          LoggerService.info(
            'Auto-cleanup after 2 minutes since emergency alert was sent',
          );
          await _cleanup();
        }
      });

      return success;
    } catch (e) {
      LoggerService.error('Error sending emergency alerts: $e');
      print('❌ Error sending emergency alerts: $e');

      // Mark as failed
      final failedAlert = alert.copyWith(status: AlertStatus.failed);
      _currentAlert = failedAlert;
      _currentAlertController.add(failedAlert);
      await _saveAlertToHistory(failedAlert);

      return false;
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
      
      // Get user's configured alert delay or use default
      final prefs = await SharedPreferences.getInstance();
      final alertDelaySeconds = prefs.getInt('alert_delay_seconds') ?? AppConstants.alertCountdownSeconds;
      _countdownController.add(alertDelaySeconds);

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

      // Get current location with robust error handling
      LocationData? location;
      String? locationInfo;

      try {
        final locationService = LocationService();

        // Set a timeout for location fetching to prevent UI blocking
        location = await locationService.getLocationWithAddress().timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            LoggerService.warning('Location fetch timed out after 15 seconds');
            print('⚠️ Location fetch timed out after 15 seconds');
            return null;
          },
        );

        if (location != null) {
          locationInfo =
              location.address ??
              'Location: ${location.latitude}, ${location.longitude}';
          print('📍 Location retrieved: ${locationInfo}');
        } else {
          print('⚠️ Could not retrieve location for background data gathering');
          locationInfo = 'Location unavailable';
        }
      } catch (locError) {
        // Handle location errors gracefully
        LoggerService.error('Error getting location in background: $locError');
        print('⚠️ Error getting location in background: $locError');
        // Continue without location
      }

      // Update alert with location data (if available)
      final updatedAlert = tempAlert.copyWith(
        latitude: location?.latitude,
        longitude: location?.longitude,
        address: location?.address,
      );

      _currentAlert = updatedAlert;
      _currentAlertController.add(updatedAlert);

      // Start countdown for UI display
      await _startCountdown(updatedAlert, contacts, locationInfo);
    } catch (e) {
      LoggerService.error('Error in background data gathering: $e');
      print('❌ Error in background data gathering: $e');
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
