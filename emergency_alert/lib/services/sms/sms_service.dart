import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/contact.dart';
import '../../models/alert.dart';
import '../../utils/constants.dart';

class SmsService {
  static final SmsService _instance = SmsService._internal();
  factory SmsService() => _instance;
  SmsService._internal();

  final StreamController<bool> _smsSentController =
      StreamController<bool>.broadcast();
  Stream<bool> get smsSentStream => _smsSentController.stream;

  Future<bool> checkPermissions() async {
    try {
      final status = await Permission.sms.request();
      return status == PermissionStatus.granted;
    } catch (e) {
      print("Error checking SMS permissions: $e");
      return false;
    }
  }

  // Added for ContactsScreen
  Future<bool> sendTestMessage(EmergencyContact contact, String userName) async {
    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) {
        print("SMS permissions not granted");
        return false;
      }

      final message = "This is a test message from $userName''s Emergency Alert app.";
      
      final url = Uri.parse("sms:${contact.phoneNumber}?body=${Uri.encodeComponent(message)}");
      
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
        return true;
      } else {
        print("Could not launch SMS app for ${contact.name}");
        return false;
      }
    } catch (e) {
      print("Error sending test SMS: $e");
      return false;
    }
  }

  // Added for form validation
  bool isValidPhoneNumber(String phoneNumber) {
    // Basic phone number validation - can be enhanced as needed
    final cleanNumber = phoneNumber.replaceAll(RegExp(r"[^\d+]"), "");
    
    // Check if it has at least 10 digits after removing non-digit characters
    if (cleanNumber.length < 10) return false;
    
    // Additional validation logic can be added here
    return true;
  }

  Future<bool> sendEmergencyAlert({
    required List<EmergencyContact> contacts,
    required Alert alert,
    String? customMessage,
    String? locationInfo,
  }) async {
    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) {
        print("SMS permissions not granted");
        return false;
      }

      final message = _buildEmergencyMessage(
        alert: alert,
        customMessage: customMessage,
        locationInfo: locationInfo,
      );

      bool allSent = true;
      for (final contact in contacts.where((c) => c.isEnabled)) {
        try {
          // Use URL launcher to send SMS
          final url = Uri.parse("sms:${contact.phoneNumber}?body=${Uri.encodeComponent(message)}");
          
          if (await canLaunchUrl(url)) {
            await launchUrl(url);
          } else {
            print("Could not launch SMS app for ${contact.name}");
            allSent = false;
          }
        } catch (e) {
          print("Error sending SMS to ${contact.name}: $e");
          allSent = false;
        }
      }

      _smsSentController.add(allSent);
      return allSent;
    } catch (e) {
      print("Error sending emergency SMS: $e");
      _smsSentController.add(false);
      return false;
    }
  }

  String _buildEmergencyMessage({
    required Alert alert,
    String? customMessage,
    String? locationInfo,
  }) {
    final buffer = StringBuffer();

    // Add alert prefix
    buffer.writeln("EMERGENCY ALERT");

    // Add alert type
    buffer.writeln("Type: ${_alertTypeToString(alert.type)}");

    // Add timestamp
    buffer.writeln("Time: ${alert.timestamp.toString().substring(0, 19)}");

    // Add location info if available
    if (locationInfo != null && locationInfo.isNotEmpty) {
      buffer.writeln(locationInfo);
    } else if (alert.latitude != null && alert.longitude != null) {
      buffer.writeln("Location: ${alert.latitude}, ${alert.longitude}");
      if (alert.address != null && alert.address!.isNotEmpty) {
        buffer.writeln("Address: ${alert.address}");
      }
    }

    // Add custom message if provided
    if (customMessage != null && customMessage.isNotEmpty) {
      buffer.writeln(customMessage);
    }

    // Add app signature
    buffer.writeln("Sent via Emergency Alert App");

    return buffer.toString();
  }

  String _alertTypeToString(AlertType type) {
    switch (type) {
      case AlertType.fall:
        return "Fall Detected";
      case AlertType.impact:
        return "Impact/Crash Detected";
      case AlertType.panicButton:
        return "Panic Button Pressed";
      case AlertType.inactivity:
        return "Inactivity Alert";
      case AlertType.medicalEmergency:
        return "Medical Emergency";
      case AlertType.custom:
        return "Custom Alert";
      default:
        return "Emergency";
    }
  }

  void dispose() {
    _smsSentController.close();
  }
}
