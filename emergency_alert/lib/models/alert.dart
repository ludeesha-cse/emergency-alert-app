enum AlertType {
  fall,
  impact,
  panicButton,
  inactivity,
  medicalEmergency,
  custom,
  manual,
}

enum AlertSeverity { low, medium, high, critical }

enum AlertStatus { triggered, sent, acknowledged, resolved, cancelled, failed }

class Alert {
  final String id;
  final AlertType type;
  final AlertSeverity severity;
  final AlertStatus status;
  final DateTime timestamp;
  final String? customMessage;
  final Map<String, dynamic>? sensorData;
  final double? latitude;
  final double? longitude;
  final String? address;
  final List<String> sentToContacts;
  final DateTime? resolvedAt;
  final String? resolvedBy;

  Alert({
    required this.id,
    required this.type,
    required this.severity,
    required this.status,
    required this.timestamp,
    this.customMessage,
    this.sensorData,
    this.latitude,
    this.longitude,
    this.address,
    this.sentToContacts = const [],
    this.resolvedAt,
    this.resolvedBy,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id'],
      type: AlertType.values[json['type']],
      severity: AlertSeverity.values[json['severity']],
      status: AlertStatus.values[json['status']],
      timestamp: DateTime.parse(json['timestamp']),
      customMessage: json['customMessage'],
      sensorData: json['sensorData'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      address: json['address'],
      sentToContacts: List<String>.from(json['sentToContacts'] ?? []),
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.parse(json['resolvedAt'])
          : null,
      resolvedBy: json['resolvedBy'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.index,
      'severity': severity.index,
      'status': status.index,
      'timestamp': timestamp.toIso8601String(),
      'customMessage': customMessage,
      'sensorData': sensorData,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'sentToContacts': sentToContacts,
      'resolvedAt': resolvedAt?.toIso8601String(),
      'resolvedBy': resolvedBy,
    };
  }

  Alert copyWith({
    String? id,
    AlertType? type,
    AlertSeverity? severity,
    AlertStatus? status,
    DateTime? timestamp,
    String? customMessage,
    Map<String, dynamic>? sensorData,
    double? latitude,
    double? longitude,
    String? address,
    List<String>? sentToContacts,
    DateTime? resolvedAt,
    String? resolvedBy,
  }) {
    return Alert(
      id: id ?? this.id,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      customMessage: customMessage ?? this.customMessage,
      sensorData: sensorData ?? this.sensorData,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      sentToContacts: sentToContacts ?? this.sentToContacts,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolvedBy: resolvedBy ?? this.resolvedBy,
    );
  }
  String get alertTypeDescription {
    switch (type) {
      case AlertType.fall:
        return 'Fall Detected';
      case AlertType.impact:
        return 'Impact Detected';
      case AlertType.panicButton:
        return 'Panic Button';
      case AlertType.inactivity:
        return 'Inactivity Alert';
      case AlertType.medicalEmergency:
        return 'Medical Emergency';
      case AlertType.custom:
        return 'Custom Alert';
      case AlertType.manual:
        return 'Manual Emergency';
    }
  }

  String get severityDescription {
    switch (severity) {
      case AlertSeverity.low:
        return 'Low';
      case AlertSeverity.medium:
        return 'Medium';
      case AlertSeverity.high:
        return 'High';
      case AlertSeverity.critical:
        return 'Critical';
    }
  }

  @override
  String toString() {
    return 'Alert(id: $id, type: $type, severity: $severity, status: $status, timestamp: $timestamp)';
  }
}
