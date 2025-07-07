# Emergency Alert App

A comprehensive Flutter application that uses device sensors to detect falls and impacts, automatically triggering emergency responses including SMS alerts, audio alarms, flashlight activation, and vibration patterns.

## 🚀 Overview

This emergency alert system continuously monitors device sensors to detect potential emergencies and automatically contacts designated emergency contacts. The app is designed for users who may be at risk of falls or accidents and need immediate assistance.

## 🔧 Core Detection Logic

### Fall Detection Algorithm

The app implements a sophisticated fall detection system using accelerometer and gyroscope data:

#### 1. Free Fall Detection

- **Threshold**: < 0.5 G-force (gravity units)
- **Logic**: Detects when the device experiences minimal acceleration, indicating free fall
- **Duration**: Monitors for 300ms to confirm sustained free fall

#### 2. Impact Detection After Free Fall

- **Threshold**: > 2.5 G-force after free fall
- **Algorithm**:
  1. Detect free fall phase
  2. Wait for impact (up to 300ms)
  3. Confirm impact with acceleration spike
  4. Trigger emergency if both conditions are met

### Impact Detection Algorithm

Independent impact detection for sudden collisions or accidents:

#### Multi-Stage Validation

1. **Baseline Calculation**: Uses rolling average of recent readings (excluding outliers)
2. **Threshold Check**: Impact magnitude > 15.0 G-force
3. **Device Movement Verification**: Confirms device is actually moving using gyroscope data
4. **Consecutive Confirmation**: Requires 3 consecutive high readings to avoid false positives
5. **Cooldown Period**: 2-second cooldown between detections to prevent duplicate alerts

#### Mathematical Formula

```
magnitude = √(x² + y² + z²)
magnitudeChange = |magnitude - baseline|
isImpact = magnitudeChange > 15.0 AND gyroscopeMovement > 0.1 AND consecutiveReadings ≥ 3
```

### Sensor Configuration

#### Accelerometer Settings

- **Sampling Rate**: 20 Hz (20 readings per second)
- **Buffer Size**: 100 samples for moving average calculations
- **Earth Gravity Compensation**: 9.81 m/s²

#### Gyroscope Settings

- **Sampling Rate**: 10 Hz
- **Sensitivity**: 0.1 degrees/second
- **Maximum Value**: 2000 degrees/second

## 📱 Emergency Response System

### Immediate Response (0-5 seconds)

1. **Audio Alert**: High-priority alarm sound at 80% volume
2. **Vibration Pattern**: Emergency vibration sequence [0ms, 1000ms, 500ms, 1000ms, 500ms, 1000ms]
3. **Flashlight**: Strobe pattern for visual alert
4. **Screen Activation**: Wake device and show emergency interface

### Countdown Phase (30 seconds)

- User has 30 seconds to cancel the alert
- Countdown timer displayed prominently
- All local alerts continue during countdown
- One-tap cancellation available

### Emergency Dispatch

If not cancelled within 30 seconds:

1. **SMS Alerts**: Send location and emergency details to all emergency contacts
2. **Retry Logic**: Up to 5 retry attempts with 60-second intervals
3. **Status Tracking**: Monitor delivery status and log all attempts

## 📦 Libraries and Dependencies

### Core Sensor Libraries

```yaml
sensors_plus: ^6.0.1 # Accelerometer and gyroscope access
```

### Location Services

```yaml
geolocator: ^13.0.1 # GPS location tracking
location: ^7.0.0 # Alternative location service
geocoding: ^3.0.0 # Address resolution from coordinates
```

### Communication

```yaml
url_launcher: ^6.2.5 # SMS and call functionality
```

_Note: Direct SMS sending uses native Android MethodChannel for reliable delivery_

### Background Processing

```yaml
flutter_background_service: ^5.0.10 # Continuous monitoring when app is closed
```

### Multimedia and Alerts

```yaml
just_audio: ^0.9.40 # Emergency alarm sounds
torch_light: ^1.0.0 # Flashlight control
vibration: ^2.0.0 # Haptic feedback patterns
flutter_local_notifications: ^19.2.1 # System notifications
```

### Permissions and Security

```yaml
permission_handler: ^11.3.1 # Runtime permission management
```

### Data Storage

```yaml
shared_preferences: ^2.3.2 # User settings and configuration
sqflite: ^2.3.3+1 # Local database for contacts and alert history
```

### State Management and Utilities

```yaml
provider: ^6.1.2 # State management
rxdart: ^0.28.0 # Reactive programming streams
intl: ^0.19.0 # Date/time formatting
logger: ^2.5.0 # Debug and error logging
```

## 🔐 Required Permissions

### Android Manifest Permissions

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.SEND_SMS" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.FLASHLIGHT" />
```

### Runtime Permission Flow

1. **Location**: Required for emergency GPS coordinates
2. **SMS**: Essential for contacting emergency contacts
3. **Notifications**: For background service alerts
4. **Camera/Flashlight**: For emergency visual signals

## 🏗️ Architecture Overview

### Service Layer

- **SensorService**: Continuous sensor monitoring and algorithm processing
- **EmergencyResponseService**: Coordinates all emergency actions
- **LocationService**: GPS tracking and address resolution
- **SMSService**: Emergency message dispatch
- **AudioService**: Alarm sound management
- **FlashlightService**: Visual alert control
- **VibrationService**: Haptic feedback management
- **PermissionService**: Runtime permission handling

### Data Models

- **SensorData**: Accelerometer and gyroscope readings with timestamps
- **Alert**: Emergency event details and status
- **Contact**: Emergency contact information
- **PermissionModel**: Permission state management

### Background Service

- Runs continuously using foreground service
- Monitors sensors even when app is closed
- Handles emergency detection and response
- Maintains GPS location updates

## ⚙️ Configuration Parameters

### Detection Thresholds (Configurable)

```dart
// Fall Detection
static const double freeFallThreshold = 0.5;        // G-force
static const double fallDetectionThreshold = 2.5;   // G-force
static const int freeFallDurationMs = 300;          // milliseconds

// Impact Detection
static const double impactDetectionThreshold = 15.0; // G-force
static const int impactConfirmationCount = 3;        // consecutive readings
static const int impactCooldownMs = 2000;           // milliseconds

// Sensor Configuration
static const int accelerometerSensitivity = 20;     // Hz
static const int gyroscopeSamplingRate = 10;        // Hz
static const int sensorBufferSize = 100;            // samples
```

### Alert Timing

```dart
static const int alertCountdownSeconds = 30;        // Cancellation window
static const int emergencyResponseTimeout = 300;    // 5 minutes
static const int retryIntervalSeconds = 60;         // SMS retry interval
static const int maxRetryAttempts = 5;              // Maximum retries
```

## 🚦 Getting Started

### Installation

1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Configure emergency contacts in the app
4. Grant all required permissions
5. Test the system with gentle shake to verify detection

### Initial Setup

1. **Add Emergency Contacts**: Minimum 1, maximum 10 contacts
2. **Permission Grant**: Allow all requested permissions
3. **Background Service**: Enable to run continuously
4. **Test Mode**: Use built-in test functions to verify SMS delivery

### Testing the System

- **Gentle Test**: Soft shake to test impact detection (reduced threshold in test mode)
- **SMS Test**: Send test messages to verify contact delivery
- **Background Test**: Ensure monitoring continues when app is closed

## 🔍 Troubleshooting

### Common Issues

- **False Positives**: Adjust impact threshold in settings if too sensitive
- **Missed Events**: Check sensor permissions and background service status
- **SMS Failures**: Verify phone numbers and network connectivity
- **Battery Optimization**: Disable for this app to ensure continuous monitoring

### Debug Features

- Real-time sensor data visualization
- Alert history and logs
- Permission status monitoring
- Background service health checks

## 🔒 Privacy and Security

- All location data processed locally
- Emergency contacts stored securely on device
- No data transmitted to external servers (except emergency SMS)
- User controls all alert triggers and cancellations

## 📋 System Requirements

- **Android**: 6.0+ (API level 23)
- **iOS**: 11.0+
- **Sensors**: Accelerometer and gyroscope required
- **Permissions**: Location, SMS, and notification access
- **Storage**: 50MB for app and alert history

## 🆘 Emergency Use

### When Alert is Triggered

1. **Stay Calm**: You have 30 seconds to cancel if false alarm
2. **Cancel if Safe**: Tap the large "Cancel" button if you're okay
3. **Let it Send**: If you need help, let the countdown complete
4. **Follow Up**: Emergency contacts will receive your location and time

### For Emergency Contacts

- Will receive SMS with exact location coordinates
- Message includes timestamp and alert type
- Can track location link to find the person
- Advised to call emergency services if needed

---

**Emergency Alert App** - Your safety companion that's always watching out for you.
