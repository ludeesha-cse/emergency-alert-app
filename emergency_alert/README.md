# Emergency Alert Flutter Project

This is a comprehensive Flutter application for emergency alert detection and response, targeting Android API Level 26+.

## Features

- **Sensor-based Detection**: Monitors accelerometer and gyroscope for fall and impact detection
- **Location Services**: GPS tracking and reverse geocoding for emergency location
- **SMS Emergency Alerts**: Automated SMS messaging to emergency contacts
- **Background Monitoring**: Continuous monitoring even when app is in background
- **Audio Alarms**: Emergency sound alerts and alarms
- **Flashlight Control**: Emergency flashing patterns including SOS
- **Vibration Feedback**: Emergency vibration patterns
- **Offline Functionality**: Core features work without internet connectivity

## Project Structure

```
lib/
├── models/          # Data models
│   ├── alert.dart
│   ├── contact.dart
│   └── sensor_data.dart
├── services/        # Core services
│   ├── sensor/      # Sensor monitoring
│   ├── location/    # GPS and location services
│   ├── sms/         # SMS messaging
│   ├── background/  # Background processing
│   ├── audio/       # Audio playback
│   ├── flashlight/  # Flashlight control
│   └── vibration/   # Vibration control
├── ui/              # User interface
│   ├── screens/     # App screens
│   └── widgets/     # Reusable widgets
└── utils/           # Utilities
    ├── constants.dart
    └── permission_helper.dart
```
