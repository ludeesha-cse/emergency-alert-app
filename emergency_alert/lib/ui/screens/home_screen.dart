import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/sensor/sensor_service.dart';
import '../../services/location/location_service.dart';
import '../../services/background/background_service.dart';
import '../../services/permission_service.dart';
import '../../services/emergency_response_service.dart';
import '../../utils/permission_helper.dart';
import '../../utils/permission_fallbacks.dart';
import '../../models/sensor_data.dart';
import '../../models/alert.dart';
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
  final EmergencyResponseService _emergencyService = EmergencyResponseService();
  bool _isMonitoring = false;
  bool _hasPermissions = false;
  bool _notificationsEnabled = false;
  bool _isEmergencyModalShowing = false;
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
    final criticalPermissions = [
      'location',
      'backgroundLocation',
      'sms',
      'microphone',
    ];

    // Notification is treated separately since it may require special handling
    final hasNotificationPermission = permissions['notification'] == true;

    bool allCriticalGranted = true;
    for (var permission in criticalPermissions) {
      if (permissions.containsKey(permission) &&
          permissions[permission] == false) {
        allCriticalGranted = false;
        break;
      }
    } // Use our new fallback system to determine if we can operate in limited mode
    final permissionService = Provider.of<PermissionService>(
      context,
      listen: false,
    );
    await permissionService.checkPermissionStatuses();

    // Determine if we can operate with the current permissions
    final canOperateWithLimitations =
        PermissionFallbacks.canOperateInLimitedMode(permissionService);

    setState(() {
      // We can still function with limited capabilities based on available permissions
      _hasPermissions = canOperateWithLimitations;
      _notificationsEnabled = hasNotificationPermission;
    }); // Request permissions if we can't operate even in limited mode
    if (!_hasPermissions) {
      await _requestPermissions();
    } else if (!allCriticalGranted) {
      // Show limitations if we're operating in limited mode
      PermissionFallbacks.showLimitationsDialog(context, permissionService);
    } else if (!hasNotificationPermission) {
      // If just notifications are missing, show a specific dialog
      _showNotificationPermissionDialog();
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

  // Show a specialized dialog for notification permissions
  void _showNotificationPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Access Required'),
        content: const Text(
          'This app needs notification permissions to alert you during emergencies and to run properly in the background.\n\n'
          'On newer Android devices, this permission must be granted from system settings. '
          'Would you like to go to settings to enable notifications?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final permissionService = Provider.of<PermissionService>(
                context,
                listen: false,
              );
              await permissionService.openSettings();
            },
            child: const Text('Open Settings'),
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
    }); // Listen to emergency alerts
    _sensorService.fallDetectedStream.listen((detected) {
      if (detected) {
        _emergencyService.triggerEmergency(
          alertType: AlertType.fall,
          customMessage: 'Fall detected - user may need assistance',
        );
        _showEmergencyAlert('Fall Detected');
      }
    });

    _sensorService.impactDetectedStream.listen((detected) {
      if (detected) {
        _emergencyService.triggerEmergency(
          alertType: AlertType.impact,
          customMessage: 'High impact detected - possible accident',
        );
        _showEmergencyAlert('Impact Detected');
      }
    });
  }

  void _showEmergencyAlert(String alertType) {
    // Prevent duplicate modals
    if (_isEmergencyModalShowing) {
      return;
    }

    _isEmergencyModalShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StreamBuilder<int>(
        stream: _emergencyService.countdownStream,
        builder: (context, snapshot) {
          final remainingSeconds = snapshot.data ?? 30;

          // Check if countdown has finished
          if (remainingSeconds <= 0) {
            // Close dialog automatically when countdown reaches 0
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.canPop(context)) {
                Navigator.of(context).pop();
                _isEmergencyModalShowing = false;
              }
            });
          }

          return AlertDialog(
            title: Text(alertType),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'An emergency has been detected. Emergency contacts will be notified automatically.',
                ),
                const SizedBox(height: 16),
                Text(
                  remainingSeconds > 0
                      ? 'SMS will be sent in $remainingSeconds seconds'
                      : 'Sending emergency SMS...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: remainingSeconds <= 10 ? Colors.red : Colors.orange,
                  ),
                ),
                const SizedBox(height: 8),
                if (remainingSeconds > 0)
                  Text(
                    'Press Cancel to stop all alerts and cancel the emergency.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
              ],
            ),
            actions: remainingSeconds > 0
                ? [
                    TextButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        _isEmergencyModalShowing = false;
                        await _emergencyService.cancelEmergency();
                      },
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        _isEmergencyModalShowing = false;
                        await _emergencyService.sendEmergencyImmediately();
                      },
                      child: const Text('Send Now'),
                    ),
                  ]
                : [
                    // Show only close button when countdown is finished
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _isEmergencyModalShowing = false;
                      },
                      child: const Text('Close'),
                    ),
                  ],
          );
        },
      ),
    ).then((_) {
      // Ensure the flag is reset when dialog is dismissed
      _isEmergencyModalShowing = false;
    });
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

      // Start background service after permission checks
      final permissionService = Provider.of<PermissionService>(
        context,
        listen: false,
      );
      if (permissionService.isNotificationGranted) {
        await _backgroundService.startService();
      } else {
        // Show a snackbar warning that background monitoring won't work
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notification permission not granted. Background monitoring will be limited.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }

      setState(() {
        _isMonitoring = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Emergency monitoring started')),
      );
    } catch (e) {
      print('Error starting monitoring: $e');
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
        child: SingleChildScrollView(
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
                        _isMonitoring
                            ? Icons.security
                            : Icons.security_outlined,
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
                            ? (_notificationsEnabled
                                  ? 'All permissions granted'
                                  : 'Limited functionality - Notifications disabled')
                            : 'Permissions required',
                        style: TextStyle(
                          color: _hasPermissions
                              ? (_notificationsEnabled
                                    ? Colors.green
                                    : Colors.orange)
                              : Colors.orange,
                        ),
                      ),

                      // Emergency Detection Cooldown Indicator
                      if (BackgroundService.isInCooldownPeriod)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.blue),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.pause_circle_outline,
                                size: 16,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Detection paused (${BackgroundService.cooldownTimeRemainingMinutes}m)',
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Show notification warning banner if needed
              if (!_notificationsEnabled)
                Card(
                  margin: const EdgeInsets.only(top: 16),
                  color: Colors.amber.shade100,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.notification_important,
                              color: Colors.amber.shade800,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Notifications Disabled',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Emergency alerts may not work properly. Background monitoring and alerts require notification permission.',
                          style: TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () {
                            _showNotificationPermissionDialog();
                          },
                          child: const Text('Enable Notifications'),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16), // Sensor Data Card
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
                      if (_currentSensorData != null) ...[
                        Text(
                          'Magnitude: ${_currentSensorData!.magnitude.toStringAsFixed(2)}G',
                        ),
                        Text(
                          'Accelerometer: (${_currentSensorData!.accelerometerX.toStringAsFixed(2)}, ${_currentSensorData!.accelerometerY.toStringAsFixed(2)}, ${_currentSensorData!.accelerometerZ.toStringAsFixed(2)})',
                        ),
                        Text(
                          'Gyroscope: (${_currentSensorData!.gyroscopeX.toStringAsFixed(2)}, ${_currentSensorData!.gyroscopeY.toStringAsFixed(2)}, ${_currentSensorData!.gyroscopeZ.toStringAsFixed(2)})',
                        ),
                      ] else ...[
                        Text(
                          'No sensor data available',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const Text(
                          'Start monitoring to see real-time sensor readings',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16), // Location Data Card
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
                      if (_currentLocation != null) ...[
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
                      ] else ...[
                        Text(
                          'No location data available',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const Text(
                          'Start monitoring to see current location',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

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
              const SizedBox(height: 8), // Panic Button
              ElevatedButton.icon(
                onPressed: () async {
                  await _emergencyService.triggerManualEmergency();
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
              const SizedBox(height: 8), // Cancel Previous Alert Button
              StreamBuilder<bool>(
                stream: _emergencyService.emergencyActiveStream,
                builder: (context, snapshot) {
                  final isAllowed = _emergencyService.isCancellationAllowed;
                  final timeRemaining =
                      _emergencyService.cancellationTimeRemaining;
                  final isActiveEmergency = _emergencyService.isEmergencyActive;

                  // Dynamic button text based on emergency state
                  final buttonText = isActiveEmergency
                      ? 'CANCEL ACTIVE EMERGENCY'
                      : 'CANCEL & STOP ALERTS';

                  return Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: isAllowed
                            ? () async {
                                final success = await _emergencyService
                                    .sendManualCancellationMessage();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success
                                            ? 'Emergency cancelled and all alerts stopped'
                                            : 'Failed to cancel emergency',
                                      ),
                                      backgroundColor: success
                                          ? Colors.green
                                          : Colors.red,
                                      duration: const Duration(seconds: 4),
                                    ),
                                  );
                                }
                              }
                            : null,
                        icon: const Icon(Icons.cancel),
                        label: Text(buttonText),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isAllowed
                              ? Colors.orange
                              : Colors.grey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                      if (isAllowed && timeRemaining != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Available for $timeRemaining more minute${timeRemaining != 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[700],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      else if (!isAllowed)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'No recent alert to cancel (or already stopped)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 16),
            ],
          ),
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
