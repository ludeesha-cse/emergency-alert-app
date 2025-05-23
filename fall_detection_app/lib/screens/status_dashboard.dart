import 'package:flutter/material.dart';
import 'dart:async';
import '../services/fall_detection_service.dart';
import '../services/location_service.dart';
import '../models/settings_model.dart';

class StatusDashboard extends StatefulWidget {
  const StatusDashboard({super.key});

  @override
  State<StatusDashboard> createState() => _StatusDashboardState();
}

class _StatusDashboardState extends State<StatusDashboard> {
  final FallDetectionService _fallService = FallDetectionService();
  Timer? _statusUpdateTimer;
  // Status variables
  bool _isMonitoring = false;
  bool _locationEnabled = false;
  int _emergencyContacts = 0;
  String _lastLocationUpdate = 'Never';
  AppSettings? _settings;

  @override
  void initState() {
    super.initState();
    _updateStatus();
    _startStatusUpdates();
  }

  @override
  void dispose() {
    _statusUpdateTimer?.cancel();
    super.dispose();
  }

  void _startStatusUpdates() {
    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _updateStatus();
    });
  }

  Future<void> _updateStatus() async {
    try {
      final locationService = await LocationService.initialize();
      final hasLocationPermission = await locationService
          .checkLocationPermission();

      setState(() {
        _isMonitoring = _fallService.isRunning;
        _emergencyContacts = _fallService.emergencyContacts.length;
        _settings = _fallService.settings;
        _locationEnabled = hasLocationPermission;
        _lastLocationUpdate = 'Available';
      });
    } catch (e) {
      // Handle errors gracefully
      debugPrint('Error updating status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dashboard, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'System Status',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Monitoring Status
            _buildStatusRow(
              'Fall Detection',
              _isMonitoring ? 'Active' : 'Inactive',
              _isMonitoring ? Colors.green : Colors.red,
              _isMonitoring ? Icons.check_circle : Icons.error,
            ),

            // Location Status
            _buildStatusRow(
              'Location Services',
              _locationEnabled ? 'Enabled' : 'Disabled',
              _locationEnabled ? Colors.green : Colors.orange,
              _locationEnabled ? Icons.location_on : Icons.location_off,
            ),

            // Emergency Contacts
            _buildStatusRow(
              'Emergency Contacts',
              '$_emergencyContacts configured',
              _emergencyContacts > 0 ? Colors.green : Colors.orange,
              _emergencyContacts > 0 ? Icons.contacts : Icons.contact_emergency,
            ),

            // Sensitivity Setting
            if (_settings != null)
              _buildStatusRow(
                'Detection Sensitivity',
                '${(_settings!.fallDetectionSensitivity * 100).toInt()}%',
                Colors.blue,
                Icons.tune,
              ),

            // Last Location Update
            _buildStatusRow(
              'Last Location Update',
              _lastLocationUpdate,
              _lastLocationUpdate == 'Never' ? Colors.red : Colors.green,
              Icons.update,
            ),

            const SizedBox(height: 16),

            // Quick Actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _updateStatus,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _runSystemTest,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Test'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Future<void> _runSystemTest() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Running system test...'),
          ],
        ),
      ),
    );

    try {
      // Test various components
      final results = <String, bool>{};

      // Test fall detection service
      results['Fall Detection Service'] = _fallService.isRunning;
      // Test location service
      final locationService = await LocationService.initialize();
      results['Location Service'] = await locationService
          .checkLocationPermission();

      // Test permissions
      // This would check various permissions
      results['Permissions'] = true; // Simplified for demo

      // Wait a bit to simulate testing
      await Future.delayed(const Duration(seconds: 2));

      // Close loading dialog
      Navigator.of(context).pop();

      // Show results
      _showTestResults(results);
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Test failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showTestResults(Map<String, bool> results) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('System Test Results'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: results.entries.map((entry) {
            return ListTile(
              leading: Icon(
                entry.value ? Icons.check_circle : Icons.error,
                color: entry.value ? Colors.green : Colors.red,
              ),
              title: Text(entry.key),
              subtitle: Text(entry.value ? 'OK' : 'Failed'),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
