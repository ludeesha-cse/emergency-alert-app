# Fall Detection App Services

This directory contains all the service classes used by the Fall Detection App.

## LocalAlertService

The `LocalAlertService` is responsible for managing all local device alerts when a fall is detected. It handles:

- Vibration patterns using the `vibration` package
- Alarm sounds using the `audioplayers` package
- Flashlight toggling using the `torch_light` package

### Features

- **Battery Efficient**: Limits alert duration to conserve battery
- **Configurable**: Each alert type can be toggled via settings
- **Integrated**: Works with the `EmergencyAlertService` for a complete alert system

### Usage

```dart
// Initialize the service
final localAlertService = LocalAlertService();
await localAlertService.initialize();

// Start alerts (will check settings to determine which alerts to trigger)
await localAlertService.startAlerts();

// Stop all alerts
await localAlertService.stopAllAlerts();

// Update alert settings
await localAlertService.updateAlertSettings(
  vibrateOnFall: true,
  playAlarmOnFall: true,
  flashLightOnFall: false,
);
```

### Integration with EmergencyAlertService

The `LocalAlertService` is integrated with the `EmergencyAlertService` to provide a complete alert system:

1. When a fall is detected, `FallDetectionService` triggers the `EmergencyAlertService`
2. `EmergencyAlertService` then triggers both SMS alerts and local device alerts via `LocalAlertService`
3. If the user cancels the alert (false positive), all alerts are stopped

## Alert Patterns

- **Vibration**: 500ms on, 1000ms off, repeated pattern
- **Sound**: Looped alarm sound (alarm.mp3)
- **Flashlight**: 500ms on/off cycle

## Battery Efficiency

To conserve battery, all alerts automatically stop after 30 seconds if not manually canceled.
