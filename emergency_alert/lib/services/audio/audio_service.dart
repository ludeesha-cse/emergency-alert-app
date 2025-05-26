import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Timer? _alarmTimer;
  Timer? _beepTimer;

  bool get isPlaying => _isPlaying;

  Future<void> playEmergencyAlarm({
    double volume = 0.8,
    int durationSeconds = 30,
  }) async {
    try {
      if (_isPlaying) {
        await stopAlarm();
      }

      _isPlaying = true;

      // Try to load and play audio file first
      bool audioFileLoaded = await _tryLoadAudioFile(volume);

      if (!audioFileLoaded) {
        // Fallback to system sounds with beep pattern
        print('Using system sound fallback for emergency alarm');
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

  Future<bool> _tryLoadAudioFile(double volume) async {
    try {
      // Try to load the high-priority alarm sound
      await _audioPlayer.setAsset('assets/audio/alarm_high.mp3');
      await _audioPlayer.setVolume(volume);
      await _audioPlayer.setLoopMode(LoopMode.one);
      await _audioPlayer.play();
      print('Successfully loaded and playing audio file');
      return true;
    } catch (e) {
      print('Failed to load audio file: $e');
      return false;
    }
  }

  void _startBeepPattern() {
    // Use system sounds for emergency alarm with more aggressive pattern
    _beepTimer = Timer.periodic(const Duration(milliseconds: 600), (
      timer,
    ) async {
      if (!_isPlaying) {
        timer.cancel();
        return;
      }

      try {
        // Play system alert sound multiple times for emergency
        await SystemSound.play(SystemSoundType.alert);
        await Future.delayed(const Duration(milliseconds: 100));
        await SystemSound.play(SystemSoundType.alert);
        await Future.delayed(const Duration(milliseconds: 100));
        await SystemSound.play(SystemSoundType.alert);

        // Also trigger haptic feedback
        await HapticFeedback.heavyImpact();
      } catch (e) {
        print('Error in beep pattern: $e');
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
      _beepTimer?.cancel();
      _beepTimer = null;

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
    _beepTimer?.cancel();
    _audioPlayer.dispose();
  }
}
