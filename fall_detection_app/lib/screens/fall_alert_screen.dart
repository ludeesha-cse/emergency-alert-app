// Screen shown when a fall is detected
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/sms_service.dart';
import '../services/settings_service.dart';
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

  @override
  void initState() {
    super.initState();

    // Load settings
    _loadSettings();

    // Start countdown timer
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
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

  // Send emergency SMS to all contacts
  Future<void> _sendEmergencySMS() async {
    if (_settings == null) {
      await _loadSettings();
    }

    final contacts = _settings?.emergencyContacts ?? [];
    if (contacts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No emergency contacts found')),
        );
      }
      return;
    }

    final phoneNumbers = contacts
        .map((contact) => contact.phoneNumber)
        .toList();
    final message =
        _settings?.emergencyMessage ?? "I've fallen and need assistance.";

    // Send SMS
    final result = await SmsService.sendSms(
      recipients: phoneNumbers,
      message: message,
      position: widget.currentPosition,
    );

    setState(() {
      _smsSent = result;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result ? 'Emergency alert sent' : 'Failed to send emergency alert',
          ),
        ),
      );
    }
  }

  // Cancel the alert
  void _cancelAlert() {
    _timer?.cancel();
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
