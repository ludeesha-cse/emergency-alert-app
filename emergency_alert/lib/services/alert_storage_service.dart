import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alert.dart';
import '../utils/constants.dart';

/// Service for managing alert history storage
class AlertStorageService {
  /// Load all alerts from storage
  Future<List<Alert>> loadAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson =
          prefs.getStringList(AppConstants.keyAlertHistory) ?? [];

      final alerts = historyJson
          .map((json) => Alert.fromJson(jsonDecode(json)))
          .toList();

      // Sort by timestamp, most recent first
      alerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return alerts;
    } catch (e) {
      print('Error loading alerts from storage: $e');
      return [];
    }
  }

  /// Save an alert to storage
  Future<void> saveAlert(Alert alert) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson =
          prefs.getStringList(AppConstants.keyAlertHistory) ?? [];

      // Add new alert
      historyJson.add(jsonEncode(alert.toJson()));

      // Keep only last 100 alerts
      if (historyJson.length > 100) {
        historyJson.removeAt(0);
      }

      await prefs.setStringList(AppConstants.keyAlertHistory, historyJson);
    } catch (e) {
      print('Error saving alert to storage: $e');
      throw Exception('Failed to save alert: $e');
    }
  }

  /// Update an existing alert in storage
  Future<void> updateAlert(Alert updatedAlert) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson =
          prefs.getStringList(AppConstants.keyAlertHistory) ?? [];

      // Find and update the alert
      bool found = false;
      for (int i = 0; i < historyJson.length; i++) {
        final alertData = jsonDecode(historyJson[i]);
        if (alertData['id'] == updatedAlert.id) {
          historyJson[i] = jsonEncode(updatedAlert.toJson());
          found = true;
          break;
        }
      }

      if (!found) {
        // If alert doesn't exist, add it
        historyJson.add(jsonEncode(updatedAlert.toJson()));
      }

      // Keep only last 100 alerts
      if (historyJson.length > 100) {
        historyJson.removeAt(0);
      }

      await prefs.setStringList(AppConstants.keyAlertHistory, historyJson);
    } catch (e) {
      print('Error updating alert in storage: $e');
      throw Exception('Failed to update alert: $e');
    }
  }

  /// Delete an alert from storage
  Future<void> deleteAlert(String alertId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson =
          prefs.getStringList(AppConstants.keyAlertHistory) ?? [];

      // Remove the alert with matching ID
      historyJson.removeWhere((json) {
        final alertData = jsonDecode(json);
        return alertData['id'] == alertId;
      });

      await prefs.setStringList(AppConstants.keyAlertHistory, historyJson);
    } catch (e) {
      print('Error deleting alert from storage: $e');
      throw Exception('Failed to delete alert: $e');
    }
  }

  /// Clear all alerts from storage
  Future<void> clearAllAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.keyAlertHistory);
    } catch (e) {
      print('Error clearing alerts from storage: $e');
      throw Exception('Failed to clear alerts: $e');
    }
  }

  /// Get alerts by type
  Future<List<Alert>> getAlertsByType(AlertType type) async {
    final allAlerts = await loadAlerts();
    return allAlerts.where((alert) => alert.type == type).toList();
  }

  /// Get alerts by status
  Future<List<Alert>> getAlertsByStatus(AlertStatus status) async {
    final allAlerts = await loadAlerts();
    return allAlerts.where((alert) => alert.status == status).toList();
  }

  /// Get alert count
  Future<int> getAlertCount() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList(AppConstants.keyAlertHistory) ?? [];
    return historyJson.length;
  }

  /// Get recent alerts (last N alerts)
  Future<List<Alert>> getRecentAlerts({int limit = 10}) async {
    final allAlerts = await loadAlerts();
    return allAlerts.take(limit).toList();
  }

  /// Export alerts as JSON string
  Future<String> exportAlerts() async {
    try {
      final alerts = await loadAlerts();
      final alertsJson = alerts.map((alert) => alert.toJson()).toList();
      return jsonEncode(alertsJson);
    } catch (e) {
      print('Error exporting alerts: $e');
      throw Exception('Failed to export alerts: $e');
    }
  }

  /// Import alerts from JSON string
  Future<void> importAlerts(String jsonString, {bool append = true}) async {
    try {
      final List<dynamic> alertsJson = jsonDecode(jsonString);
      final List<Alert> importedAlerts = alertsJson
          .map((json) => Alert.fromJson(json))
          .toList();

      if (!append) {
        // Clear existing alerts if not appending
        await clearAllAlerts();
      }

      // Save each imported alert
      for (final alert in importedAlerts) {
        await saveAlert(alert);
      }
    } catch (e) {
      print('Error importing alerts: $e');
      throw Exception('Failed to import alerts: $e');
    }
  }

  /// Get alerts statistics
  Future<Map<String, dynamic>> getAlertsStatistics() async {
    try {
      final alerts = await loadAlerts();

      final byType = <String, int>{};
      final byStatus = <String, int>{};
      final bySeverity = <String, int>{};

      final stats = {
        'total': alerts.length,
        'byType': byType,
        'byStatus': byStatus,
        'bySeverity': bySeverity,
        'lastWeek': 0,
        'lastMonth': 0,
      };

      final now = DateTime.now();
      final oneWeekAgo = now.subtract(const Duration(days: 7));
      final oneMonthAgo = now.subtract(const Duration(days: 30));

      for (final alert in alerts) {
        // Count by type
        final typeKey = alert.type.toString().split('.').last;
        byType[typeKey] = (byType[typeKey] ?? 0) + 1;

        // Count by status
        final statusKey = alert.status.toString().split('.').last;
        byStatus[statusKey] = (byStatus[statusKey] ?? 0) + 1;

        // Count by severity
        final severityKey = alert.severity.toString().split('.').last;
        bySeverity[severityKey] = (bySeverity[severityKey] ?? 0) + 1;

        // Count recent alerts
        if (alert.timestamp.isAfter(oneWeekAgo)) {
          stats['lastWeek'] = (stats['lastWeek'] as int) + 1;
        }
        if (alert.timestamp.isAfter(oneMonthAgo)) {
          stats['lastMonth'] = (stats['lastMonth'] as int) + 1;
        }
      }

      return stats;
    } catch (e) {
      print('Error getting alerts statistics: $e');
      return {};
    }
  }
}
