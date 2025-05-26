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

## Recent Updates

### Automatic SMS Sending (Fixed)

**Problem**: Previously, when a fall was detected, the app would only open the messaging app with a pre-filled message, requiring manual user intervention to send the SMS.

**Solution**: Implemented a custom platform channel solution for direct SMS sending:

- **Platform Channel Implementation**: Custom Android integration using `SmsManager` for direct SMS sending
- **Automatic Emergency Alerts**: SMS messages are now sent automatically without user intervention
- **Fallback Support**: If platform channel fails, the app falls back to the original messaging app method
- **Multiple Recipients**: Sends to all enabled emergency contacts simultaneously
- **Real-time Sending**: Emergency SMS is sent immediately when fall detection triggers
- **Long Message Support**: Automatically handles multipart SMS for longer messages

**Technical Details**:

- Custom `MethodChannel` implementation replacing third-party packages
- Android `SmsManager` integration for reliable SMS delivery
- Comprehensive error handling and logging
- No external dependencies for SMS functionality

**Benefits**:

- True hands-free emergency response
- No manual intervention required during emergencies
- Reliable delivery with fallback mechanism
- Faster emergency response time
