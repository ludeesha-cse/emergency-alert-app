import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/permission_model.dart';
import '../../services/permission_service.dart';

class PermissionScreen extends StatefulWidget {
  final VoidCallback? onAllPermissionsGranted;

  const PermissionScreen({Key? key, this.onAllPermissionsGranted})
    : super(key: key);

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  late PermissionService _permissionService;
  bool _isLoading = true;
  @override
  void initState() {
    super.initState();
    _permissionService = Provider.of<PermissionService>(context, listen: false);
    _loadPermissionStatus();
  }

  @override
  void dispose() {
    // When this screen is dismissed, return the permission status to any awaiting caller
    if (widget.onAllPermissionsGranted == null && Navigator.canPop(context)) {
      Navigator.pop(context, _permissionService.areAllPermissionsGranted);
    }
    super.dispose();
  }

  Future<void> _loadPermissionStatus() async {
    setState(() => _isLoading = true);
    await _permissionService.checkPermissionStatuses();
    setState(() => _isLoading = false);

    // Call the callback if all permissions are granted
    if (_permissionService.areAllPermissionsGranted &&
        widget.onAllPermissionsGranted != null) {
      widget.onAllPermissionsGranted!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Permissions'), elevation: 0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<PermissionService>(
              builder: (context, permissionService, child) {
                return ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    const _HeaderWidget(),
                    const SizedBox(height: 24),
                    _buildPermissionCard(
                      PermissionModel(
                        name: 'Location',
                        description:
                            'Required to know your position during emergencies and send accurate location to emergency contacts',
                        icon: Icons.location_on,
                        permission: Permission.location,
                        requestPermission:
                            permissionService.requestLocationPermission,
                      ),
                      permissionService.isLocationGranted,
                    ),
                    _buildPermissionCard(
                      PermissionModel(
                        name: 'Background Location',
                        description:
                            'Allows the app to monitor your location even when it\'s not open, essential for automatic emergency detection',
                        icon: Icons.location_searching,
                        permission: Permission.locationAlways,
                        requestPermission: permissionService
                            .requestBackgroundLocationPermission,
                      ),
                      permissionService.isBackgroundLocationGranted,
                    ),
                    _buildPermissionCard(
                      PermissionModel(
                        name: 'Microphone',
                        description:
                            'Needed to detect audio cues for emergencies like shouts for help or distress sounds',
                        icon: Icons.mic,
                        permission: Permission.microphone,
                        requestPermission:
                            permissionService.requestMicrophonePermission,
                      ),
                      permissionService.isMicrophoneGranted,
                    ),
                    _buildPermissionCard(
                      PermissionModel(
                        name: 'SMS',
                        description:
                            'Required to send emergency text messages to your contacts automatically',
                        icon: Icons.sms,
                        permission: Permission.sms,
                        requestPermission:
                            permissionService.requestSmsPermission,
                      ),
                      permissionService.isSmsGranted,
                    ),
                    _buildPermissionCard(
                      PermissionModel(
                        name: 'Sensors',
                        description:
                            'Access to accelerometer and gyroscope to detect falls or sudden movements that might indicate emergencies',
                        icon: Icons.sensors,
                        permission: Permission.sensors,
                        requestPermission: () async =>
                            true, // Sensors usually don't need explicit permission
                      ),
                      permissionService.isSensorsGranted,
                    ),
                    _buildNotificationPermissionCard(permissionService),
                    const SizedBox(height: 24),
                    _buildRequestAllButton(permissionService),
                    if (!permissionService.areAllPermissionsGranted)
                      _buildOpenSettingsButton(permissionService),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildPermissionCard(PermissionModel permissionModel, bool isGranted) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      permissionModel.icon,
                      color: Theme.of(context).primaryColor,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      permissionModel.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                _buildStatusChip(isGranted),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              permissionModel.description,
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
            const SizedBox(height: 16),
            if (!isGranted)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final granted = await permissionModel.requestPermission();
                    if (granted) {
                      await _loadPermissionStatus();
                    } else {
                      // Show rationale if permission is denied
                      _showPermissionDeniedDialog(
                        context,
                        permissionModel.name,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Grant ${permissionModel.name} Permission'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool isGranted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isGranted ? Colors.green.shade100 : Colors.red.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isGranted ? Icons.check_circle : Icons.cancel,
            color: isGranted ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            isGranted ? 'Granted' : 'Required',
            style: TextStyle(
              color: isGranted ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestAllButton(PermissionService permissionService) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: permissionService.areAllPermissionsGranted
            ? null
            : () async {
                final allGranted = await permissionService
                    .requestAllPermissions();
                if (allGranted && widget.onAllPermissionsGranted != null) {
                  widget.onAllPermissionsGranted!();
                }
              },
        icon: const Icon(Icons.security),
        label: const Text('Request All Permissions'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildOpenSettingsButton(PermissionService permissionService) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          onPressed: () async {
            await permissionService.openSettings();
          },
          icon: const Icon(Icons.settings),
          label: const Text('Open App Settings'),
        ),
      ),
    );
  }

  void _showPermissionDeniedDialog(
    BuildContext context,
    String permissionName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$permissionName Permission Denied'),
        content: Text(
          'To use the full features of this emergency app, $permissionName permission is required. Please grant the permission in app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _permissionService.openSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Special handling for notification permissions
  /// On Android 13+, we need to direct users to the system settings
  Widget _buildNotificationPermissionCard(PermissionService permissionService) {
    final isGranted = permissionService.isNotificationGranted;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.notifications,
                      color: Theme.of(context).primaryColor,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                _buildStatusChip(isGranted),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Required for the app to run in background and show important alerts. This permission must be granted in Android system settings on newer devices.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 16),
            if (!isGranted)
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(                      onPressed: () async {
                        final granted = await permissionService
                            .requestNotificationPermission();
                        await _loadPermissionStatus();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(granted 
                                ? 'Notification permission granted' 
                                : 'Notification permission denied'),
                              backgroundColor: granted ? Colors.green : Colors.orange,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Request Notification Permission'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'If the button above does not work, please use the button below to open app settings and enable notifications manually.',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.settings),
                      label: const Text('Open App Settings'),
                      onPressed: () async {
                        await permissionService.openSettings();
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'How to enable: Settings > Apps > Emergency Alert > Notifications > Allow notifications',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _HeaderWidget extends StatelessWidget {
  const _HeaderWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.security,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          const Text(
            'Emergency Alert Permissions',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'The app needs these permissions to function correctly during emergencies. Without these permissions, some features may not work properly.',
            style: TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
