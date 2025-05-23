// Screen shown when a fall is detected
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/settings_service.dart';
import '../services/emergency_alert_service.dart';
import '../services/local_alert_service.dart';
import '../models/settings_model.dart';

class FallAlertScreen extends StatefulWidget {
  final Position? currentPosition;

  const FallAlertScreen({super.key, this.currentPosition});

  @override
  State<FallAlertScreen> createState() => _FallAlertScreenState();
}

class _FallAlertScreenState extends State<FallAlertScreen> {
  // Countdown timer
  int _secondsRemaining = 30;
  Timer? _timer;

  // SMS sent status
  bool _smsSent = false;

  // App settings
  AppSettings? _settings;
  // Alert services
  final _emergencyAlertService = EmergencyAlertService();
  final _localAlertService = LocalAlertService();
  @override
  void initState() {
    super.initState();

    // Load settings
    _loadSettings();

    // Initialize services
    _initializeServices();

    // Start countdown timer
    _startCountdown();
  }

  // Initialize alert services
  Future<void> _initializeServices() async {
    await _localAlertService.initialize();
    await _emergencyAlertService.initialize();
  }

  @override
  void dispose() {
    _timer?.cancel();
    // Ensure alerts are stopped when screen is closed
    _localAlertService.stopAllAlerts();
    super.dispose();
  }

  // Load application settings
  Future<void> _loadSettings() async {
    final settings = await SettingsService.getSettings();
    setState(() {
      _settings = settings;
    });
  }

  // Start countdown timer
  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _timer?.cancel();
          // Send SMS when timer expires
          if (!_smsSent) {
            _sendEmergencySMS();
          }
        }
      });
    });
  }

  // Send emergency alerts (SMS and local device alerts)
  Future<void> _sendEmergencySMS() async {
    if (_settings == null) {
      await _loadSettings();
    }

    // Use EmergencyAlertService to handle all alert types
    // This will trigger both SMS notifications and local device alerts (sound, vibration, flashlight)
    final sendResult = await _emergencyAlertService.sendEmergencyAlerts();

    setState(() {
      _smsSent = sendResult;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sendResult
                ? 'Emergency alert sent'
                : 'Could not send SMS alerts, but local alerts are active',
          ),
          backgroundColor: sendResult ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  // Cancel the alert
  void _cancelAlert() {
    _timer?.cancel();

    // Stop all local alerts since user indicates they're okay
    _localAlertService.stopAllAlerts();
    _emergencyAlertService.cancelEmergencyAlerts();

    Navigator.of(context).pop(false); // false = alert canceled
  }

  // Confirm the fall and send alert immediately
  void _confirmFall() {
    _timer?.cancel();
    _sendEmergencySMS();
    Navigator.of(context).pop(true); // true = alert confirmed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Alert icon
              Icon(Icons.warning_rounded, size: 80, color: Colors.red.shade700),
              const SizedBox(height: 24),

              // Alert title
              Text(
                'Fall Detected!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade900,
                ),
              ),
              const SizedBox(height: 16),

              // Alert description
              const Text(
                'We detected that you may have fallen. '
                'If this is not the case, please press "I\'m OK".',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 32),

              // Countdown timer
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.shade100,
                  border: Border.all(color: Colors.red.shade700, width: 4),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$_secondsRemaining',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade900,
                        ),
                      ),
                      Text(
                        'seconds',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // SMS status
              if (_smsSent)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'Emergency contacts notified',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 32),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Cancel button
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.green),
                      ),
                      onPressed: _cancelAlert,
                      child: const Text(
                        "I'M OK",
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Confirm button
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _confirmFall,
                      child: const Text(
                        'NEED HELP',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
