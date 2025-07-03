import 'dart:async';
import 'package:torch_light/torch_light.dart';

class FlashlightService {
  static final FlashlightService _instance = FlashlightService._internal();
  factory FlashlightService() => _instance;
  FlashlightService._internal();

  bool _isFlashlightOn = false;
  bool _isFlashing = false;
  Timer? _flashTimer;

  bool get isFlashlightOn => _isFlashlightOn;
  bool get isFlashing => _isFlashing;

  Future<bool> isAvailable() async {
    try {
      return await TorchLight.isTorchAvailable();
    } catch (e) {
      print('Error checking flashlight availability: $e');
      return false;
    }
  }

  Future<bool> turnOn() async {
    try {
      if (!await isAvailable()) {
        return false;
      }

      await TorchLight.enableTorch();
      _isFlashlightOn = true;
      return true;
    } catch (e) {
      print('Error turning on flashlight: $e');
      return false;
    }
  }

  Future<bool> turnOff() async {
    try {
      await TorchLight.disableTorch();
      _isFlashlightOn = false;
      return true;
    } catch (e) {
      print('Error turning off flashlight: $e');
      return false;
    }
  }

  Future<bool> toggle() async {
    if (_isFlashlightOn) {
      return await turnOff();
    } else {
      return await turnOn();
    }
  }

  Future<void> startEmergencyFlashing({
    int durationSeconds = 30,
    int flashIntervalMs = 500,
  }) async {
    try {
      if (!await isAvailable()) {
        return;
      }

      if (_isFlashing) {
        await stopFlashing();
      }

      _isFlashing = true;

      // Create flashing pattern
      Timer.periodic(Duration(milliseconds: flashIntervalMs), (timer) async {
        if (!_isFlashing) {
          timer.cancel();
          return;
        }

        await toggle();
      });

      // Stop flashing after duration
      _flashTimer = Timer(Duration(seconds: durationSeconds), () {
        stopFlashing();
      });
    } catch (e) {
      print('Error starting emergency flashing: $e');
      _isFlashing = false;
    }
  }

  Future<void> startSOSFlashing({int durationSeconds = 60}) async {
    try {
      if (!await isAvailable()) {
        return;
      }

      if (_isFlashing) {
        await stopFlashing();
      }

      _isFlashing = true;

      // SOS pattern: ... --- ... (short-short-short long-long-long short-short-short)
      await _flashSOSPattern();

      // Repeat SOS pattern for duration
      Timer.periodic(Duration(seconds: 3), (timer) async {
        if (!_isFlashing) {
          timer.cancel();
          return;
        }

        await _flashSOSPattern();
      });

      // Stop flashing after duration
      _flashTimer = Timer(Duration(seconds: durationSeconds), () {
        stopFlashing();
      });
    } catch (e) {
      print('Error starting SOS flashing: $e');
      _isFlashing = false;
    }
  }

  Future<void> _flashSOSPattern() async {
    // Short flashes (S)
    for (int i = 0; i < 3; i++) {
      await turnOn();
      await Future.delayed(Duration(milliseconds: 200));
      await turnOff();
      await Future.delayed(Duration(milliseconds: 200));
    }

    await Future.delayed(Duration(milliseconds: 400));

    // Long flashes (O)
    for (int i = 0; i < 3; i++) {
      await turnOn();
      await Future.delayed(Duration(milliseconds: 600));
      await turnOff();
      await Future.delayed(Duration(milliseconds: 200));
    }

    await Future.delayed(Duration(milliseconds: 400));

    // Short flashes (S)
    for (int i = 0; i < 3; i++) {
      await turnOn();
      await Future.delayed(Duration(milliseconds: 200));
      await turnOff();
      await Future.delayed(Duration(milliseconds: 200));
    }
  }

  Future<void> stopFlashing() async {
    try {
      _flashTimer?.cancel();
      _flashTimer = null;
      _isFlashing = false;

      if (_isFlashlightOn) {
        await turnOff();
      }
    } catch (e) {
      print('Error stopping flashing: $e');
    }
  }

  Future<bool> testFlashlight() async {
    try {
      if (!await isAvailable()) {
        return false;
      }

      await turnOn();
      await Future.delayed(Duration(milliseconds: 500));
      await turnOff();
      return true;
    } catch (e) {
      print('Flashlight test failed: $e');
      return false;
    }
  }

  void dispose() {
    stopFlashing();
    if (_isFlashlightOn) {
      turnOff();
    }
  }
}
