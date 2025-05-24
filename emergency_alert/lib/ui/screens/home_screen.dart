import 'package:flutter/material.dart';
import '../../services/sensor/sensor_service.dart';
import '../../services/location/location_service.dart';
import '../../services/background/background_service.dart';
import '../../utils/permission_helper.dart';
import '../../models/sensor_data.dart';
import '../screens/permission_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SensorService _sensorService = SensorService();
  final LocationService _locationService = LocationService();
  final BackgroundService _backgroundService = BackgroundService();

  bool _isMonitoring = false;
  bool _hasPermissions = false;
  SensorData? _currentSensorData;
  LocationData? _currentLocation;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _checkPermissions();
    await _initializeServices();
  }

  Future<void> _checkPermissions() async {
    // Get permissions status
    final permissions = await PermissionHelper.checkAllPermissions();

    // Check if all required permissions are granted
    final requiredPermissions = [
      'location',
      'backgroundLocation',
      'sms',
      'microphone',
      'notification',
    ];

    bool allRequired = true;
    for (var permission in requiredPermissions) {
      if (permissions.containsKey(permission) &&
          permissions[permission] == false) {
        allRequired = false;
        break;
      }
    }

    setState(() {
      _hasPermissions = allRequired;
    });

    // Request permissions if not granted
    if (!_hasPermissions) {
      await _requestPermissions();
    }
  }

  Future<void> _requestPermissions() async {
    // Show the dedicated permission screen instead of modal dialogs
    final granted =
        await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (context) => const PermissionScreen()),
        ) ??
        false;

    // Update state based on result
    setState(() {
      _hasPermissions = granted;
    });

    // If still not granted, show explanation dialog
    if (!granted) {
      _showPermissionDialog();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text(
          'This app requires various permissions to function properly. '
          'Without these permissions, some emergency features will not work correctly.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PermissionScreen(),
                ),
              );
            },
            child: const Text('Review Permissions'),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeServices() async {
    if (!_hasPermissions) return;

    // Initialize background service
    await _backgroundService.initialize();

    // Listen to sensor data
    _sensorService.sensorDataStream.listen((data) {
      setState(() {
        _currentSensorData = data;
      });
    });

    // Listen to location updates
    _locationService.locationStream.listen((location) {
      setState(() {
        _currentLocation = location;
      });
    });

    // Listen to emergency alerts
    _sensorService.fallDetectedStream.listen((detected) {
      if (detected) {
        _showEmergencyAlert('Fall Detected');
      }
    });

    _sensorService.impactDetectedStream.listen((detected) {
      if (detected) {
        _showEmergencyAlert('Impact Detected');
      }
    });
  }

  void _showEmergencyAlert(String alertType) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(alertType),
        content: const Text(
          'An emergency has been detected. Emergency contacts will be notified in 30 seconds. '
          'Press Cancel if this is a false alarm.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Cancel emergency alert
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Send alert immediately
            },
            child: const Text('Send Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleMonitoring() async {
    if (!_hasPermissions) {
      await _requestPermissions();
      return;
    }

    if (_isMonitoring) {
      await _stopMonitoring();
    } else {
      await _startMonitoring();
    }
  }

  Future<void> _startMonitoring() async {
    try {
      await _sensorService.startMonitoring();
      await _locationService.startTracking();
      await _backgroundService.startService();

      setState(() {
        _isMonitoring = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Emergency monitoring started')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error starting monitoring: $e')));
    }
  }

  Future<void> _stopMonitoring() async {
    try {
      await _sensorService.stopMonitoring();
      await _locationService.stopTracking();
      await _backgroundService.stopService();

      setState(() {
        _isMonitoring = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Emergency monitoring stopped')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error stopping monitoring: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Alert'),
        backgroundColor: _isMonitoring ? Colors.green : Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      _isMonitoring ? Icons.security : Icons.security_outlined,
                      size: 48,
                      color: _isMonitoring ? Colors.green : Colors.red,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isMonitoring
                          ? 'Monitoring Active'
                          : 'Monitoring Inactive',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _hasPermissions
                          ? 'All permissions granted'
                          : 'Permissions required',
                      style: TextStyle(
                        color: _hasPermissions ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Sensor Data Card
            if (_currentSensorData != null)
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sensor Data',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Magnitude: ${_currentSensorData!.magnitude.toStringAsFixed(2)}G',
                      ),
                      Text(
                        'Accelerometer: (${_currentSensorData!.accelerometerX.toStringAsFixed(2)}, ${_currentSensorData!.accelerometerY.toStringAsFixed(2)}, ${_currentSensorData!.accelerometerZ.toStringAsFixed(2)})',
                      ),
                      Text(
                        'Gyroscope: (${_currentSensorData!.gyroscopeX.toStringAsFixed(2)}, ${_currentSensorData!.gyroscopeY.toStringAsFixed(2)}, ${_currentSensorData!.gyroscopeZ.toStringAsFixed(2)})',
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Location Data Card
            if (_currentLocation != null)
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Location',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Lat: ${_currentLocation!.latitude.toStringAsFixed(6)}',
                      ),
                      Text(
                        'Lng: ${_currentLocation!.longitude.toStringAsFixed(6)}',
                      ),
                      if (_currentLocation!.address != null)
                        Text('Address: ${_currentLocation!.address}'),
                      if (_currentLocation!.accuracy != null)
                        Text(
                          'Accuracy: ${_currentLocation!.accuracy!.toStringAsFixed(1)}m',
                        ),
                    ],
                  ),
                ),
              ),

            const Spacer(),

            // Control Buttons
            ElevatedButton.icon(
              onPressed: _toggleMonitoring,
              icon: Icon(_isMonitoring ? Icons.stop : Icons.play_arrow),
              label: Text(
                _isMonitoring ? 'Stop Monitoring' : 'Start Monitoring',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isMonitoring ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            const SizedBox(height: 8),

            // Panic Button
            ElevatedButton.icon(
              onPressed: () {
                _showEmergencyAlert('Panic Button Activated');
              },
              icon: const Icon(Icons.warning),
              label: const Text('PANIC BUTTON'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sensorService.dispose();
    _locationService.dispose();
    super.dispose();
  }
}
