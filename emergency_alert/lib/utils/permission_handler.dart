import 'dart:async';
import 'package:flutter/material.dart';
import '../services/permission_service.dart';
import '../ui/screens/permission_screen.dart';

/// Utility class to help with permission handling and navigation
class PermissionHandler {
  /// Check if all required permissions are granted
  /// Returns true if all permissions are granted, false otherwise
  static Future<bool> checkPermissions(
    PermissionService permissionService,
  ) async {
    if (!permissionService.isInitialized) {
      await permissionService.init();
    } else {
      await permissionService.checkPermissionStatuses();
    }
    return permissionService.areAllPermissionsGranted;
  }

  /// Show permission screen if any permission is not granted
  /// Returns true if all permissions are granted (either before or after showing the screen)
  /// Returns false if user dismisses the screen without granting all permissions
  static Future<bool> showPermissionsIfNeeded(
    BuildContext context,
    PermissionService permissionService,
  ) async {
    final allGranted = await checkPermissions(permissionService);

    if (allGranted) {
      return true;
    }

    // Show permissions screen and wait for result
    final completer = Completer<bool>();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PermissionScreen(
          onAllPermissionsGranted: () {
            completer.complete(true);
            Navigator.pop(context);
          },
        ),
      ),
    );

    // If completer hasn't been completed, it means the user dismissed the screen
    if (!completer.isCompleted) {
      completer.complete(await checkPermissions(permissionService));
    }

    return completer.future;
  }
}
