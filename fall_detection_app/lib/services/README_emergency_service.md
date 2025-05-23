# EmergencyAlertService Documentation

The `EmergencyAlertService` is a Flutter service designed to handle emergency SMS alerts in a fall detection application. This service manages emergency contacts, sends SMS alerts with location information when falls are detected, and ensures offline functionality.

## Features

- **Emergency SMS Alerts**: Sends SMS messages to emergency contacts with location information
- **Contact Management**: Store up to 5 emergency contacts
- **Location Integration**: Includes GPS coordinates in emergency messages
- **Offline Support**: Works without internet connectivity
- **Permission Handling**: Manages SMS and location permissions
- **Custom Messages**: Supports configurable emergency message templates

## Usage

### Initialize the Service

```dart
final emergencyService = EmergencyAlertService();
await emergencyService.initialize();
```

### Send Emergency Alerts

```dart
// Send using default emergency message
bool success = await emergencyService.sendEmergencyAlerts();

// Send with custom message
bool success = await emergencyService.sendEmergencyAlerts(
  customMessage: "Help needed! I've fallen and can't get up.",
);
```

### Managing Emergency Contacts

```dart
// Add a contact
bool added = await emergencyService.addEmergencyContact(
  name: "John Doe",
  phoneNumber: "+1234567890",
);

// Remove a contact
bool removed = await emergencyService.removeEmergencyContact("+1234567890");

// Update a contact
bool updated = await emergencyService.updateEmergencyContact(
  oldPhoneNumber: "+1234567890",
  name: "John Smith",
  newPhoneNumber: "+0987654321",
);

// Get all contacts
List<EmergencyContact> contacts = await emergencyService.getEmergencyContacts();
```

### Emergency Message Management

```dart
// Update emergency message
await emergencyService.updateEmergencyMessage(
  "I need help! Please check on me at my current location:"
);

// Get current emergency message
String message = await emergencyService.getEmergencyMessage();
```

### Permission Handling

```dart
// Check if alerts can be sent (SMS permission granted and contacts configured)
bool canSend = await emergencyService.canSendAlerts();
```

## Implementation Details

### SMS Sending

The service uses the device's native SMS capabilities to send messages without requiring an internet connection. This ensures reliability during emergencies when network connectivity might be limited.

### Location Data

The service attempts to get the current location first, then falls back to the last known location if real-time data isn't available.

### Contact Storage

Emergency contacts are stored using SharedPreferences and are limited to 5 contacts maximum.

### Integration with Fall Detection

The service is designed to integrate with fall detection algorithms through a simple API. When a fall is detected, simply call `sendEmergencyAlerts()`.

### Error Handling

The service includes error handling to ensure reliability in emergency situations. Failed SMS attempts are logged, and the service provides feedback on whether alerts were successfully sent.

## Example Screen

See the `EmergencyContactsScreen` for a complete example of how to use this service in a user interface, including:

- Adding and removing contacts
- Setting custom emergency messages
- Testing alert functionality
