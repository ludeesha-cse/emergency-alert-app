// A utility class for fall detection algorithm
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

class FallDetectionAlgorithm {
  // Window size for analyzing sensor data
  static const int _windowSize = 20;

  // Lists to store recent accelerometer and gyroscope readings
  final List<AccelerometerEvent> _accelerometerWindow = [];
  final List<GyroscopeEvent> _gyroscopeWindow = [];

  // Thresholds for fall detection
  final double _accelerationThreshold;
  final double _impactThreshold;
  final double _postureChangeThreshold;

  // Constructor with configurable sensitivity
  FallDetectionAlgorithm({double sensitivity = 0.5})
    : // Adjust thresholds based on sensitivity (0.0-1.0)
      // Lower sensitivity means higher thresholds (fewer false positives)
      _accelerationThreshold = 20.0 - (sensitivity * 5.0),
      _impactThreshold = 30.0 - (sensitivity * 10.0),
      _postureChangeThreshold = 2.5 - (sensitivity * 0.5);

  // Add a new accelerometer reading to the window
  void addAccelerometerEvent(AccelerometerEvent event) {
    _accelerometerWindow.add(event);
    if (_accelerometerWindow.length > _windowSize) {
      _accelerometerWindow.removeAt(0);
    }
  }

  // Add a new gyroscope reading to the window
  void addGyroscopeEvent(GyroscopeEvent event) {
    _gyroscopeWindow.add(event);
    if (_gyroscopeWindow.length > _windowSize) {
      _gyroscopeWindow.removeAt(0);
    }
  }

  // Calculate the magnitude of acceleration
  double _calculateAccelerationMagnitude(AccelerometerEvent event) {
    return sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
  }

  // Calculate the magnitude of angular velocity
  double _calculateGyroscopeMagnitude(GyroscopeEvent event) {
    return sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
  }

  // Calculate standard deviation of values
  double _calculateStandardDeviation(List<double> values) {
    if (values.isEmpty) return 0;

    double sum = 0;
    double mean = values.reduce((a, b) => a + b) / values.length;

    for (final value in values) {
      sum += pow(value - mean, 2);
    }

    return sqrt(sum / values.length);
  }

  // Check if a fall has been detected
  bool detectFall() {
    // Need enough data points
    if (_accelerometerWindow.length < _windowSize ||
        _gyroscopeWindow.length < _windowSize) {
      return false;
    }

    // Extract acceleration magnitudes for analysis
    final accelerationMagnitudes = _accelerometerWindow
        .map(_calculateAccelerationMagnitude)
        .toList();

    // Extract gyroscope magnitudes for analysis
    final gyroscopeMagnitudes = _gyroscopeWindow
        .map(_calculateGyroscopeMagnitude)
        .toList();

    // 1. Check for sudden acceleration (free fall followed by impact)
    final maxAcceleration = accelerationMagnitudes.reduce(
      (a, b) => a > b ? a : b,
    );

    // 2. Check for acceleration variance (indicates significant motion)
    final accelerationStdDev = _calculateStandardDeviation(
      accelerationMagnitudes,
    );

    // 3. Check for posture change using gyroscope
    final maxGyroscope = gyroscopeMagnitudes.reduce((a, b) => a > b ? a : b);

    // Combine these signals to detect a fall
    return maxAcceleration > _impactThreshold &&
        accelerationStdDev > _accelerationThreshold &&
        maxGyroscope > _postureChangeThreshold;
  }

  // Reset the algorithm
  void reset() {
    _accelerometerWindow.clear();
    _gyroscopeWindow.clear();
  }
}
