import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../services/sensor/sensor_service.dart';
import '../../services/location/location_service.dart';
import '../../services/background/background_service.dart';
import '../../services/permission_service.dart';
import '../../services/emergency_response_service.dart';
import '../../services/logger/logger_service.dart';
import '../../utils/permission_helper.dart';
import '../../utils/permission_fallbacks.dart';
import '../../utils/constants.dart';
import '../../models/sensor_data.dart';
import '../../models/alert.dart';
import '../screens/permission_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // GlobalKey for ScaffoldMessenger to avoid widget deactivation issues
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

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

    // Check if this is a panic button activation
    final isPanicButton = alertType == 'Panic Button Activated';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StreamBuilder<int>(
        stream: _emergencyService.countdownStream,
        builder: (context, snapshot) {
          final remainingSeconds =
              snapshot.data ?? AppConstants.alertCountdownSeconds;

          return AlertDialog(
            title: Text(alertType),
            content: Text(
              isPanicButton
                  ? 'Panic button activated! Emergency alerts are sounding. Emergency contacts will be notified in $remainingSeconds seconds.\n\n'
                        '• Press "Send Now" to notify immediately\n'
                        '• Press "Stop Local Alert" to silence alarms but keep countdown\n'
                        '• Press "Cancel" if this was accidental'
                  : 'An emergency has been detected! Emergency alerts are sounding. Emergency contacts will be notified in $remainingSeconds seconds.\n\n'
                        '• Press "Send Now" to notify immediately\n'
                        '• Press "Stop Local Alert" to silence alarms but keep countdown\n'
                        '• Press "Cancel" if this is a false alarm',
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  print('🛑 Emergency cancelled by user');
                  Navigator.of(context).pop();
                  _isEmergencyModalShowing = false;
                  await _emergencyService.cancelEmergency();

                  // Show immediate feedback - use a delay to avoid widget deactivation
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Emergency cancelled. All alerts stopped.',
                          ),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  });
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  print('🔇 Stopping local alerts only');
                  await _stopLocalAlert();
                },
                style: TextButton.styleFrom(foregroundColor: Colors.orange),
                child: const Text('Stop Local Alert'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  _isEmergencyModalShowing = false;
                  await _emergencyService.sendEmergencyImmediately();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPanicButton ? Colors.red : null,
                ),
                child: const Text('Send Now'),
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

  /// Stop local alert sounds, vibration, and flashlight without cancelling the emergency
  Future<void> _stopLocalAlert() async {
    try {
      print('🔇 User requested to stop local alerts');

      // Use the emergency service's centralized method to stop local alerts
      await _emergencyService.stopLocalAlerts();

      // Force a second emergency reset after a short delay to catch any lingering audio
      await Future.delayed(const Duration(milliseconds: 200));
      await _emergencyService.stopLocalAlerts();

      // Show confirmation snackbar using the global key to avoid widget deactivation issues
      if (mounted) {
        // Use safe snackbar display method
        _showSafeSnackBar(
          'Local alert stopped. Emergency countdown continues.',
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      LoggerService.error('Error stopping local alert: $e');

      // Even if there was an error, try one more emergency reset
      try {
        await _emergencyService.stopLocalAlerts();
      } catch (_) {}
    }
  }

  // Helper method to safely show snackbars using the global key
  void _showSafeSnackBar(String message, {Duration? duration}) {
    try {
      // If context is still valid, use direct context method
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: duration ?? const Duration(seconds: 2),
          ),
        );
      } else {
        // Fallback to global key if context is no longer valid
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(message),
            duration: duration ?? const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Last resort fallback if both methods fail
      print('⚠️ Could not show snackbar: $e');
    }
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
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
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
                  onPressed: () {
                    print(
                      '🚨 PANIC BUTTON PRESSED - Starting immediate response',
                    );

                    // Show immediate feedback
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🚨 PANIC BUTTON ACTIVATED! 🚨'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 2),
                      ),
                    );

                    // Show popup immediately
                    _showEmergencyAlert('Panic Button Activated');

                    // Trigger immediate emergency response with local alerts in parallel
                    _emergencyService
                        .triggerImmediateManualEmergency()
                        .then((_) {
                          print('✅ Emergency service triggered');
                        })
                        .catchError((e) {
                          print('❌ Error triggering emergency service: $e');
                        });
                  },
                  icon: const Icon(Icons.warning),
                  label: const Text('PANIC BUTTON'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),

                const SizedBox(height: 8),

                // Stop Local Alerts Button
                StreamBuilder<bool>(
                  stream: _emergencyService.emergencyActiveStream,
                  builder: (context, emergencySnapshot) {
                    return StreamBuilder<int>(
                      stream: _emergencyService.countdownStream,
                      builder: (context, countdownSnapshot) {
                        final isEmergencyActive =
                            emergencySnapshot.data ?? false;
                        final hasLocalServices =
                            _emergencyService.hasActiveLocalServices;
                        final shouldEnable =
                            isEmergencyActive && hasLocalServices;

                        return ElevatedButton.icon(
                          onPressed: shouldEnable
                              ? () async {
                                  try {
                                    print(
                                      '🔇 User requested to stop all local alerts',
                                    );

                                    // Stop all local alerts
                                    await _emergencyService.stopLocalAlerts();

                                    // Show feedback
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            '🔇 Local alerts stopped. Emergency countdown continues.',
                                          ),
                                          backgroundColor: Colors.orange,
                                          duration: Duration(seconds: 3),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    print('❌ Error stopping local alerts: $e');
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            '❌ Error stopping local alerts',
                                          ),
                                          backgroundColor: Colors.red,
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  }
                                }
                              : null,
                          icon: Icon(
                            shouldEnable
                                ? Icons.volume_off
                                : Icons.volume_off_outlined,
                          ),
                          label: const Text('STOP LOCAL ALERTS'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: shouldEnable
                                ? Colors.orange
                                : Colors.grey[300],
                            foregroundColor: shouldEnable
                                ? Colors.white
                                : Colors.grey[600],
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void deactivate() {
    // This is called when the widget is removed from the widget tree
    // It's a good place to force emergency reset in case there are any ongoing alerts
    super.deactivate();
    if (_emergencyService.isEmergencyActive) {
      try {
        LoggerService.warning(
          'Detected widget deactivation with active emergency - forcing stop',
        );
        _emergencyService.stopLocalAlerts();
      } catch (e) {
        LoggerService.error('Error during deactivate emergency stop: $e');
      }
    }
  }

  @override
  void dispose() {
    _sensorService.dispose();
    _locationService.dispose();
    // Ensure any active emergency alerts are stopped
    _emergencyService.stopLocalAlerts().catchError((_) {});
    super.dispose();
  }
}
