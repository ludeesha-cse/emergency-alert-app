# Permission Handling System

This document provides an overview of the permission handling system implemented in the Emergency Alert app.

## Components

### 1. PermissionService

The `PermissionService` class is the core component that handles runtime permission requests and tracks their states. It's implemented as a singleton with ChangeNotifier to facilitate state management.

Location:

```
lib/services/permission_service.dart
```

Features:

- Handles requests for critical permissions (location, background location, microphone, SMS, sensors, notifications)
- Maintains permission states using SharedPreferences
- Provides methods to request individual and all permissions
- Includes a method to open app settings

### 2. PermissionModel

A simple model class that represents a single permission with its metadata.

Location:

```
lib/models/permission_model.dart
```

### 3. PermissionScreen

A user-friendly UI for requesting and managing permissions.

Location:

```
lib/ui/screens/permission_screen.dart
```

Features:

- Displays each permission with an explanation of why it's needed
- Shows the current status of each permission (granted/denied)
- Provides buttons to request each permission individually
- Includes a "Request All Permissions" button
- Provides fallback to app settings if permissions are denied

### 4. PermissionHandler

A utility class that helps integrate permission handling into the app flow.

Location:

```
lib/utils/permission_handler.dart
```

Features:

- Checks if all required permissions are granted
- Shows the permission screen when needed
- Provides a unified API for permission-related operations

### 5. Permission Helper

A utility class that acts as a bridge between the new permission system and existing code.

Location:

```
lib/utils/permission_helper.dart
```

## Usage

### Basic Usage

To check and request permissions in your screen:

```dart
import 'package:provider/provider.dart';
import '../services/permission_service.dart';
import '../ui/screens/permission_screen.dart';

// Inside a StatefulWidget:
void initState() {
  super.initState();
  _checkPermissions();
}

Future<void> _checkPermissions() async {
  final permissionService = Provider.of<PermissionService>(context, listen: false);

  // Initialize if needed
  if (!permissionService.isInitialized) {
    await permissionService.init();
  }

  // Check if all permissions are granted
  if (!permissionService.areAllPermissionsGranted) {
    // Show the permission screen
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PermissionScreen(),
      ),
    );
  }
}
```

### Advanced Usage

For advanced usage and integration with existing code, use the PermissionHandler utility:

```dart
import '../utils/permission_handler.dart';

// Check if all permissions are granted
final allGranted = await PermissionHandler.checkPermissions(permissionService);

// Show permissions screen if needed and get the result
final permissionsGranted = await PermissionHandler.showPermissionsIfNeeded(
  context,
  permissionService
);

// Handle the result
if (permissionsGranted) {
  // All permissions granted, proceed with functionality
} else {
  // Some permissions denied, handle gracefully
}
```

## Graceful Fallbacks

When permissions are denied, the app degrades gracefully using the `PermissionFallbacks` utility class:

### Fallback System

The `PermissionFallbacks` class provides methods to determine how the app should operate with limited permissions:

```dart
import '../utils/permission_fallbacks.dart';

// Check if we can operate in limited mode
final canOperateWithLimitations = PermissionFallbacks.canOperateInLimitedMode(permissionService);

// Get limitations description to show to the user
final limitations = PermissionFallbacks.getLimitationsDescription(permissionService);

// Show limitations dialog
await PermissionFallbacks.showLimitationsDialog(context, permissionService);

// Get specific fallback strategies
final locationStrategy = PermissionFallbacks.getLocationFallbackStrategy(permissionService);
final notificationStrategy = PermissionFallbacks.getNotificationFallbackStrategy(permissionService);
```

### Permission-Specific Fallbacks

1. For location permissions:

   - Disable automatic location tracking
   - Allow manual location entry
   - Limit geofencing features

2. For microphone permissions:

   - Disable audio detection features
   - Focus on motion detection only
   - Provide manual emergency trigger option

3. For SMS permissions:

   - Disable automatic SMS alerts
   - Provide manual SMS sending option
   - Use alternative communication channels if available

4. For background execution:

   - Notify user that alerts only work when app is in foreground
   - Provide instructions on how to enable background execution
   - Implement foreground service workarounds where possible

5. For notification permissions:
   - Display in-app alerts instead of system notifications
   - Use visual indicators within the app
   - Prompt users periodically to enable notifications

## Special Notes for Notification Permissions

On Android 13 (API level 33) and higher, users must explicitly grant notification permissions through system settings. The app handles this with the following strategies:

1. **Clear Notification Banner**: A prominent amber banner is displayed when notification permissions are not granted
2. **Direct Settings Access**: Users are guided to system settings with detailed instructions
3. **Graceful Degradation**: The app continues to function in a limited capacity without notifications
4. **POST_NOTIFICATIONS Permission**: The AndroidManifest.xml includes the proper permission declaration

### Troubleshooting Notification Issues

If notification permissions cannot be granted:

1. Go to Android Settings > Apps > Emergency Alert > Notifications
2. Toggle "Allow notifications" to ON
3. Return to the app and verify the permission is granted

On some devices, you may need to:

1. Go to Settings > Apps > Emergency Alert > Permissions > Notifications
2. Set notification permission to "Allow"

## Foreground Service and BadNotificationForForegroundService Exception

The BackgroundService component has been updated to properly handle foreground service notifications on all Android versions, including Android 13+.

### Fix for BadNotificationForForegroundService Exception

The exception was fixed by implementing the following changes:

1. **Correct Notification Setup**:

   ```dart
   // First switch to foreground mode - with no parameters
   await service.setAsForegroundService();

   // Then set notification info
   await service.setForegroundNotificationInfo(
     title: "Emergency Alert Active",
     content: "Monitoring for emergencies"
   );
   ```

2. **AndroidManifest.xml Configuration**:
   - Added proper foreground service types:
   ```xml
   <service
       android:name="id.flutter.flutter_background_service.BackgroundService"
       android:foregroundServiceType="dataSync|location"
       android:exported="false"
       tools:replace="android:exported" />
   ```
   - Added required permissions:
   ```xml
   <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
   <uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
   <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
   ```
3. **Error Handling**: Added proper error handling to display useful diagnostics if notification setup fails:
   ```dart
   try {
     // Notification setup code
   } catch (e) {
     print('Error setting up foreground service: $e');
   }
   ```

If you're still experiencing issues with the foreground service notification:

1. Check that notification permissions are granted
2. Ensure battery optimization is disabled for the app
3. On some devices, you may need to "lock" the app in recent apps list
