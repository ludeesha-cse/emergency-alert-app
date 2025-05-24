// A utility class that handles fallback behaviors when permissions are denied
import 'package:flutter/material.dart';
import '../services/permission_service.dart';
import '../ui/screens/permission_screen.dart';

/// Handles fallback behaviors when various permissions are denied
class PermissionFallbacks {
  /// Get a description of current limitations based on missing permissions
  static String getLimitationsDescription(PermissionService permissionService) {
    List<String> limitations = [];

    if (!permissionService.isLocationGranted) {
      limitations.add('• Cannot determine your location during emergencies');
    }

    if (!permissionService.isBackgroundLocationGranted) {
      limitations.add('• Cannot track location while app is in background');
    }

    if (!permissionService.isMicrophoneGranted) {
      limitations.add('• Cannot detect audio-based emergency triggers');
    }

    if (!permissionService.isSmsGranted) {
      limitations.add(
        '• Cannot send automatic SMS alerts to emergency contacts',
      );
    }

    if (!permissionService.isNotificationGranted) {
      limitations.add(
        '• Cannot display emergency notifications or operate in background',
      );
    }

    if (limitations.isEmpty) {
      return 'All permissions granted. App is fully functional.';
    }

    return 'Current limitations due to missing permissions:\n${limitations.join('\n')}';
  }

  /// Check if the app can operate in limited mode
  static bool canOperateInLimitedMode(PermissionService permissionService) {
    // The app can operate in a limited capacity as long as it has location permission
    // This is the bare minimum requirement for the emergency alert app
    return permissionService.isLocationGranted;
  }

  /// Get fallback strategy for location service
  static Map<String, dynamic> getLocationFallbackStrategy(
    PermissionService permissionService,
  ) {
    if (permissionService.isLocationGranted) {
      if (permissionService.isBackgroundLocationGranted) {
        return {
          'canTrackLocation': true,
          'backgroundTracking': true,
          'message': 'Full location tracking is available',
        };
      } else {
        return {
          'canTrackLocation': true,
          'backgroundTracking': false,
          'message': 'Location tracking only works when app is open',
        };
      }
    } else {
      return {
        'canTrackLocation': false,
        'backgroundTracking': false,
        'message': 'Location tracking unavailable',
      };
    }
  }

  /// Get fallback strategy for notification service
  static Map<String, dynamic> getNotificationFallbackStrategy(
    PermissionService permissionService,
  ) {
    if (permissionService.isNotificationGranted) {
      return {
        'canShowNotifications': true,
        'canRunInBackground': true,
        'message': 'Notifications and background operation available',
      };
    } else {
      return {
        'canShowNotifications': false,
        'canRunInBackground': false,
        'message': 'Keep app open for alerts - cannot notify when closed',
      };
    }
  }

  /// Get fallback strategy for SMS service
  static Map<String, dynamic> getSmsFallbackStrategy(
    PermissionService permissionService,
  ) {
    if (permissionService.isSmsGranted) {
      return {'canSendSms': true, 'message': 'Automatic SMS alerts available'};
    } else {
      return {'canSendSms': false, 'message': 'Manual SMS alerts only'};
    }
  }

  /// Get fallback strategy for microphone service
  static Map<String, dynamic> getMicrophoneFallbackStrategy(
    PermissionService permissionService,
  ) {
    if (permissionService.isMicrophoneGranted) {
      return {
        'canUseMicrophone': true,
        'message': 'Audio emergency detection available',
      };
    } else {
      return {
        'canUseMicrophone': false,
        'message': 'Audio detection unavailable',
      };
    }
  }

  /// Show a dialog explaining the current limitations and how to fix them
  static Future<void> showLimitationsDialog(
    BuildContext context,
    PermissionService permissionService,
  ) async {
    final limitations = getLimitationsDescription(permissionService);

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limited Functionality'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('The app is running with limited functionality:'),
            const SizedBox(height: 12),
            Text(limitations),
            const SizedBox(height: 16),
            const Text(
              'Would you like to update your permissions to enable all features?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PermissionScreen(),
                ),
              );
            },
            child: const Text('Update Permissions'),
          ),
        ],
      ),
    );
  }
}
