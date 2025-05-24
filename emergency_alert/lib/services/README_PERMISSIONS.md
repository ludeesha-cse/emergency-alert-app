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

When permissions are denied, the app should degrade gracefully:

1. For location permissions:

   - Disable automatic location tracking
   - Allow manual location entry

2. For microphone permissions:

   - Disable audio detection features
   - Focus on motion detection only

3. For SMS permissions:

   - Disable automatic SMS alerts
   - Provide manual SMS sending option

4. For background execution:
   - Notify user that alerts only work when app is in foreground
   - Provide instructions on how to enable background execution
