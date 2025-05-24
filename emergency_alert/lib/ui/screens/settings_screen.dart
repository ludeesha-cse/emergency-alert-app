import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SharedPreferences _prefs;

  // Settings values
  bool _fallDetectionEnabled = true;
  bool _impactDetectionEnabled = true;
  bool _locationTrackingEnabled = true;
  bool _backgroundServiceEnabled = true;
  bool _audioAlertsEnabled = true;
  bool _vibrationEnabled = true;
  bool _flashlightEnabled = true;  double _fallThreshold = 2.5;
  double _impactThreshold = 15.0; // Changed from 4.0 to be within valid range (10-50)
  int _alertDelaySeconds = 30;
  int _locationUpdateIntervalMinutes = 5;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();

    setState(() {
      _fallDetectionEnabled =
          _prefs.getBool(AppConstants.keyFallDetectionEnabled) ?? true;
      _impactDetectionEnabled =
          _prefs.getBool(AppConstants.keyImpactDetectionEnabled) ?? true;
      _locationTrackingEnabled =
          _prefs.getBool(AppConstants.keyLocationTrackingEnabled) ?? true;
      _backgroundServiceEnabled =
          _prefs.getBool('background_service_enabled') ?? true;
      _audioAlertsEnabled = _prefs.getBool('audio_alerts_enabled') ?? true;
      _vibrationEnabled = _prefs.getBool('vibration_enabled') ?? true;
      _flashlightEnabled = _prefs.getBool('flashlight_enabled') ?? true;      _fallThreshold = _prefs.getDouble('fall_threshold') ?? 2.5;
      _impactThreshold = _prefs.getDouble('impact_threshold') ?? 15.0; // Changed default to 15.0
      _alertDelaySeconds = _prefs.getInt('alert_delay_seconds') ?? 30;
      _locationUpdateIntervalMinutes =
          _prefs.getInt('location_update_interval') ?? 5;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    if (value is bool) {
      await _prefs.setBool(key, value);
    } else if (value is double) {
      await _prefs.setDouble(key, value);
    } else if (value is int) {
      await _prefs.setInt(key, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Detection Settings
          _buildSectionHeader('Detection Settings'),
          _buildSwitchTile(
            'Fall Detection',
            'Monitor for falls using accelerometer',
            _fallDetectionEnabled,
            Icons.personal_injury,
            (value) {
              setState(() => _fallDetectionEnabled = value);
              _saveSetting(AppConstants.keyFallDetectionEnabled, value);
            },
          ),
          _buildSwitchTile(
            'Impact Detection',
            'Monitor for sudden impacts',
            _impactDetectionEnabled,
            Icons.warning,
            (value) {
              setState(() => _impactDetectionEnabled = value);
              _saveSetting(AppConstants.keyImpactDetectionEnabled, value);
            },
          ),
          _buildSwitchTile(
            'Location Tracking',
            'Track GPS location for emergency alerts',
            _locationTrackingEnabled,
            Icons.location_on,
            (value) {
              setState(() => _locationTrackingEnabled = value);
              _saveSetting(AppConstants.keyLocationTrackingEnabled, value);
            },
          ),

          const Divider(height: 32),

          // Alert Settings
          _buildSectionHeader('Alert Settings'),
          _buildSwitchTile(
            'Background Service',
            'Keep monitoring when app is closed',
            _backgroundServiceEnabled,
            Icons.settings_backup_restore,
            (value) {
              setState(() => _backgroundServiceEnabled = value);
              _saveSetting('background_service_enabled', value);
            },
          ),
          _buildSwitchTile(
            'Audio Alerts',
            'Play alarm sound during emergencies',
            _audioAlertsEnabled,
            Icons.volume_up,
            (value) {
              setState(() => _audioAlertsEnabled = value);
              _saveSetting('audio_alerts_enabled', value);
            },
          ),
          _buildSwitchTile(
            'Vibration',
            'Vibrate device during alerts',
            _vibrationEnabled,
            Icons.vibration,
            (value) {
              setState(() => _vibrationEnabled = value);
              _saveSetting('vibration_enabled', value);
            },
          ),
          _buildSwitchTile(
            'Flashlight',
            'Flash light in SOS pattern',
            _flashlightEnabled,
            Icons.flashlight_on,
            (value) {
              setState(() => _flashlightEnabled = value);
              _saveSetting('flashlight_enabled', value);
            },
          ),

          const Divider(height: 32),

          // Threshold Settings
          _buildSectionHeader('Sensitivity Settings'),
          _buildSliderTile(
            'Fall Detection Sensitivity',
            'Higher values = less sensitive',
            _fallThreshold,
            1.0,
            5.0,
            Icons.tune,
            (value) {
              setState(() => _fallThreshold = value);
              _saveSetting('fall_threshold', value);
            },
          ),
          _buildSliderTile(
            'Impact Detection Sensitivity',
            'Higher values = less sensitive',
            _impactThreshold,
            10.0,
            50.0,
            Icons.tune,
            (value) {
              setState(() => _impactThreshold = value);
              _saveSetting('impact_threshold', value);
            },
          ),

          const Divider(height: 32),

          // Timing Settings
          _buildSectionHeader('Timing Settings'),
          _buildSliderTile(
            'Alert Delay (seconds)',
            'Time before sending emergency alerts',
            _alertDelaySeconds.toDouble(),
            5.0,
            60.0,
            Icons.timer,
            (value) {
              setState(() => _alertDelaySeconds = value.round());
              _saveSetting('alert_delay_seconds', value.round());
            },
          ),
          _buildSliderTile(
            'Location Update Interval (minutes)',
            'How often to update GPS location',
            _locationUpdateIntervalMinutes.toDouble(),
            1.0,
            30.0,
            Icons.location_searching,
            (value) {
              setState(() => _locationUpdateIntervalMinutes = value.round());
              _saveSetting('location_update_interval', value.round());
            },
          ),

          const Divider(height: 32),

          // Reset Settings
          _buildSectionHeader('Reset'),
          ListTile(
            leading: const Icon(Icons.restore, color: Colors.orange),
            title: const Text('Reset to Defaults'),
            subtitle: const Text('Restore all settings to default values'),
            onTap: _showResetDialog,
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    IconData icon,
    ValueChanged<bool> onChanged,
  ) {
    return Card(
      child: SwitchListTile(
        secondary: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSliderTile(
    String title,
    String subtitle,
    double value,
    double min,
    double max,
    IconData icon,
    ValueChanged<double> onChanged,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle),
            const SizedBox(height: 8),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: (max - min).round(),
              label: value.toStringAsFixed(1),
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text(
          'Are you sure you want to reset all settings to their default values? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _resetSettings();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetSettings() async {
    await _prefs.clear();
    await _loadSettings();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings reset to defaults')),
      );
    }
  }
}
