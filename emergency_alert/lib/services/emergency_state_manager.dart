import 'dart:async';
import 'logger/logger_service.dart';

/// Manages shared emergency state to prevent conflicts between
/// EmergencyResponseService and BackgroundService
class EmergencyStateManager {
  static final EmergencyStateManager _instance =
      EmergencyStateManager._internal();
  factory EmergencyStateManager() => _instance;
  EmergencyStateManager._internal();

  static bool _isGlobalEmergencyActive = false;
  static bool _isEmergencyCancelled = false;
  static DateTime? _lastCancellationTime;
  static String? _activeAlertId;

  // Stream to notify when emergency state changes
  static final StreamController<bool> _emergencyStateController =
      StreamController<bool>.broadcast();

  static Stream<bool> get emergencyStateStream =>
      _emergencyStateController.stream;

  /// Check if any emergency is currently active globally
  static bool get isGlobalEmergencyActive => _isGlobalEmergencyActive;

  /// Check if emergency was recently cancelled
  static bool get isEmergencyCancelled => _isEmergencyCancelled;

  /// Get the currently active alert ID
  static String? get activeAlertId => _activeAlertId;

  /// Mark the start of an emergency
  static void startEmergency(String alertId) {
    LoggerService.info('EmergencyStateManager: Starting emergency $alertId');
    _isGlobalEmergencyActive = true;
    _isEmergencyCancelled = false;
    _activeAlertId = alertId;
    _emergencyStateController.add(true);
  }

  /// Mark the end of an emergency (cancellation)
  static void cancelEmergency(String alertId) {
    LoggerService.info('EmergencyStateManager: Cancelling emergency $alertId');

    // Only cancel if this is the active alert
    if (_activeAlertId == alertId || _activeAlertId == null) {
      _isGlobalEmergencyActive = false;
      _isEmergencyCancelled = true;
      _lastCancellationTime = DateTime.now();
      _activeAlertId = null;
      _emergencyStateController.add(false);

      // Reset cancellation flag after a short delay to allow all services to see it
      Timer(const Duration(milliseconds: 500), () {
        _isEmergencyCancelled = false;
      });
    }
  }

  /// Mark the completion of an emergency (sent successfully)
  static void completeEmergency(String alertId) {
    LoggerService.info('EmergencyStateManager: Completing emergency $alertId');

    if (_activeAlertId == alertId || _activeAlertId == null) {
      _isGlobalEmergencyActive = false;
      _isEmergencyCancelled = false;
      _activeAlertId = null;
      _emergencyStateController.add(false);
    }
  }

  /// Check if enough time has passed since last cancellation to allow new emergency
  static bool canStartNewEmergency() {
    if (_lastCancellationTime == null) return true;

    final timeSinceCancellation = DateTime.now().difference(
      _lastCancellationTime!,
    );
    // Allow new emergency after 30 seconds cooldown
    return timeSinceCancellation.inSeconds > 30;
  }

  /// Force reset state (for testing or error recovery)
  static void resetState() {
    LoggerService.info('EmergencyStateManager: Resetting all state');
    _isGlobalEmergencyActive = false;
    _isEmergencyCancelled = false;
    _lastCancellationTime = null;
    _activeAlertId = null;
    _emergencyStateController.add(false);
  }

  /// Get time since last cancellation in seconds
  static int getTimeSinceCancellation() {
    if (_lastCancellationTime == null) return 0;
    return DateTime.now().difference(_lastCancellationTime!).inSeconds;
  }

  void dispose() {
    _emergencyStateController.close();
  }
}
