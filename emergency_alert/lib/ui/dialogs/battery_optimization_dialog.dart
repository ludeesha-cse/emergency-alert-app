import 'package:flutter/material.dart';
import '../../services/permission_service.dart';

class BatteryOptimizationDialog extends StatelessWidget {
  const BatteryOptimizationDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.battery_alert, color: Colors.orange),
          SizedBox(width: 8),
          Text('Battery Optimization'),
        ],
      ),
      content: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'To ensure the emergency alert app works reliably in the background, please disable battery optimization for this app.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              'Manual Steps:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text('1. Tap "Open Settings" below'),
            SizedBox(height: 4),
            Text('2. Find and select "Emergency Alert" from the app list'),
            SizedBox(height: 4),
            Text('3. Select "Don\'t optimize" or "Not optimized"'),
            SizedBox(height: 4),
            Text('4. Tap "Done" or "Back"'),
            SizedBox(height: 16),
            Text(
              'This setting allows the app to continue monitoring for emergencies even when not actively in use.',
              style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final permissionService = PermissionService();

            // Try to open settings
            await permissionService.openSettings();

            // Close dialog and return true indicating user was guided to settings
            if (context.mounted) {
              Navigator.of(context).pop(true);
            }
          },
          child: const Text('Open Settings'),
        ),
      ],
    );
  }

  /// Show the battery optimization guidance dialog
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const BatteryOptimizationDialog(),
    );
  }
}
