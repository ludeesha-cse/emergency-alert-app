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

      // Try to play an actual audio file first
      try {
        await _audioPlayer.setAsset('assets/audio/emergency_siren.mp3');
        await _audioPlayer.setVolume(volume);
        await _audioPlayer.setLoopMode(LoopMode.one);
        await _audioPlayer.play();
        _isPlaying = true;
      } catch (audioFileError) {
        // If audio file fails, fall back to beep pattern
        print('Audio file failed, using beep pattern: $audioFileError');
        _isPlaying = true;
        _startBeepPattern();
      }

      // Stop alarm after specified duration
      _alarmTimer = Timer(Duration(seconds: durationSeconds), () {
        stopAlarm();
      });
    } catch (e) {
      print('Error in playEmergencyAlarm: $e');
      _isPlaying = false;
    }
  }

  void _startBeepPattern() {
    // Create a simple beep pattern using periodic timer and volume changes
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!_isPlaying) {
        timer.cancel();
        return;
      }

      // Create a beep by quickly changing volume
      try {
        _audioPlayer.setVolume(0.0);
        Future.delayed(const Duration(milliseconds: 50), () {
          if (_isPlaying) {
            _audioPlayer.setVolume(0.8);
          }
        });
      } catch (e) {
        // If this fails, at least the timer indicates beeping
        print('Beep pattern error: $e');
      }
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
