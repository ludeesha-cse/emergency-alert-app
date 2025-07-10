import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/sensor_data.dart';
import '../../utils/constants.dart';
import '../logger/logger_service.dart';

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

  // Additional variables for improved impact detection
  double _baselineMagnitude = SensorConstants.earthGravity;
  DateTime? _lastImpactTime;
  int _consecutiveHighReadings = 0;
  final List<double> _recentMagnitudes = [];
  bool _isMonitoring = false;
  bool _fallDetectionEnabled = true;
  bool _impactDetectionEnabled = true;

  // User-configurable sampling rates
  int _accelerometerSamplingRate = SensorConstants.accelerometerSensitivity;
  int _gyroscopeSamplingRate = SensorConstants.gyroscopeSamplingRate;

  bool get isMonitoring => _isMonitoring;
  bool get fallDetectionEnabled => _fallDetectionEnabled;
  bool get impactDetectionEnabled => _impactDetectionEnabled;

  void setFallDetectionEnabled(bool enabled) {
    _fallDetectionEnabled = enabled;
  }

  void setImpactDetectionEnabled(bool enabled) {
    _impactDetectionEnabled = enabled;
  }

  /// Load user-configurable sampling rates from SharedPreferences
  Future<void> _loadSamplingRates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accelerometerSamplingRate =
          prefs.getInt('accelerometer_sampling_rate') ??
          SensorConstants.accelerometerSensitivity;
      _gyroscopeSamplingRate =
          prefs.getInt('gyroscope_sampling_rate') ??
          SensorConstants.gyroscopeSamplingRate;
    } catch (e) {
      // If there's an error loading preferences, use default values
      _accelerometerSamplingRate = SensorConstants.accelerometerSensitivity;
      _gyroscopeSamplingRate = SensorConstants.gyroscopeSamplingRate;
    }
  }

  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    // Load user-configurable sampling rates
    await _loadSamplingRates();

    _isMonitoring = true;

    // Start accelerometer monitoring
    _accelerometerSubscription =
        accelerometerEventStream(
          samplingPeriod: Duration(
            milliseconds: 1000 ~/ _accelerometerSamplingRate,
          ),
        ).listen((AccelerometerEvent event) {
          _lastAccelerometerEvent = event;
          _processAccelerometerData(event);
        });

    // Start gyroscope monitoring
    _gyroscopeSubscription =
        gyroscopeEventStream(
          samplingPeriod: Duration(
            milliseconds: 1000 ~/ _gyroscopeSamplingRate,
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

    // Update recent magnitudes for baseline calculation
    _recentMagnitudes.add(magnitude);
    if (_recentMagnitudes.length > 20) {
      _recentMagnitudes.removeAt(0);
    }

    // Calculate baseline magnitude (moving average excluding outliers)
    if (_recentMagnitudes.length >= 10) {
      final sortedMagnitudes = [..._recentMagnitudes]..sort();
      // Use median of middle 50% to exclude outliers
      final startIndex = (sortedMagnitudes.length * 0.25).floor();
      final endIndex = (sortedMagnitudes.length * 0.75).ceil();
      final middleMagnitudes = sortedMagnitudes.sublist(startIndex, endIndex);
      _baselineMagnitude =
          middleMagnitudes.reduce((a, b) => a + b) / middleMagnitudes.length;
    }

    // Check for impact cooldown period
    if (_lastImpactTime != null &&
        now.difference(_lastImpactTime!).inMilliseconds <
            SensorConstants.impactCooldownMs) {
      return;
    }

    // Calculate magnitude change from baseline
    final magnitudeChange = (magnitude - _baselineMagnitude).abs();

    // Additional check: ensure device is actually moving (check gyroscope)
    bool isDeviceMoving = false;
    if (_lastGyroscopeEvent != null) {
      final gyroMagnitude = sqrt(
        _lastGyroscopeEvent!.x * _lastGyroscopeEvent!.x +
            _lastGyroscopeEvent!.y * _lastGyroscopeEvent!.y +
            _lastGyroscopeEvent!.z * _lastGyroscopeEvent!.z,
      );
      isDeviceMoving = gyroMagnitude > SensorConstants.gyroscopeSensitivity;
    }

    // Check if magnitude change exceeds threshold AND device is moving
    if (magnitudeChange > AppConstants.impactDetectionThreshold &&
        isDeviceMoving) {
      _consecutiveHighReadings++;

      // Require multiple consecutive high readings to confirm impact
      if (_consecutiveHighReadings >= SensorConstants.impactConfirmationCount) {
        // Remove old impact timestamps (older than 2 seconds)
        _impactTimestamps.removeWhere(
          (timestamp) =>
              now.difference(timestamp).inMilliseconds >
              SensorConstants.impactCooldownMs,
        );

        _impactTimestamps.add(now);
        _lastImpactTime = now;
        _consecutiveHighReadings = 0;

        // Trigger impact detection
        LoggerService.debug(
          'Impact detected: magnitude=$magnitude, baseline=$_baselineMagnitude, change=$magnitudeChange',
        );
        _impactDetectedController.add(true);
      }
    } else {
      // Reset consecutive high readings if magnitude is normal
      if (_consecutiveHighReadings > 0) {
        _consecutiveHighReadings--;
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

    // Reset impact detection variables
    _impactTimestamps.clear();
    _recentMagnitudes.clear();
    _lastImpactTime = null;
    _consecutiveHighReadings = 0;
    _baselineMagnitude = SensorConstants.earthGravity;
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

  /// Calibrate the sensor baseline when device is stationary
  void calibrateBaseline() {
    if (_recentMagnitudes.length >= 5) {
      _baselineMagnitude =
          _recentMagnitudes.reduce((a, b) => a + b) / _recentMagnitudes.length;
      LoggerService.info('Baseline calibrated to: $_baselineMagnitude');
    }
  }

  /// Get current acceleration magnitude relative to baseline
  double getCurrentMagnitudeChange() {
    if (_lastAccelerometerEvent == null) return 0.0;

    final magnitude = sqrt(
      _lastAccelerometerEvent!.x * _lastAccelerometerEvent!.x +
          _lastAccelerometerEvent!.y * _lastAccelerometerEvent!.y +
          _lastAccelerometerEvent!.z * _lastAccelerometerEvent!.z,
    );

    return (magnitude - _baselineMagnitude).abs();
  }

  /// Restart monitoring with updated settings (e.g., new sampling rates)
  Future<void> restartMonitoringWithNewSettings() async {
    if (_isMonitoring) {
      await stopMonitoring();
      await startMonitoring();
    }
  }
}
