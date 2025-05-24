import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/alert.dart';
import '../../services/alert_storage_service.dart';

class AlertHistoryScreen extends StatefulWidget {
  const AlertHistoryScreen({super.key});

  @override
  State<AlertHistoryScreen> createState() => _AlertHistoryScreenState();
}

class _AlertHistoryScreenState extends State<AlertHistoryScreen> {
  List<Alert> _alerts = [];
  bool _isLoading = true;
  String _filterType = 'All';

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);

    try {
      final alertStorage = AlertStorageService();
      final alerts = await alertStorage.loadAlerts();
      
      setState(() {
        _alerts = alerts;
        
        // If no alerts were found from storage, use sample alerts for demo purposes
        if (_alerts.isEmpty) {
          _alerts = sampleAlerts;
        }
        
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading alerts: $e');
      setState(() {
        // Fall back to sample alerts on error
        _alerts = sampleAlerts;
        _isLoading = false;
      });
    }
  }

  List<Alert> get sampleAlerts => [
    Alert(
      id: '1',
      type: AlertType.fall,
      severity: AlertSeverity.high,
      status: AlertStatus.resolved,
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      customMessage: 'Fall detected - user may need assistance',
      latitude: 37.7749,
      longitude: -122.4194,
      address: 'San Francisco, CA',
      sentToContacts: ['Emergency Contact 1', 'Emergency Contact 2'],
      resolvedAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    Alert(
      id: '2',
      type: AlertType.impact,
      severity: AlertSeverity.medium,
      status: AlertStatus.resolved,
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      customMessage: 'High impact detected',
      latitude: 37.7849,
      longitude: -122.4094,
      address: 'San Francisco, CA',
      sentToContacts: ['Emergency Contact 1'],
      resolvedAt: DateTime.now().subtract(const Duration(hours: 22)),
    ),
    Alert(
      id: '3',
      type: AlertType.panicButton,
      severity: AlertSeverity.critical,
      status: AlertStatus.sent,
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
      customMessage: 'Manual panic button activated',
      latitude: 37.7649,
      longitude: -122.4294,
      address: 'San Francisco, CA',
      sentToContacts: [
        'Emergency Contact 1',
        'Emergency Contact 2',
        'Family Member',
      ],
    ),
    Alert(
      id: '4',
      type: AlertType.fall,
      severity: AlertSeverity.low,
      status: AlertStatus.resolved,
      timestamp: DateTime.now().subtract(const Duration(days: 7)),
      customMessage: 'Potential fall detected',
      latitude: 37.7549,
      longitude: -122.4394,
      address: 'San Francisco, CA',
      sentToContacts: [],
      resolvedAt: DateTime.now().subtract(const Duration(days: 7)),
    ),
  ];
  List<Alert> get _filteredAlerts {
    if (_filterType == 'All') return _alerts;

    final type = AlertType.values.firstWhere(
      (t) =>
          t.toString().split('.').last.toLowerCase() ==
          _filterType.toLowerCase(),
      orElse: () => AlertType.fall,
    );

    return _alerts.where((alert) => alert.type == type).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alert History'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _filterType = value);
            },            itemBuilder: (context) => [
              const PopupMenuItem(value: 'All', child: Text('All Alerts')),
              const PopupMenuItem(value: 'fall', child: Text('Fall Detection')),
              const PopupMenuItem(
                value: 'impact',
                child: Text('Impact Detection'),
              ),
              const PopupMenuItem(
                value: 'panicButton',
                child: Text('Panic Button'),
              ),
              const PopupMenuItem(
                value: 'manual',
                child: Text('Manual Emergency'),
              ),
              const PopupMenuItem(
                value: 'inactivity',
                child: Text('Inactivity'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredAlerts.isEmpty
          ? _buildEmptyState()
          : _buildAlertsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No alerts found',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            _filterType == 'All'
                ? 'Your emergency alerts will appear here'
                : 'No ${_filterType.toLowerCase()} alerts found',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsList() {
    return RefreshIndicator(
      onRefresh: _loadAlerts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _filteredAlerts.length,
        itemBuilder: (context, index) {
          final alert = _filteredAlerts[index];
          return _buildAlertCard(alert);
        },
      ),
    );
  }

  Widget _buildAlertCard(Alert alert) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () => _showAlertDetails(alert),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildAlertIcon(alert.type),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.alertTypeDescription,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          dateFormat.format(alert.timestamp),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(alert),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                alert.customMessage ?? alert.alertTypeDescription,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (alert.address != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        alert.address!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (alert.sentToContacts.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.people, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Notified: ${alert.sentToContacts.join(', ')}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }  Widget _buildAlertIcon(AlertType type) {
    IconData icon;
    Color color;

    switch (type) {
      case AlertType.fall:
        icon = Icons.personal_injury;
        color = Colors.orange;
        break;
      case AlertType.impact:
        icon = Icons.warning;
        color = Colors.red;
        break;
      case AlertType.panicButton:
        icon = Icons.emergency;
        color = Colors.red;
        break;
      case AlertType.manual:
        icon = Icons.touch_app;
        color = Colors.red;
        break;
      case AlertType.inactivity:
        icon = Icons.timer_off;
        color = Colors.blue;
        break;
      case AlertType.medicalEmergency:
        icon = Icons.medical_services;
        color = Colors.red;
        break;
      case AlertType.custom:
        icon = Icons.notifications;
        color = Colors.purple;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
  Widget _buildStatusChip(Alert alert) {
    bool isResolved = alert.status == AlertStatus.resolved;
    Color color = isResolved ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isResolved
            ? 'Resolved'
            : alert.status.toString().split('.').last.toUpperCase(),
        style: TextStyle(
          color: isResolved ? Colors.green.shade700 : Colors.orange.shade700,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showAlertDetails(Alert alert) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(alert.alertTypeDescription),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow(
                'Time',
                DateFormat('MMM dd, yyyy HH:mm:ss').format(alert.timestamp),
              ),
              _buildDetailRow('Severity', alert.severityDescription),
              _buildDetailRow(
                'Status',
                alert.status.toString().split('.').last.toUpperCase(),
              ),
              if (alert.customMessage != null)
                _buildDetailRow('Message', alert.customMessage!),
              if (alert.resolvedAt != null)
                _buildDetailRow(
                  'Resolved At',
                  DateFormat('MMM dd, yyyy HH:mm:ss').format(alert.resolvedAt!),
                ),
              if (alert.address != null)
                _buildDetailRow('Location', alert.address!),
              if (alert.latitude != null && alert.longitude != null)
                _buildDetailRow(
                  'Coordinates',
                  '${alert.latitude!.toStringAsFixed(6)}, ${alert.longitude!.toStringAsFixed(6)}',
                ),
              if (alert.sentToContacts.isNotEmpty)
                _buildDetailRow(
                  'Contacts Notified',
                  alert.sentToContacts.join('\n'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (alert.status != AlertStatus.resolved)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resolveAlert(alert);
              },
              child: const Text('Mark Resolved'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(value),
        ],
      ),
    );
  }
  void _resolveAlert(Alert alert) async {
    // Create a new alert with resolved status using copyWith
    final resolvedAlert = alert.copyWith(
      status: AlertStatus.resolved,
      resolvedAt: DateTime.now(),
    );

    setState(() {
      final index = _alerts.indexWhere((a) => a.id == alert.id);
      if (index != -1) {
        _alerts[index] = resolvedAlert;
      }
    });

    // Update alert in storage
    try {
      final alertStorage = AlertStorageService();
      await alertStorage.updateAlert(resolvedAlert);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alert marked as resolved'))
      );
    } catch (e) {
      print('Error updating alert: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update alert'))
      );
    }
  }
}
