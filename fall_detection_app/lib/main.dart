import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

import 'services/fall_detection_service_updated.dart';
import 'services/location_service.dart';
import 'services/emergency_alert_service.dart';
import 'services/local_alert_service.dart';
import 'screens/settings_screen.dart';
import 'screens/emergency_contacts_screen.dart';
import 'screens/fall_alert_screen.dart';
import 'screens/permission_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  final fallDetectionService = FallDetectionService();
  await fallDetectionService.initialize();

  // Initialize location service
  final locationService = await LocationService.initialize();
  await locationService.initializeBackgroundService();
  await locationService.startLocationUpdates();

  // Initialize emergency alert service
  final emergencyAlertService = EmergencyAlertService();
  await emergencyAlertService.initialize();
  debugPrint('EmergencyAlertService initialized');

  // Initialize local alert service
  final localAlertService = LocalAlertService();
  await localAlertService.initialize();
  debugPrint('LocalAlertService initialized');
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _checking = true;
  bool _permissionsGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final permissions = [
      Permission.activityRecognition,
      Permission.locationAlways,
      Permission.locationWhenInUse,
      Permission.notification,
      Permission.sms,
      Permission.microphone,
    ];

    // Check all required permissions
    Map<Permission, PermissionStatus> statuses = {};
    for (var permission in permissions) {
      statuses[permission] = await permission.status;
    }

    // Check if all permissions are granted
    final allGranted = statuses.values.every((status) => status.isGranted);

    setState(() {
      _permissionsGranted = allGranted;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fall Detection App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: _checking
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _permissionsGranted
          ? const MyHomePage(title: 'Fall Detection App')
          : PermissionScreen(
              nextScreen: const MyHomePage(title: 'Fall Detection App'),
            ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Service instance
  final FallDetectionService _fallDetectionService = FallDetectionService();

  // State variables
  String _statusMessage = "Fall detection is not active";
  bool _isMonitoring = false;
  bool _initializing = true;
  bool _backgroundModeEnabled = true; // Toggle for background execution
  double _sensorSamplingRate = 500; // ms, for battery optimization

  @override
  void initState() {
    super.initState();
    _checkInitialStatus();
  }

  // Check if fall detection was previously running
  Future<void> _checkInitialStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final wasRunning = prefs.getBool('fall_detection_running') ?? false;

    if (wasRunning) {
      _startMonitoring(showSnackBar: false);
    }

    setState(() {
      _initializing = false;
    });
  }

  // Toggle fall detection monitoring
  Future<void> _toggleMonitoring() async {
    if (_isMonitoring) {
      await _stopMonitoring();
    } else {
      await _startMonitoring();
    }
  }

  // Start fall detection
  Future<void> _startMonitoring({bool showSnackBar = true}) async {
    // Request necessary permissions
    final permissionsGranted = await _requestPermissions();
    if (!permissionsGranted) {
      if (mounted && showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permissions required for fall detection'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Start the monitoring service
    final success = await _fallDetectionService.startMonitoring();

    if (success) {
      // Save state to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('fall_detection_running', true);

      setState(() {
        _isMonitoring = true;
        _statusMessage = "Fall detection active";
      });

      if (mounted && showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fall detection started'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted && showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to start fall detection'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Stop fall detection
  Future<void> _stopMonitoring() async {
    await _fallDetectionService.stopMonitoring();

    // Save state to preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fall_detection_running', false);

    setState(() {
      _isMonitoring = false;
      _statusMessage = "Fall detection stopped";
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fall detection stopped')));
    }
  }

  // Request required permissions
  Future<bool> _requestPermissions() async {
    final permissions = [
      Permission.activityRecognition,
      Permission.locationAlways,
      Permission.locationWhenInUse,
      Permission.notification,
      Permission.sms,
      Permission.microphone,
    ];

    // Check permissions first
    Map<Permission, PermissionStatus> statuses = {};
    for (var permission in permissions) {
      statuses[permission] = await permission.status;
    }

    // If all permissions are already granted, return true
    if (statuses.values.every((status) => status.isGranted)) {
      return true;
    }

    // If any permission is not granted, show the permission screen
    if (mounted) {
      final granted = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (context) => PermissionScreen(
            nextScreen: const MyHomePage(title: 'Fall Detection App'),
          ),
        ),
      );

      // Return true if all permissions were granted, false otherwise
      return granted ?? false;
    }

    return false;
  }

  // Simulate a fall for testing
  void _simulateFall() async {
    if (!_isMonitoring) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Start monitoring first')));
      return;
    }

    // Get current location
    Position? position;
    try {
      final locationService = await LocationService.initialize();
      position = await locationService.getCurrentLocation();
      if (position == null) {
        // Try to get last known location as fallback
        position = await locationService.getLastKnownLocation();
      }
    } catch (e) {
      debugPrint('Error getting position: $e');
    }

    // Show fall alert screen
    if (mounted) {
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FallAlertScreen(currentPosition: position),
        ),
      );

      // Handle result (true = help needed, false = false alarm)
      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emergency contacts have been notified'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Navigate to settings screen
  void _openSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const SettingsScreen()));
  }

  // Navigate to contacts screen
  void _openContacts() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const EmergencyContactsScreen()),
    );
  }

  // Toggle background mode
  void _toggleBackgroundMode(bool value) async {
    setState(() {
      _backgroundModeEnabled = value;
    });
    if (!value) {
      // Stop background service
      await _fallDetectionService.stopMonitoring();
      setState(() {
        _isMonitoring = false;
        _statusMessage = "Fall detection stopped (background disabled)";
      });
    } else {
      // Optionally restart monitoring if needed
      if (!_isMonitoring) {
        await _startMonitoring();
      }
    }
  }

  // Adjust sensor sampling rate for battery optimization
  void _setSensorSamplingRate(double value) {
    setState(() {
      _sensorSamplingRate = value;
    });
    _fallDetectionService.setSamplingRate(value);
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // App icon
            Icon(
              Icons.support,
              size: 100,
              color: _isMonitoring ? Colors.red : Colors.grey,
            ),
            const SizedBox(height: 20),

            // Status message
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isMonitoring
                    ? Colors.green.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _statusMessage,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _isMonitoring ? Colors.green[700] : Colors.grey[700],
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Start/Stop button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isMonitoring ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: _toggleMonitoring,
              child: Text(
                _isMonitoring ? 'Stop Monitoring' : 'Start Monitoring',
                style: const TextStyle(fontSize: 18),
              ),
            ),

            const SizedBox(height: 20),

            // Testing button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: _simulateFall,
              child: const Text(
                'Simulate Fall',
                style: TextStyle(fontSize: 18),
              ),
            ),

            const SizedBox(height: 40),

            // Emergency contacts button
            TextButton.icon(
              icon: const Icon(Icons.contacts),
              label: const Text('Manage Emergency Contacts'),
              onPressed: _openContacts,
            ),

            const SizedBox(height: 20),

            // Toggle for background mode
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Background Mode'),
                Switch(
                  value: _backgroundModeEnabled,
                  onChanged: _toggleBackgroundMode,
                ),
              ],
            ),
            // Slider for sensor sampling rate
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Sensor Rate:'),
                Slider(
                  value: _sensorSamplingRate,
                  min: 100,
                  max: 2000,
                  divisions: 19,
                  label: '${_sensorSamplingRate.round()} ms',
                  onChanged: (value) => _setSensorSamplingRate(value),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
