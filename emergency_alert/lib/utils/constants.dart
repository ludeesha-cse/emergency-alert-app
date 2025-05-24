class AppConstants {
  // Sensor thresholds
  static const double fallDetectionThreshold =
      2.5; // G-force threshold for fall detection
  static const double impactDetectionThreshold =
      4.0; // G-force threshold for impact detection
  static const int sensorSamplingRate = 50; // Hz
  static const int sensorBufferSize =
      100; // Number of samples to keep in buffer

  // Location settings
  static const double locationAccuracyThreshold = 100.0; // meters
  static const int locationUpdateInterval = 30; // seconds
  static const double minimumDistanceFilter = 10.0; // meters

  // Alert timing
  static const int alertCountdownSeconds = 30; // Countdown before sending alert
  static const int emergencyResponseTimeout = 300; // 5 minutes in seconds
  static const int retryIntervalSeconds =
      60; // Retry sending alerts every minute
  static const int maxRetryAttempts = 5;

  // Background service
  static const String backgroundServiceTaskName = 'emergency_monitoring';
  static const int backgroundServiceInterval = 15; // minutes
  static const String backgroundServiceNotificationChannelId =
      'emergency_alert_background';
  static const String backgroundServiceNotificationChannelName =
      'Emergency Alert Background Service';

  // Audio settings
  static const List<String> alertSounds = [
    'assets/audio/alarm_high.mp3',
    'assets/audio/alarm_medium.mp3',
    'assets/audio/alarm_low.mp3',
  ];
  static const double defaultAlarmVolume = 0.8;
  static const int alarmDurationSeconds = 10;

  // Vibration patterns (milliseconds: [wait, vibrate, wait, vibrate, ...])
  static const List<int> emergencyVibrationPattern = [
    0,
    1000,
    500,
    1000,
    500,
    1000,
  ];
  static const List<int> alertVibrationPattern = [0, 500, 250, 500];
  static const List<int> notificationVibrationPattern = [0, 200, 100, 200];

  // SMS templates
  static const String emergencyMessage =
      'EMERGENCY ALERT: {name} may need assistance. Last known location: {location}. Time: {timestamp}. Alert type: {alertType}. Please check on them immediately.';

  static const String testMessage =
      'This is a test message from Emergency Alert app. Your contact {name} has added you as an emergency contact.';

  static const String cancelMessage =
      'ALERT CANCELLED: Previous emergency alert for {name} has been cancelled. They are safe.';

  // Database settings
  static const String databaseName = 'emergency_alert.db';
  static const int databaseVersion = 1;

  // Storage keys
  static const String keyEmergencyContacts = 'emergency_contacts';
  static const String keyAlertHistory = 'alert_history';
  static const String keyUserSettings = 'user_settings';
  static const String keyLastLocation = 'last_location';
  static const String keySensorCalibration = 'sensor_calibration';
  static const String keyAppEnabled = 'app_enabled';
  static const String keyFallDetectionEnabled = 'fall_detection_enabled';
  static const String keyImpactDetectionEnabled = 'impact_detection_enabled';
  static const String keyLocationTrackingEnabled = 'location_tracking_enabled';

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double cardElevation = 4.0;
  static const double borderRadius = 8.0;

  // Emergency contact limits
  static const int maxEmergencyContacts = 10;
  static const int maxPrimaryContacts = 3;

  // Inactivity detection
  static const int inactivityThresholdHours = 12;
  static const int checkInReminderHours = 6;

  // Network timeouts
  static const int networkTimeoutSeconds = 30;
  static const int geocodingTimeoutSeconds = 15;
}

class SensorConstants {
  // Accelerometer calibration values
  static const double earthGravity = 9.81; // m/s²
  static const double accelerometerSensitivity =
      0.01; // Minimum detectable change

  // Gyroscope calibration values
  static const double gyroscopeSensitivity = 0.1; // degrees/second
  static const double maxGyroscopeValue = 2000.0; // degrees/second

  // Movement classification thresholds
  static const double walkingThreshold = 1.2;
  static const double runningThreshold = 2.0;
  static const double stationaryThreshold = 0.1;

  // Fall detection algorithm parameters
  static const double freeFallThreshold = 0.5; // G-force
  static const int freeFallDurationMs = 300; // milliseconds
  static const double postImpactThreshold = 2.0; // G-force
  static const int postImpactDurationMs = 1000; // milliseconds
}

class ErrorMessages {
  static const String permissionDenied =
      'Permission denied. Please grant the required permissions in settings.';
  static const String locationUnavailable =
      'Location services are unavailable.';
  static const String smsPermissionRequired =
      'SMS permission is required to send emergency alerts.';
  static const String noEmergencyContacts =
      'No emergency contacts configured. Please add at least one contact.';
  static const String networkError =
      'Network error occurred. Please check your connection.';
  static const String sensorError =
      'Sensor data unavailable. Please check device sensors.';
  static const String backgroundServiceError =
      'Background service could not be started.';
  static const String alertSendFailed =
      'Failed to send emergency alert. Will retry automatically.';
  static const String invalidPhoneNumber = 'Invalid phone number format.';
  static const String contactLimitReached =
      'Maximum number of emergency contacts reached.';
}
