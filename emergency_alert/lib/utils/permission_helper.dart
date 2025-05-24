import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  static Future<bool> requestLocationPermissions() async {
    final permissions = [
      Permission.location,
      Permission.locationWhenInUse,
      Permission.locationAlways,
    ];

    Map<Permission, PermissionStatus> statuses = await permissions.request();

    return statuses.values.every(
      (status) =>
          status == PermissionStatus.granted ||
          status == PermissionStatus.limited,
    );
  }

  static Future<bool> requestSmsPermissions() async {
    final permissions = [Permission.sms];

    Map<Permission, PermissionStatus> statuses = await permissions.request();

    return statuses.values.every(
      (status) => status == PermissionStatus.granted,
    );
  }

  static Future<bool> requestAudioPermissions() async {
    final permissions = [Permission.microphone];

    Map<Permission, PermissionStatus> statuses = await permissions.request();

    return statuses.values.every(
      (status) => status == PermissionStatus.granted,
    );
  }

  static Future<bool> requestCameraPermissions() async {
    final permissions = [Permission.camera];

    Map<Permission, PermissionStatus> statuses = await permissions.request();

    return statuses.values.every(
      (status) => status == PermissionStatus.granted,
    );
  }

  static Future<bool> requestPhonePermissions() async {
    final permissions = [Permission.phone];

    Map<Permission, PermissionStatus> statuses = await permissions.request();

    return statuses.values.every(
      (status) => status == PermissionStatus.granted,
    );
  }

  static Future<bool> requestStoragePermissions() async {
    final permissions = [Permission.storage];

    Map<Permission, PermissionStatus> statuses = await permissions.request();

    return statuses.values.every(
      (status) => status == PermissionStatus.granted,
    );
  }

  static Future<bool> requestNotificationPermissions() async {
    final permissions = [Permission.notification];

    Map<Permission, PermissionStatus> statuses = await permissions.request();

    return statuses.values.every(
      (status) => status == PermissionStatus.granted,
    );
  }

  static Future<bool> requestAllPermissions() async {
    final results = await Future.wait([
      requestLocationPermissions(),
      requestSmsPermissions(),
      requestAudioPermissions(),
      requestCameraPermissions(),
      requestPhonePermissions(),
      requestStoragePermissions(),
      requestNotificationPermissions(),
    ]);

    return results.every((granted) => granted);
  }

  static Future<Map<String, bool>> checkAllPermissions() async {
    return {
      'location': await Permission.location.isGranted,
      'sms': await Permission.sms.isGranted,
      'microphone': await Permission.microphone.isGranted,
      'camera': await Permission.camera.isGranted,
      'phone': await Permission.phone.isGranted,
      'storage': await Permission.storage.isGranted,
      'notification': await Permission.notification.isGranted,
    };
  }

  static Future<bool> requestIgnoreBatteryOptimizations() async {
    return await Permission.ignoreBatteryOptimizations.request() ==
        PermissionStatus.granted;
  }
}
