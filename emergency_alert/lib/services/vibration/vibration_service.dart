import 'dart:async';
import 'package:vibration/vibration.dart';
import '../logger/logger_service.dart';

class VibrationService {
  static final VibrationService _instance = VibrationService._internal();
  factory VibrationService() => _instance;
  VibrationService._internal();

  bool _isVibrating = false;
  Timer? _vibrationTimer;

  bool get isVibrating => _isVibrating;
  Future<bool> hasVibrator() async {
    try {
      return await Vibration.hasVibrator();
    } catch (e) {
      LoggerService.error('Error checking vibrator availability', e);
      return false;
    }
  }

  Future<bool> hasAmplitudeControl() async {
    try {
      return await Vibration.hasAmplitudeControl();
    } catch (e) {
      LoggerService.error('Error checking amplitude control', e);
      return false;
    }
  }

  Future<void> vibrateEmergency({int durationSeconds = 30}) async {
    try {
      if (!await hasVibrator()) {
        return;
      }

      if (_isVibrating) {
        await stopVibration();
      }

      _isVibrating = true;
      // Start emergency vibration pattern
      await _startPatternVibration(
        [0, 1000, 500, 1000, 500, 1000], // Emergency pattern: long-short-long
        durationSeconds,
      );
    } catch (e) {
      LoggerService.error('Error in emergency vibration', e);
      _isVibrating = false;
    }
  }

  Future<void> vibrateAlert() async {
    try {
      if (!await hasVibrator()) {
        return;
      }
      await Vibration.vibrate(
        pattern: [0, 500, 250, 500], // Alert pattern: medium-short
      );
    } catch (e) {
      LoggerService.error('Error in alert vibration', e);
    }
  }

  Future<void> vibrateNotification() async {
    try {
      if (!await hasVibrator()) {
        return;
      }
      await Vibration.vibrate(
        pattern: [0, 200, 100, 200], // Notification pattern: short-very short
      );
    } catch (e) {
      LoggerService.error('Error in notification vibration', e);
    }
  }

  Future<void> vibrateSOS({int durationSeconds = 60}) async {
    try {
      if (!await hasVibrator()) {
        return;
      }

      if (_isVibrating) {
        await stopVibration();
      }

      _isVibrating = true;

      // SOS pattern: ... --- ... (short-short-short long-long-long short-short-short)
      const sosPattern = [
        0, 200, 200, 200, 200, 200, 400, // S (short-short-short)
        600, 200, 600, 200, 600, 400, // O (long-long-long)
        200, 200, 200, 200, 200, 1000, // S (short-short-short)
      ];

      await _startPatternVibration(sosPattern, durationSeconds);
    } catch (e) {
      LoggerService.error('Error in SOS vibration', e);
      _isVibrating = false;
    }
  }

  Future<void> vibrateCustom({
    int duration = 500,
    List<int>? pattern,
    int amplitude = 255,
  }) async {
    try {
      if (!await hasVibrator()) {
        return;
      }

      if (pattern != null) {
        await Vibration.vibrate(pattern: pattern);
      } else {
        if (await hasAmplitudeControl()) {
          await Vibration.vibrate(duration: duration, amplitude: amplitude);
        } else {
          await Vibration.vibrate(duration: duration);
        }
      }
    } catch (e) {
      LoggerService.error('Error in custom vibration', e);
    }
  }

  Future<void> _startPatternVibration(
    List<int> pattern,
    int durationSeconds,
  ) async {
    // Calculate pattern duration
    final patternDuration = pattern.reduce((a, b) => a + b);
    final cycles = (durationSeconds * 1000 / patternDuration).ceil();

    // Repeat pattern for specified duration
    for (int i = 0; i < cycles && _isVibrating; i++) {
      await Vibration.vibrate(pattern: pattern);

      // Wait for pattern to complete
      await Future.delayed(Duration(milliseconds: patternDuration));
    }

    _isVibrating = false;
  }

  Future<void> stopVibration() async {
    try {
      LoggerService.info('Stopping vibration');
      _vibrationTimer?.cancel();
      _vibrationTimer = null;
      _isVibrating = false;

      await Vibration.cancel();
      LoggerService.info('Vibration stopped');
    } catch (e) {
      LoggerService.error('Error stopping vibration', e);
    }
  }

  Future<bool> testVibration() async {
    try {
      if (!await hasVibrator()) {
        return false;
      }

      await vibrateNotification();
      return true;
    } catch (e) {
      LoggerService.error('Vibration test failed', e);
      return false;
    }
  }

  void dispose() {
    stopVibration();
  }
}
