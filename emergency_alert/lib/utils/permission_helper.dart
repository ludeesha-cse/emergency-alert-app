import 'package:permission_handler/permission_handler.dart';
import '../services/permission_service.dart';

/// A utility class for handling permissions in the app
/// Note: This class wraps the new PermissionService to maintain compatibility
/// with existing code while we transition to the new service
class PermissionHelper {
  static PermissionService _getPermissionService() {
    return PermissionService();
  }

  static Future<bool> requestLocationPermissions() async {
    final permissionService = _getPermissionService();
    final locationGranted = await permissionService.requestLocationPermission();

    // We'll return true if at least the basic location permission is granted
    return locationGranted;
  }

  static Future<bool> requestSmsPermissions() async {
    final permissionService = _getPermissionService();
    return await permissionService.requestSmsPermission();
  }

  static Future<bool> requestAudioPermissions() async {
    final permissionService = _getPermissionService();
    return await permissionService.requestMicrophonePermission();
  }

  static Future<bool> requestCameraPermissions() async {
    // Camera permission is not handled by our new service, so we'll use the direct approach
    final permissionStatus = await Permission.camera.request();
    return permissionStatus == PermissionStatus.granted;
  }

  static Future<bool> requestPhonePermissions() async {
    // Phone permission is not handled by our new service, so we'll use the direct approach
    final permissionStatus = await Permission.phone.request();
    return permissionStatus == PermissionStatus.granted;
  }

  static Future<bool> requestStoragePermissions() async {
    // Storage permission is not handled by our new service, so we'll use the direct approach
    final permissionStatus = await Permission.storage.request();
    return permissionStatus == PermissionStatus.granted;
  }

  static Future<bool> requestNotificationPermissions() async {
    final permissionService = _getPermissionService();
    return await permissionService.requestNotificationPermission();
  }

  static Future<bool> requestAllPermissions() async {
    final permissionService = _getPermissionService();

    // Request all permissions managed by the permission service
    final servicePermissions = await permissionService.requestAllPermissions();

    // Request additional permissions not managed by the service
    final cameraPermission = await requestCameraPermissions();
    final phonePermission = await requestPhonePermissions();
    final storagePermission = await requestStoragePermissions();

    // Return true only if all permissions are granted
    return servicePermissions &&
        cameraPermission &&
        phonePermission &&
        storagePermission;
  }

  static Future<Map<String, bool>> checkAllPermissions() async {
    final permissionService = _getPermissionService();
    await permissionService.checkPermissionStatuses();

    // Create a map of all permission statuses
    return {
      'location': permissionService.isLocationGranted,
      'backgroundLocation': permissionService.isBackgroundLocationGranted,
      'sms': permissionService.isSmsGranted,
      'microphone': permissionService.isMicrophoneGranted,
      'sensors': permissionService.isSensorsGranted,
      'notification': permissionService.isNotificationGranted,
      'camera': await Permission.camera.isGranted,
      'phone': await Permission.phone.isGranted,
      'storage': await Permission.storage.isGranted,
    };
  }

  static Future<bool> requestIgnoreBatteryOptimizations() async {
    return await Permission.ignoreBatteryOptimizations.request() ==
        PermissionStatus.granted;
  }

  /// Opens the app settings page so the user can grant permissions manually
  static Future<bool> openAppSettings() async {
    final permissionService = _getPermissionService();
    return await permissionService.openSettings();
  }
}
