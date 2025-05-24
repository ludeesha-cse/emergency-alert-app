import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A service class to handle runtime permission requests and maintain their states
class PermissionService extends ChangeNotifier {
  // Singleton instance
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  // Keys for shared preferences
  static const _locationPermKey = 'location_permission';
  static const _backgroundLocationPermKey = 'background_location_permission';
  static const _microphonePermKey = 'microphone_permission';
  static const _smsPermKey = 'sms_permission';
  static const _sensorsPermKey = 'sensors_permission';
  static const _notificationPermKey = 'notification_permission';

  // Permission state holders
  bool _isLocationGranted = false;
  bool _isBackgroundLocationGranted = false;
  bool _isMicrophoneGranted = false;
  bool _isSmsGranted = false;
  bool _isSensorsGranted = false;
  bool _isNotificationGranted = false;
  bool _isInitialized = false;

  // Getters
  bool get isLocationGranted => _isLocationGranted;
  bool get isBackgroundLocationGranted => _isBackgroundLocationGranted;
  bool get isMicrophoneGranted => _isMicrophoneGranted;
  bool get isSmsGranted => _isSmsGranted;
  bool get isSensorsGranted => _isSensorsGranted;
  bool get isNotificationGranted => _isNotificationGranted;
  bool get isInitialized => _isInitialized;

  // Getter to check if all required permissions are granted
  bool get areAllPermissionsGranted =>
      _isLocationGranted &&
      _isBackgroundLocationGranted &&
      _isMicrophoneGranted &&
      _isSmsGranted &&
      _isSensorsGranted &&
      _isNotificationGranted;

  /// Initialize and load permission states from shared preferences
  Future<void> init() async {
    await _loadPermissionStates();
    await checkPermissionStatuses();
    _isInitialized = true;
    notifyListeners();
  }

  /// Load stored permission states from SharedPreferences
  Future<void> _loadPermissionStates() async {
    final prefs = await SharedPreferences.getInstance();
    _isLocationGranted = prefs.getBool(_locationPermKey) ?? false;
    _isBackgroundLocationGranted =
        prefs.getBool(_backgroundLocationPermKey) ?? false;
    _isMicrophoneGranted = prefs.getBool(_microphonePermKey) ?? false;
    _isSmsGranted = prefs.getBool(_smsPermKey) ?? false;
    _isSensorsGranted = prefs.getBool(_sensorsPermKey) ?? false;
    _isNotificationGranted = prefs.getBool(_notificationPermKey) ?? false;
  }

  /// Save permission state to SharedPreferences
  Future<void> _savePermissionState(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  /// Check all permission statuses and update the state
  Future<void> checkPermissionStatuses() async {
    // Check location permission
    final locationStatus = await Permission.location.status;
    _isLocationGranted = locationStatus.isGranted;
    await _savePermissionState(_locationPermKey, _isLocationGranted);

    // Check background location permission
    if (_isLocationGranted) {
      final backgroundLocationStatus = await Permission.locationAlways.status;
      _isBackgroundLocationGranted = backgroundLocationStatus.isGranted;
      await _savePermissionState(
        _backgroundLocationPermKey,
        _isBackgroundLocationGranted,
      );
    }

    // Check microphone permission
    final microphoneStatus = await Permission.microphone.status;
    _isMicrophoneGranted = microphoneStatus.isGranted;
    await _savePermissionState(_microphonePermKey, _isMicrophoneGranted);

    // Check SMS permission
    final smsStatus = await Permission.sms.status;
    _isSmsGranted = smsStatus.isGranted;
    await _savePermissionState(_smsPermKey, _isSmsGranted);

    // Sensors don't typically need runtime permission, but we'll track it anyway
    _isSensorsGranted =
        true; // Assume granted since most devices don't require explicit permission
    await _savePermissionState(_sensorsPermKey, _isSensorsGranted);

    // Check notification permission for foreground service
    final notificationStatus = await Permission.notification.status;
    _isNotificationGranted = notificationStatus.isGranted;
    await _savePermissionState(_notificationPermKey, _isNotificationGranted);

    notifyListeners();
  }

  /// Request location permission
  Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    _isLocationGranted = status.isGranted;
    await _savePermissionState(_locationPermKey, _isLocationGranted);
    notifyListeners();
    return _isLocationGranted;
  }

  /// Request background location permission
  /// Note: This should be called after location permission is granted
  Future<bool> requestBackgroundLocationPermission() async {
    if (!_isLocationGranted) {
      final locationGranted = await requestLocationPermission();
      if (!locationGranted) return false;
    }

    final status = await Permission.locationAlways.request();
    _isBackgroundLocationGranted = status.isGranted;
    await _savePermissionState(
      _backgroundLocationPermKey,
      _isBackgroundLocationGranted,
    );
    notifyListeners();
    return _isBackgroundLocationGranted;
  }

  /// Request microphone permission
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    _isMicrophoneGranted = status.isGranted;
    await _savePermissionState(_microphonePermKey, _isMicrophoneGranted);
    notifyListeners();
    return _isMicrophoneGranted;
  }

  /// Request SMS permission
  Future<bool> requestSmsPermission() async {
    final status = await Permission.sms.request();
    _isSmsGranted = status.isGranted;
    await _savePermissionState(_smsPermKey, _isSmsGranted);
    notifyListeners();
    return _isSmsGranted;
  }

  /// Request notification permission for foreground service
  ///
  /// Note: On Android 13+ (API level 33+), the proper permission is POST_NOTIFICATIONS
  /// and may require the user to manually enable it in settings
  Future<bool> requestNotificationPermission() async {
    try {
      // Try standard permission request first
      final status = await Permission.notification.request();
      bool isGranted = status.isGranted;

      if (!isGranted) {
        // If not granted and on Android 13+, we need to handle special case
        // The permission_handler package handles this internally, but we need
        // to explicitly guide the user to system settings

        // Check if permission can be requested through normal means
        if (status.isPermanentlyDenied) {
          // Can only be granted from settings at this point
          await openAppSettings();

          // Wait a moment for user to potentially come back from settings
          await Future.delayed(const Duration(milliseconds: 500));

          // Check status again
          final newStatus = await Permission.notification.status;
          isGranted = newStatus.isGranted;
        } else if (status.isDenied) {
          // Let's try one more time with specific notification setting request
          try {
            // This is a safer approach to handle notification settings
            await openAppSettings();

            // Wait a moment for user to potentially come back from settings
            await Future.delayed(const Duration(milliseconds: 500));

            // Check status again
            final newStatus = await Permission.notification.status;
            isGranted = newStatus.isGranted;
          } catch (e) {
            print('Error opening notification settings: $e');
          }
        }
      }

      _isNotificationGranted = isGranted;
    } catch (e) {
      print('Error requesting notification permission: $e');
      _isNotificationGranted = false;
    }

    await _savePermissionState(_notificationPermKey, _isNotificationGranted);
    notifyListeners();
    return _isNotificationGranted;
  }

  /// Request all permissions at once
  Future<bool> requestAllPermissions() async {
    bool allGranted = true;

    // Request location and background location permissions
    final locationGranted = await requestLocationPermission();
    if (locationGranted) {
      final backgroundLocationGranted =
          await requestBackgroundLocationPermission();
      allGranted = allGranted && backgroundLocationGranted;
    } else {
      allGranted = false;
    }

    // Request microphone permission
    final microphoneGranted = await requestMicrophonePermission();
    allGranted = allGranted && microphoneGranted;

    // Request SMS permission
    final smsGranted = await requestSmsPermission();
    allGranted = allGranted && smsGranted;

    // Request notification permission
    final notificationGranted = await requestNotificationPermission();
    allGranted = allGranted && notificationGranted;

    // Sensors typically don't need runtime permission
    await _savePermissionState(_sensorsPermKey, true);

    notifyListeners();
    return allGranted;
  }

  /// Opens app settings page so user can enable permissions manually
  Future<bool> openSettings() async {
    return await openAppSettings();
  }
}
