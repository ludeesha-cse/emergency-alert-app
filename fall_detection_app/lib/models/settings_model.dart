// A model class to store app settings and emergency contacts
class AppSettings {
  // Fall detection sensitivity (0.0-1.0)
  double fallDetectionSensitivity;

  // Emergency contacts list
  List<EmergencyContact> emergencyContacts;

  // Whether to play alarm sound when fall is detected
  bool playAlarmOnFall;

  // Whether to flash lights when fall is detected
  bool flashLightOnFall;

  // Whether to vibrate when fall is detected
  bool vibrateOnFall;

  // Custom emergency message
  String emergencyMessage;

  // Default constructor
  AppSettings({
    this.fallDetectionSensitivity = 0.5,
    this.emergencyContacts = const [],
    this.playAlarmOnFall = true,
    this.flashLightOnFall = true,
    this.vibrateOnFall = true,
    this.emergencyMessage =
        "I've fallen and need assistance. This is my current location:",
  });

  // Copy constructor with optional named parameters
  AppSettings copyWith({
    double? fallDetectionSensitivity,
    List<EmergencyContact>? emergencyContacts,
    bool? playAlarmOnFall,
    bool? flashLightOnFall,
    bool? vibrateOnFall,
    String? emergencyMessage,
  }) {
    return AppSettings(
      fallDetectionSensitivity:
          fallDetectionSensitivity ?? this.fallDetectionSensitivity,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      playAlarmOnFall: playAlarmOnFall ?? this.playAlarmOnFall,
      flashLightOnFall: flashLightOnFall ?? this.flashLightOnFall,
      vibrateOnFall: vibrateOnFall ?? this.vibrateOnFall,
      emergencyMessage: emergencyMessage ?? this.emergencyMessage,
    );
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'fallDetectionSensitivity': fallDetectionSensitivity,
      'emergencyContacts': emergencyContacts
          .map((contact) => contact.toJson())
          .toList(),
      'playAlarmOnFall': playAlarmOnFall,
      'flashLightOnFall': flashLightOnFall,
      'vibrateOnFall': vibrateOnFall,
      'emergencyMessage': emergencyMessage,
    };
  }

  // Create from JSON data
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      fallDetectionSensitivity: json['fallDetectionSensitivity'] ?? 0.5,
      emergencyContacts:
          (json['emergencyContacts'] as List?)
              ?.map((item) => EmergencyContact.fromJson(item))
              .toList() ??
          [],
      playAlarmOnFall: json['playAlarmOnFall'] ?? true,
      flashLightOnFall: json['flashLightOnFall'] ?? true,
      vibrateOnFall: json['vibrateOnFall'] ?? true,
      emergencyMessage:
          json['emergencyMessage'] ??
          "I've fallen and need assistance. This is my current location:",
    );
  }
}

// Model for emergency contacts
class EmergencyContact {
  final String name;
  final String phoneNumber;

  const EmergencyContact({required this.name, required this.phoneNumber});

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {'name': name, 'phoneNumber': phoneNumber};
  }

  // Create from JSON
  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: json['name'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
    );
  }
}
