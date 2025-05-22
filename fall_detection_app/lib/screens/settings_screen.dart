// Settings screen for the fall detection app
import 'package:flutter/material.dart';
import '../models/settings_model.dart';
import '../services/settings_service.dart';
import '../services/fall_detection_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // App settings
  AppSettings? _settings;

  // Fallback values if settings are not loaded yet
  double _sensitivity = 0.5;
  bool _playAlarm = true;
  bool _flashLight = true;
  bool _vibrate = true;
  String _message =
      "I've fallen and need assistance. This is my current location:";

  // Text editing controller for emergency message
  late TextEditingController _messageController;

  // Services
  final _fallDetectionService = FallDetectionService();

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(text: _message);
    _loadSettings();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  // Load settings from storage
  Future<void> _loadSettings() async {
    final settings = await SettingsService.getSettings();
    setState(() {
      _settings = settings;
      _sensitivity = settings.fallDetectionSensitivity;
      _playAlarm = settings.playAlarmOnFall;
      _flashLight = settings.flashLightOnFall;
      _vibrate = settings.vibrateOnFall;
      _message = settings.emergencyMessage;
      _messageController.text = _message;
    });
  }

  // Save settings
  Future<void> _saveSettings() async {
    if (_settings == null) return;

    final updatedSettings = _settings!.copyWith(
      fallDetectionSensitivity: _sensitivity,
      playAlarmOnFall: _playAlarm,
      flashLightOnFall: _flashLight,
      vibrateOnFall: _vibrate,
      emergencyMessage: _messageController.text,
    );

    await SettingsService.saveSettings(updatedSettings);

    // Update fall detection service sensitivity
    await _fallDetectionService.updateSensitivity(_sensitivity);

    // Show confirmation
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Settings saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _settings == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fall Detection Sensitivity
                  const Text(
                    'Fall Detection Sensitivity',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Low'),
                      Expanded(
                        child: Slider(
                          value: _sensitivity,
                          min: 0.0,
                          max: 1.0,
                          divisions: 10,
                          label: _getSensitivityLabel(_sensitivity),
                          onChanged: (value) {
                            setState(() {
                              _sensitivity = value;
                            });
                          },
                        ),
                      ),
                      const Text('High'),
                    ],
                  ),

                  const Divider(height: 32),

                  // Alert Settings
                  const Text(
                    'Alert Settings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Play alarm switch
                  SwitchListTile(
                    title: const Text('Play Alarm Sound'),
                    subtitle: const Text(
                      'Play a loud alarm when a fall is detected',
                    ),
                    value: _playAlarm,
                    onChanged: (value) {
                      setState(() {
                        _playAlarm = value;
                      });
                    },
                  ),

                  // Flash light switch
                  SwitchListTile(
                    title: const Text('Flash Light'),
                    subtitle: const Text(
                      'Flash the phone light when a fall is detected',
                    ),
                    value: _flashLight,
                    onChanged: (value) {
                      setState(() {
                        _flashLight = value;
                      });
                    },
                  ),

                  // Vibrate switch
                  SwitchListTile(
                    title: const Text('Vibrate'),
                    subtitle: const Text(
                      'Vibrate the phone when a fall is detected',
                    ),
                    value: _vibrate,
                    onChanged: (value) {
                      setState(() {
                        _vibrate = value;
                      });
                    },
                  ),

                  const Divider(height: 32),

                  // Emergency Message
                  const Text(
                    'Emergency Message',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This message will be sent to emergency contacts when a fall is detected',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _messageController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter emergency message',
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _saveSettings,
                      child: const Text('SAVE SETTINGS'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // Get label text for sensitivity slider
  String _getSensitivityLabel(double value) {
    if (value < 0.3) {
      return 'Low';
    } else if (value < 0.7) {
      return 'Medium';
    } else {
      return 'High';
    }
  }
}
