import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service to detect loud sounds using the microphone in the background.
class SoundDetectionService {
  static final SoundDetectionService _instance =
      SoundDetectionService._internal();
  factory SoundDetectionService() => _instance;
  SoundDetectionService._internal();

  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isDetecting = false;
  double _thresholdDb = 70.0;
  StreamSubscription? _recorderSubscription;
  final StreamController<void> _onLoudSoundController =
      StreamController.broadcast();

  /// Stream that emits an event when a loud sound is detected.
  Stream<void> get onLoudSound => _onLoudSoundController.stream;

  /// Returns whether sound detection is enabled.
  bool get isDetecting => _isDetecting;

  /// Set the loudness threshold in dB (default 70).
  set thresholdDb(double value) => _thresholdDb = value;
  double get thresholdDb => _thresholdDb;

  /// Request microphone permission. Returns true if granted.
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Start sound detection in the background.
  Future<bool> startDetection({double? thresholdDb}) async {
    if (_isDetecting) return true;
    if (thresholdDb != null) _thresholdDb = thresholdDb;

    final hasPermission = await requestMicrophonePermission();
    if (!hasPermission) {
      debugPrint('Microphone permission denied.');
      return false;
    }

    await _recorder.openRecorder(); // Correct for flutter_sound 9.x
    await _recorder.startRecorder(
      toStream: null, // No file output, just for amplitude monitoring
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: 44100,
    );

    _isDetecting = true;
    _recorderSubscription = _recorder.onProgress?.listen((event) {
      if (!_isDetecting) return;
      final amplitude = event.decibels ?? 0.0;
      if (amplitude >= _thresholdDb) {
        _onLoudSoundController.add(null);
      }
    });
    return true;
  }

  /// Stop sound detection.
  Future<void> stopDetection() async {
    if (!_isDetecting) return;
    _isDetecting = false;
    await _recorderSubscription?.cancel();
    await _recorder.stopRecorder();
    await _recorder.closeRecorder(); // Correct for flutter_sound 9.x
  }

  /// Toggle sound detection on/off.
  Future<void> toggleDetection() async {
    if (_isDetecting) {
      await stopDetection();
    } else {
      await startDetection();
    }
  }

  /// Dispose resources.
  void dispose() {
    _recorderSubscription?.cancel();
    _onLoudSoundController.close();
  }
}
