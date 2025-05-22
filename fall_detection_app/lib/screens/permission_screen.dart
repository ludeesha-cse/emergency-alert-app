import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionScreen extends StatefulWidget {
  final Widget nextScreen;

  const PermissionScreen({Key? key, required this.nextScreen})
    : super(key: key);

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  final List<PermissionInfo> _permissions = [
    PermissionInfo(
      permission: Permission.locationAlways,
      title: 'Location Access (Background)',
      description:
          'Required to send your location to emergency contacts in case of a fall.',
      isGranted: false,
    ),
    PermissionInfo(
      permission: Permission.microphone,
      title: 'Microphone',
      description:
          'Used to detect sounds that might indicate a fall or emergency.',
      isGranted: false,
    ),
    PermissionInfo(
      permission: Permission.sms,
      title: 'SMS',
      description:
          'Allows the app to send SMS alerts to your emergency contacts.',
      isGranted: false,
    ),
    PermissionInfo(
      permission: Permission.activityRecognition,
      title: 'Motion Sensors',
      description:
          'Required to detect falls using your device\'s accelerometer and gyroscope.',
      isGranted: false,
    ),
    PermissionInfo(
      permission: Permission.notification,
      title: 'Notifications',
      description:
          'Enables the app to run in the background and show important alerts.',
      isGranted: false,
    ),
  ];

  bool _isLoading = false;
  bool _allPermissionsGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() {
      _isLoading = true;
    });

    for (var i = 0; i < _permissions.length; i++) {
      final status = await _permissions[i].permission.status;
      setState(() {
        _permissions[i].isGranted = status.isGranted;
      });
    }

    _updateAllPermissionsStatus();

    setState(() {
      _isLoading = false;
    });
  }

  void _updateAllPermissionsStatus() {
    setState(() {
      _allPermissionsGranted = _permissions.every((p) => p.isGranted);
    });
  }

  Future<void> _requestPermission(int index) async {
    final permissionInfo = _permissions[index];

    // Special handling for location permission
    if (permissionInfo.permission == Permission.locationAlways) {
      // First request foreground permission
      final locationWhenInUse = await Permission.locationWhenInUse.request();

      if (locationWhenInUse.isGranted) {
        // Now request background permission
        final locationAlways = await Permission.locationAlways.request();
        setState(() {
          permissionInfo.isGranted = locationAlways.isGranted;
        });
      } else {
        setState(() {
          permissionInfo.isGranted = false;
        });
      }
    } else {
      // Request other permissions normally
      final status = await permissionInfo.permission.request();
      setState(() {
        permissionInfo.isGranted = status.isGranted;
      });
    }

    _updateAllPermissionsStatus();
  }

  Future<void> _requestAllPermissions() async {
    setState(() {
      _isLoading = true;
    });

    // Request location permissions first
    final locationWhenInUse = await Permission.locationWhenInUse.request();
    if (locationWhenInUse.isGranted) {
      await Permission.locationAlways.request();
    } // Then request all other permissions
    await Permission.microphone.request();
    await Permission.sms.request();
    await Permission.activityRecognition.request();
    await Permission.notification.request();

    // Check the status of all permissions
    await _checkPermissions();

    setState(() {
      _isLoading = false;
    });
  }

  void _navigateNext() {
    if (_allPermissionsGranted) {
      // If this screen was pushed onto the stack, pop and return true
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      } else {
        // Otherwise replace with the next screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => widget.nextScreen),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please grant all permissions to continue'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openAppSettings() {
    openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Required Permissions'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'To ensure the Fall Detection App works correctly, please grant the following permissions:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _permissions.length,
                    itemBuilder: (context, index) {
                      final permissionInfo = _permissions[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      permissionInfo.title,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    permissionInfo.isGranted
                                        ? Icons.check_circle
                                        : Icons.error,
                                    color: permissionInfo.isGranted
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                permissionInfo.description,
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 16),
                              if (!permissionInfo.isGranted)
                                ElevatedButton(
                                  onPressed: () => _requestPermission(index),
                                  child: const Text('Grant Permission'),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: _requestAllPermissions,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text('Request All Permissions'),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _allPermissionsGranted
                            ? _navigateNext
                            : _openAppSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _allPermissionsGranted
                              ? Theme.of(context).colorScheme.secondary
                              : Colors.grey,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: Text(
                          _allPermissionsGranted ? 'Continue' : 'Open Settings',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class PermissionInfo {
  final Permission permission;
  final String title;
  final String description;
  bool isGranted;

  PermissionInfo({
    required this.permission,
    required this.title,
    required this.description,
    required this.isGranted,
  });
}
