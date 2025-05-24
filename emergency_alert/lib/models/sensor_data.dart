class SensorData {
  final DateTime timestamp;
  final double accelerometerX;
  final double accelerometerY;
  final double accelerometerZ;
  final double gyroscopeX;
  final double gyroscopeY;
  final double gyroscopeZ;
  final double magnitude;

  SensorData({
    required this.timestamp,
    required this.accelerometerX,
    required this.accelerometerY,
    required this.accelerometerZ,
    required this.gyroscopeX,
    required this.gyroscopeY,
    required this.gyroscopeZ,
    required this.magnitude,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      timestamp: DateTime.parse(json['timestamp']),
      accelerometerX: json['accelerometerX'].toDouble(),
      accelerometerY: json['accelerometerY'].toDouble(),
      accelerometerZ: json['accelerometerZ'].toDouble(),
      gyroscopeX: json['gyroscopeX'].toDouble(),
      gyroscopeY: json['gyroscopeY'].toDouble(),
      gyroscopeZ: json['gyroscopeZ'].toDouble(),
      magnitude: json['magnitude'].toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'accelerometerX': accelerometerX,
      'accelerometerY': accelerometerY,
      'accelerometerZ': accelerometerZ,
      'gyroscopeX': gyroscopeX,
      'gyroscopeY': gyroscopeY,
      'gyroscopeZ': gyroscopeZ,
      'magnitude': magnitude,
    };
  }

  @override
  String toString() {
    return 'SensorData(timestamp: $timestamp, magnitude: $magnitude)';
  }
}

class LocationData {
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
  final double? speed;
  final DateTime timestamp;
  final String? address;

  LocationData({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    this.speed,
    required this.timestamp,
    this.address,
  });

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      altitude: json['altitude']?.toDouble(),
      accuracy: json['accuracy']?.toDouble(),
      speed: json['speed']?.toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
      address: json['address'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'accuracy': accuracy,
      'speed': speed,
      'timestamp': timestamp.toIso8601String(),
      'address': address,
    };
  }

  @override
  String toString() {
    return 'LocationData(lat: $latitude, lng: $longitude, accuracy: $accuracy)';
  }
}
