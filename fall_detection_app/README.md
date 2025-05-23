# Fall Detection App

A comprehensive Flutter application for detecting falls and automatically alerting emergency contacts. This app uses device sensors, GPS location, and emergency communication features to provide safety monitoring for elderly users or anyone at risk of falls.

## 🚀 Features

### Core Fall Detection

- **Real-time Accelerometer Monitoring**: Continuously monitors device motion using accelerometer and gyroscope sensors
- **Advanced Fall Algorithm**: Uses magnitude-based detection with configurable sensitivity thresholds
- **Background Processing**: Continues monitoring even when the app is minimized
- **Instant Response**: Triggers immediate alerts when a fall is detected

### Emergency Response System

- **Automatic SMS Alerts**: Sends emergency messages with GPS coordinates to predefined contacts
- **Audio Alarms**: Plays loud alarm sounds to attract attention
- **Visual Alerts**: Activates flashlight for increased visibility
- **Vibration Feedback**: Uses vibration patterns to alert the user
- **Confirmation Dialog**: 30-second countdown allowing users to cancel false alarms

### Location Services

- **GPS Tracking**: Captures precise location coordinates when falls occur
- **Background Location**: Maintains location services for emergency situations
- **Location Permissions**: Comprehensive permission handling for location access

### User Interface

- **Permission Management**: Guided setup for all required permissions
- **Settings Configuration**: Adjustable sensitivity, emergency contacts, and alert preferences
- **Status Dashboard**: Real-time system status monitoring
- **Contact Management**: Easy emergency contact configuration

## 📱 Screenshots

_Add screenshots of your app here_

## 🛠 Installation

### Prerequisites

- Flutter SDK (3.8.0 or later)
- Android SDK
- Physical Android device (sensors required for testing)

### Build Steps

1. **Clone the repository**

   ```bash
   git clone <repository-url>
   cd fall_detection_app
   ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Build for Android**

   ```bash
   flutter build apk --debug
   ```

4. **Install on device**
   ```bash
   flutter install
   ```

## 🔧 Configuration

### Required Permissions

The app requires the following permissions:

- **Location (Always)**: For GPS coordinates in emergency situations
- **SMS**: To send emergency text messages
- **Camera**: For flashlight functionality
- **Microphone**: For audio alerts
- **Sensors**: For accelerometer and gyroscope access
- **Background Processing**: For continuous monitoring

### Emergency Contacts Setup

1. Open the app and navigate to Settings
2. Add emergency contact phone numbers
3. Configure emergency message text
4. Test SMS functionality

### Sensitivity Adjustment

- **Low (20-40%)**: Fewer false positives, may miss minor falls
- **Medium (40-60%)**: Balanced detection (recommended)
- **High (60-80%)**: More sensitive, may trigger false alarms

## 🧪 Testing

### Safe Testing Methods

⚠️ **Never test by actually falling!** Use these safe methods:

1. **Phone Movement Test**

   - Hold phone firmly
   - Create sudden downward motions (simulate drop but catch it)
   - Make sharp direction changes

2. **Vibration Test**

   - Shake phone vigorously in different directions
   - Create sudden starts and stops

3. **System Test**
   - Use the built-in system test in the status dashboard
   - Verify all components are working

### Expected Behavior

When a fall is detected:

1. Immediate vibration pattern
2. Flashlight activation
3. Alarm sound plays
4. 30-second confirmation dialog appears
5. If not cancelled, SMS sent to emergency contacts
6. GPS coordinates included in message

## 📱 Usage

### Daily Operation

1. **Start Monitoring**: Open app and tap "Start Fall Detection"
2. **Background Operation**: App continues monitoring when minimized
3. **Emergency Response**: Automatic alerts when falls detected
4. **Manual Testing**: Use system test features to verify functionality

### Emergency Situation

1. Fall detected automatically
2. User has 30 seconds to cancel false alarm
3. Emergency contacts receive SMS with location
4. Audio and visual alerts continue until acknowledged

## 🔧 Technical Details

### Architecture

- **Services Layer**: Fall detection, location, emergency response
- **UI Layer**: Flutter Material Design interface
- **Background Processing**: Flutter Background Service
- **Data Persistence**: SharedPreferences for settings

### Key Dependencies

- `sensors_plus`: Accelerometer and gyroscope data
- `geolocator`: GPS location services
- `permission_handler`: Runtime permission management
- `flutter_background_service`: Background processing
- `audioplayers`: Emergency sound alerts
- `torch_light`: Flashlight control
- `vibration`: Haptic feedback

### Fall Detection Algorithm

```dart
// Simplified version
double magnitude = sqrt(x² + y² + z²);
if (magnitude > threshold) {
    // Potential fall detected
    triggerEmergencyResponse();
}
```

## 🚨 Limitations

### Current Limitations

- **Battery Usage**: Continuous sensor monitoring impacts battery life
- **False Positives**: May trigger during vigorous activities
- **GPS Accuracy**: Location may be imprecise indoors
- **SMS Dependency**: Requires cellular service for emergency messages

### Planned Improvements

- Machine learning-based fall detection
- Integration with wearable devices
- Cloud-based monitoring dashboard
- Enhanced activity recognition
- Battery optimization features

## 🛡 Safety Considerations

### Important Notes

- This app is a safety aid, not a medical device
- Always test thoroughly before relying on the system
- Ensure emergency contacts are aware of the system
- Regular testing and maintenance required
- Not suitable as the sole safety mechanism

### Best Practices

- Keep device charged and accessible
- Test monthly with emergency contacts
- Update emergency contact information regularly
- Adjust sensitivity based on user activity level
- Ensure reliable cellular service coverage

## 🤝 Contributing

### Development Setup

1. Fork the repository
2. Create a feature branch
3. Make changes and test thoroughly
4. Submit a pull request

### Areas for Contribution

- Enhanced fall detection algorithms
- UI/UX improvements
- Battery optimization
- Additional emergency response features
- Documentation improvements

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Support

For support and questions:

- Create an issue in the repository
- Review the [Testing Guide](TESTING_GUIDE.md)
- Check the troubleshooting section

## 🔄 Version History

### Version 1.0.0

- Initial release
- Basic fall detection using accelerometer
- Emergency SMS functionality
- GPS location integration
- Background service implementation
- Permission management system

---

**⚠️ Disclaimer**: This application is provided as-is for educational and safety assistance purposes. It should not be relied upon as the sole means of emergency detection or response. Always ensure you have alternative safety measures in place.
