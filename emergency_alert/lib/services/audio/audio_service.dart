import 'dart:async';
import 'dart:developer' as developer;
import 'package:just_audio/just_audio.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  Timer? _alarmTimer;
  Timer? _beepTimer;

  // Track all pending volume operations so they can be properly cancelled
  final Set<int> _pendingVolumeOperations = {};

  // Track the last time stop was called to prevent race conditions
  int _lastStopTimeMs = 0;

  // Logger helper
  void _log(String message, {String level = 'info'}) {
    developer.log(message, name: 'AudioService', level: _getLogLevel(level));
  }

  int _getLogLevel(String level) {
    switch (level) {
      case 'warning':
        return 900;
      case 'error':
        return 1000;
      case 'debug':
        return 500;
      default:
        return 800; // info
    }
  }

  AudioPlayer _getOrCreatePlayer() {
    try {
      _audioPlayer ??= AudioPlayer();
      return _audioPlayer!;
    } catch (e) {
      _log('Error creating audio player: $e', level: 'error');
      // If player creation fails, set a flag to use fallback only
      throw Exception('Audio player creation failed: $e');
    }
  }

  bool get isPlaying => _isPlaying;

  Future<void> playEmergencyAlarm({
    double volume = 0.8,
    int durationSeconds = 30,
  }) async {
    try {
      _log('Starting emergency alarm...');

      // Make sure any existing audio is fully stopped
      if (_isPlaying) {
        await emergencyReset(); // Use emergency reset for more thorough cleanup
      } else {
        // Even if not playing, force a cleanup first to ensure a clean slate
        await stopAlarm();
      }

      // Clear tracking set just to be absolutely sure
      _pendingVolumeOperations.clear();

      // Create a completely fresh player instance
      try {
        // Dispose any existing player first (should already be null, but double-check)
        if (_audioPlayer != null) {
          try {
            await _audioPlayer!.dispose();
          } catch (e) {
            _log(
              'Warning: Failed to dispose existing player: $e',
              level: 'warning',
            );
          }
          _audioPlayer = null;
        }

        // Create fresh player
        final player = _getOrCreatePlayer();
        await player.setAsset('assets/audio/emergency_siren.mp3');
        await player.setVolume(volume);
        await player.setLoopMode(LoopMode.one);

        // Set playing flag before starting audio
        _isPlaying = true;
        await player.play();
        _log('Audio file playing');
      } catch (audioFileError) {
        // If audio file fails, fall back to beep pattern
        _log(
          'Audio file failed, using beep pattern: $audioFileError',
          level: 'warning',
        );
        _isPlaying = true;
        _startBeepPattern();
      }

      // Stop alarm after specified duration
      _alarmTimer?.cancel(); // Cancel any existing timer
      _alarmTimer = Timer(Duration(seconds: durationSeconds), () {
        stopAlarm();
      });
    } catch (e) {
      _log('Error in playEmergencyAlarm: $e', level: 'error');
      _isPlaying = false;
      // Make sure we reset everything on error
      await emergencyReset();
    }
  }

  void _startBeepPattern() {
    // Create a simple beep pattern using periodic timer
    _log('Starting fallback beep pattern...');

    // Make sure any existing beep timer is cancelled first
    _beepTimer?.cancel();
    _beepTimer = null;

    // Clear any pending volume operations
    _pendingVolumeOperations.clear();

    // Start with a silent player
    _createSilentPlayer();

    _beepTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      // CRITICAL: Check at the beginning of each tick if we should still be playing
      if (!_isPlaying || _audioPlayer == null) {
        _log('Beep pattern stopping - playing flag is false or player is null');
        timer.cancel();
        _beepTimer = null;
        _pendingVolumeOperations.clear(); // Clear on timer cancel
        return;
      }

      // Create a beep by quickly changing volume (if player available)
      try {
        final player = _audioPlayer;
        if (player != null && _isPlaying) {
          // Generate unique ID for this beep cycle
          final int beepId = DateTime.now().millisecondsSinceEpoch;

          // Store reference to the current player to avoid race conditions
          final AudioPlayer currentPlayer = player;

          // Register this operation in our tracking set
          _pendingVolumeOperations.add(beepId);

          // Set initial volume to 0.0
          try {
            player.setVolume(0.0);
            _log('Volume set to 0.0 (beep $beepId start)', level: 'debug');
          } catch (e) {
            _log('Initial volume error: $e', level: 'warning');
            _pendingVolumeOperations.remove(beepId);
            return;
          }

          // Schedule volume increase with safety checks
          Future.delayed(const Duration(milliseconds: 50), () {
            // First check if this specific operation was cancelled
            if (!_pendingVolumeOperations.contains(beepId)) {
              _log(
                'Skipped volume up - operation $beepId was cancelled',
                level: 'debug',
              );
              return;
            }

            // Remove from pending operations before making changes
            _pendingVolumeOperations.remove(beepId);

            // Check all conditions that would indicate we should abort
            if (!_isPlaying ||
                _audioPlayer != currentPlayer ||
                _beepTimer == null ||
                currentPlayer.processingState == ProcessingState.completed ||
                currentPlayer.processingState == ProcessingState.idle) {
              _log(
                'Cancelled volume up (beep $beepId) - alarm was stopped or player changed',
                level: 'debug',
              );
              return;
            }

            // Set volume back up with additional safety
            try {
              if (_isPlaying && _audioPlayer == currentPlayer) {
                currentPlayer.setVolume(0.8);
                _log('Volume set to 0.8 (beep $beepId end)', level: 'debug');
              } else {
                _log(
                  'Skipped volume up - player state mismatch',
                  level: 'debug',
                );
              }
            } catch (e) {
              _log('Volume change error: $e', level: 'warning');
            }
          });
        } else {
          _log('BEEP TICK (no active player)', level: 'debug');
        }
      } catch (e) {
        _log('Beep pattern error: $e', level: 'error');
        // If we get repeated errors, disable the pattern
        timer.cancel();
        _beepTimer = null;
      }
    });
  }

  // Create a silent player for beep patterns
  Future<void> _createSilentPlayer() async {
    try {
      // Dispose any existing player
      if (_audioPlayer != null) {
        try {
          await _audioPlayer!.dispose();
        } catch (e) {
          _log(
            'Warning: Failed to dispose existing player: $e',
            level: 'warning',
          );
        }
        _audioPlayer = null;
      }

      // Create new player with silent audio
      final player = AudioPlayer();
      _audioPlayer = player;

      // Create a silent audio source (1 second of silence)
      await player.setAsset('assets/audio/alarm_low.mp3');
      await player.setVolume(0.0);
      await player.setLoopMode(LoopMode.one);
      await player.play();

      _log('Silent player created for beep pattern');
    } catch (e) {
      _log('Error creating silent player: $e', level: 'error');
      _audioPlayer = null;
    }
  }

  Future<void> playAlertSound({double volume = 0.7}) async {
    try {
      final player = _getOrCreatePlayer();
      await player.setVolume(volume);
      // Play single beep
    } catch (e) {
      // Handle error
    }
  }

  Future<void> stopAlarm() async {
    try {
      _log('Stopping audio alarm...');

      // Record stop time to identify late callbacks
      _lastStopTimeMs = DateTime.now().millisecondsSinceEpoch;
      final thisStopTime = _lastStopTimeMs;

      // IMMEDIATELY set playing to false to stop beep pattern
      _isPlaying = false;

      // Clear all pending volume operations immediately
      int pendingOpsCount = _pendingVolumeOperations.length;
      _pendingVolumeOperations.clear();
      _log('Cleared $pendingOpsCount pending volume operations');

      // Cancel all timers first
      _alarmTimer?.cancel();
      _alarmTimer = null;
      _beepTimer?.cancel();
      _beepTimer = null;

      // Store current player reference to avoid race conditions
      final currentPlayer = _audioPlayer;

      // Check if we actually need to stop anything
      bool hasActivePlayer = currentPlayer != null;

      _log('State check - hasActivePlayer: $hasActivePlayer');

      // Null out the player reference immediately to prevent future volume changes
      _audioPlayer = null;

      if (hasActivePlayer) {
        // NUCLEAR APPROACH: Completely destroy and recreate everything
        // First mute immediately (this is the most important part for immediate silence)
        try {
          await currentPlayer.setVolume(0);
          _log('Volume immediately muted');
        } catch (volumeError) {
          _log('Immediate mute failed: $volumeError', level: 'warning');
        }

        // Try multiple stop methods in sequence
        try {
          _log('Attempting to stop audio player...');
          // First try to disable looping
          await currentPlayer.setLoopMode(LoopMode.off);
          await currentPlayer.pause();
          await currentPlayer.stop();
          await currentPlayer.seek(Duration.zero);
          _log('Basic stop sequence completed');
        } catch (stopError) {
          _log('Basic stop sequence failed: $stopError', level: 'warning');
        }

        // Force dispose regardless of stop success
        try {
          _log('Force disposing audio player...');
          await currentPlayer.dispose();
          _log('Audio player disposed');
        } catch (disposeError) {
          _log('Dispose failed: $disposeError', level: 'error');
        }

        // Additional system-level audio cleanup
        try {
          // This would be a place to add platform-specific audio reset if needed
          // For now we just wait a moment for system cleanup
          await Future.delayed(const Duration(milliseconds: 300));
        } catch (e) {
          _log('System cleanup error: $e', level: 'warning');
        }

        // Check if another stop was called while we were waiting
        if (_lastStopTimeMs == thisStopTime) {
          _log('Audio alarm stopped completely');
        } else {
          _log(
            'Another stop was called while processing - deferring to newer stop',
          );
        }
      } else {
        _log('Audio alarm was not playing (no player found)');
      }

      // Always verify that state is clean at the end - just to be absolutely sure
      _isPlaying = false;
      _pendingVolumeOperations.clear();
    } catch (e) {
      _log('Error stopping audio alarm: $e', level: 'error');
      _log('Triggering emergency reset...', level: 'warning');
      // If normal stop fails, use nuclear option
      await emergencyReset();
    }
  }

  Future<void> stopAllSounds() async {
    await stopAlarm();
  }

  /// Nuclear option: Completely reset the audio service
  Future<void> emergencyReset() async {
    _log('EMERGENCY AUDIO RESET - Nuclear option activated', level: 'warning');

    // Update stop time to invalidate any pending callbacks
    _lastStopTimeMs = DateTime.now().millisecondsSinceEpoch;

    // Stop everything immediately
    _isPlaying = false;

    // Clear all pending volume operations immediately
    int pendingOps = _pendingVolumeOperations.length;
    _pendingVolumeOperations.clear();
    _log('Emergency cleared $pendingOps pending volume operations');

    // Cancel all timers
    _alarmTimer?.cancel();
    _alarmTimer = null;
    _beepTimer?.cancel();
    _beepTimer = null;

    // Capture current player instance and null out the field immediately
    final oldPlayer = _audioPlayer;
    _audioPlayer = null;

    // Dispose current player if exists
    if (oldPlayer != null) {
      try {
        // First silence immediately to prevent any sound
        await oldPlayer.setVolume(0.0);
        _log('Emergency mute applied');

        // Try multiple disposal methods
        try {
          await oldPlayer.setLoopMode(LoopMode.off);
          await oldPlayer.pause();
          await oldPlayer.stop();
          await oldPlayer.seek(Duration.zero);
          _log('Player stopped in emergency reset');
        } catch (e) {
          _log(
            'Player stop during emergency reset failed: $e',
            level: 'warning',
          );
        }

        try {
          await oldPlayer.dispose();
          _log('Emergency disposal completed');
        } catch (e) {
          _log('Emergency disposal error: $e', level: 'warning');
        }
      } catch (e) {
        _log('Critical emergency reset error: $e', level: 'error');
      }
    }

    // Triple-check all state flags
    _isPlaying = false;
    _pendingVolumeOperations.clear();

    // Wait for system cleanup
    await Future.delayed(const Duration(milliseconds: 500));

    // Additional system-level audio killswitch would go here if needed
    // For example, on Android you might use platform channels to force audio focus loss

    _log('Emergency reset completed - service is clean');
  }

  void dispose() {
    stopAllSounds();
    _alarmTimer?.cancel();
    _beepTimer?.cancel();
    _audioPlayer?.dispose();
    _audioPlayer = null;
  }
}
