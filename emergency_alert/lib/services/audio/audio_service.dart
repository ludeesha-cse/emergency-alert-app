import 'dart:async';
import 'package:just_audio/just_audio.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Timer? _alarmTimer;

  bool get isPlaying => _isPlaying;

  Future<void> playEmergencyAlarm({
    double volume = 0.8,
    int durationSeconds = 30,
  }) async {
    try {
      if (_isPlaying) {
        await stopAlarm();
      }

      // Use system alarm sound or a default beep pattern
      await _audioPlayer.setVolume(volume);
      await _audioPlayer.setLoopMode(LoopMode.one);

      _isPlaying = true;

      // Create a simple beep pattern as fallback
      _startBeepPattern();

      // Stop alarm after specified duration
      _alarmTimer = Timer(Duration(seconds: durationSeconds), () {
        stopAlarm();
      });
    } catch (e) {
      _isPlaying = false;
    }
  }

  void _startBeepPattern() {
    // Simple implementation - in a real app you'd load audio files
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!_isPlaying) {
        timer.cancel();
      }
      // Beep pattern would go here
    });
  }

  Future<void> playAlertSound({double volume = 0.7}) async {
    try {
      await _audioPlayer.setVolume(volume);
      // Play single beep
    } catch (e) {
      // Handle error
    }
  }

  Future<void> stopAlarm() async {
    try {
      _alarmTimer?.cancel();
      _alarmTimer = null;

      if (_isPlaying) {
        await _audioPlayer.stop();
        _isPlaying = false;
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> stopAllSounds() async {
    await stopAlarm();
  }

  void dispose() {
    stopAllSounds();
    _alarmTimer?.cancel();
    _audioPlayer.dispose();
  }
}
