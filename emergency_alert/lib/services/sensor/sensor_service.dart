import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import '../../models/sensor_data.dart';
import '../../utils/constants.dart';

class SensorService {
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;
  SensorService._internal();

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;

  final StreamController<SensorData> _sensorDataController =
      StreamController<SensorData>.broadcast();
  final StreamController<bool> _fallDetectedController =
      StreamController<bool>.broadcast();
  final StreamController<bool> _impactDetectedController =
      StreamController<bool>.broadcast();

  Stream<SensorData> get sensorDataStream => _sensorDataController.stream;
  Stream<bool> get fallDetectedStream => _fallDetectedController.stream;
  Stream<bool> get impactDetectedStream => _impactDetectedController.stream;

  AccelerometerEvent? _lastAccelerometerEvent;
  GyroscopeEvent? _lastGyroscopeEvent;
  final List<double> _accelerometerMagnitudes = [];
  final List<DateTime> _impactTimestamps = [];

  bool _isMonitoring = false;
  bool _fallDetectionEnabled = true;
  bool _impactDetectionEnabled = true;

  bool get isMonitoring => _isMonitoring;
  bool get fallDetectionEnabled => _fallDetectionEnabled;
  bool get impactDetectionEnabled => _impactDetectionEnabled;

  void setFallDetectionEnabled(bool enabled) {
    _fallDetectionEnabled = enabled;
  }

  void setImpactDetectionEnabled(bool enabled) {
    _impactDetectionEnabled = enabled;
  }

  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    _isMonitoring = true;

    // Start accelerometer monitoring
    _accelerometerSubscription =
        accelerometerEventStream(
          samplingPeriod: Duration(
            milliseconds: 1000 ~/ SensorConstants.accelerometerSensitivity,
          ),
        ).listen((AccelerometerEvent event) {
          _lastAccelerometerEvent = event;
          _processAccelerometerData(event);
        });

    // Start gyroscope monitoring
    _gyroscopeSubscription =
        gyroscopeEventStream(
          samplingPeriod: Duration(
            milliseconds: 1000 ~/ SensorConstants.gyroscopeSensitivity,
          ),
        ).listen((GyroscopeEvent event) {
          _lastGyroscopeEvent = event;
          _processGyroscopeData(event);
        });
  }

  void _processAccelerometerData(AccelerometerEvent event) {
    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    // Add to magnitude buffer
    _accelerometerMagnitudes.add(magnitude);
    if (_accelerometerMagnitudes.length > AppConstants.sensorBufferSize) {
      _accelerometerMagnitudes.removeAt(0);
    }

    // Create sensor data with current readings
    if (_lastGyroscopeEvent != null) {
      final sensorData = SensorData(
        timestamp: DateTime.now(),
        accelerometerX: event.x,
        accelerometerY: event.y,
        accelerometerZ: event.z,
        gyroscopeX: _lastGyroscopeEvent!.x,
        gyroscopeY: _lastGyroscopeEvent!.y,
        gyroscopeZ: _lastGyroscopeEvent!.z,
        magnitude: magnitude,
      );

      _sensorDataController.add(sensorData);
    }

    // Fall detection algorithm
    if (_fallDetectionEnabled) {
      _detectFall(magnitude);
    }

    // Impact detection algorithm
    if (_impactDetectionEnabled) {
      _detectImpact(magnitude);
    }
  }

  void _processGyroscopeData(GyroscopeEvent event) {
    // Gyroscope data is processed with accelerometer data
    // Additional gyroscope-specific processing can be added here
  }

  void _detectFall(double magnitude) {
    // Fall detection using free fall + impact algorithm

    // Check for free fall (low acceleration)
    if (magnitude < SensorConstants.freeFallThreshold) {
      // Start monitoring for impact after free fall
      Timer(Duration(milliseconds: SensorConstants.freeFallDurationMs), () {
        _checkForImpactAfterFreeFall();
      });
    }
  }

  void _checkForImpactAfterFreeFall() {
    if (_accelerometerMagnitudes.isNotEmpty) {
      final recentMagnitude = _accelerometerMagnitudes.last;

      // Check for impact after free fall
      if (recentMagnitude > AppConstants.fallDetectionThreshold) {
        _fallDetectedController.add(true);
      }
    }
  }

  void _detectImpact(double magnitude) {
    final now = DateTime.now();

    // Remove old impact timestamps (older than 1 second)
    _impactTimestamps.removeWhere(
      (timestamp) => now.difference(timestamp).inMilliseconds > 1000,
    );

    // Check if current magnitude exceeds impact threshold
    if (magnitude > AppConstants.impactDetectionThreshold) {
      _impactTimestamps.add(now);

      // If multiple impacts in short time, trigger impact detection
      if (_impactTimestamps.length >= 2) {
        _impactDetectedController.add(true);
      }
    }
  }

  Future<void> stopMonitoring() async {
    if (!_isMonitoring) return;

    _isMonitoring = false;

    await _accelerometerSubscription?.cancel();
    await _gyroscopeSubscription?.cancel();

    _accelerometerSubscription = null;
    _gyroscopeSubscription = null;
  }

  SensorData? getCurrentSensorData() {
    if (_lastAccelerometerEvent == null || _lastGyroscopeEvent == null) {
      return null;
    }

    final magnitude = sqrt(
      _lastAccelerometerEvent!.x * _lastAccelerometerEvent!.x +
          _lastAccelerometerEvent!.y * _lastAccelerometerEvent!.y +
          _lastAccelerometerEvent!.z * _lastAccelerometerEvent!.z,
    );

    return SensorData(
      timestamp: DateTime.now(),
      accelerometerX: _lastAccelerometerEvent!.x,
      accelerometerY: _lastAccelerometerEvent!.y,
      accelerometerZ: _lastAccelerometerEvent!.z,
      gyroscopeX: _lastGyroscopeEvent!.x,
      gyroscopeY: _lastGyroscopeEvent!.y,
      gyroscopeZ: _lastGyroscopeEvent!.z,
      magnitude: magnitude,
    );
  }

  void dispose() {
    stopMonitoring();
    _sensorDataController.close();
    _fallDetectedController.close();
    _impactDetectedController.close();
  }
}
