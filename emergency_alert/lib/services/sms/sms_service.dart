import 'dart:async';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/contact.dart';
import '../../models/alert.dart';

class SmsService {
  static final SmsService _instance = SmsService._internal();
  factory SmsService() => _instance;
  SmsService._internal();

  // Platform channel for SMS sending
  static const MethodChannel _channel = MethodChannel(
    'com.emergency_alert/sms',
  );

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

  /// Send SMS directly using platform channel
  Future<bool> _sendDirectSMS({
    required String message,
    required List<String> phoneNumbers,
  }) async {
    try {
      final result = await _channel.invokeMethod('sendSMS', {
        'message': message,
        'phoneNumbers': phoneNumbers,
      });
      return result == true;
    } catch (e) {
      print("Error sending direct SMS: $e");
      return false;
    }
  } // Added for ContactsScreen

  Future<bool> sendTestMessage(
    EmergencyContact contact,
    String userName,
  ) async {
    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) {
        print("SMS permissions not granted");
        return false;
      }

      final message =
          "This is a test message from $userName''s Emergency Alert app.";

      try {
        // Try to send SMS directly using platform channel
        final success = await _sendDirectSMS(
          message: message,
          phoneNumbers: [contact.phoneNumber],
        );

        if (success) {
          print("Test SMS sent to ${contact.name}");
          return true;
        } else {
          throw Exception("Platform channel SMS failed");
        }
      } catch (e) {
        print("Error sending direct SMS: $e");
        // Fallback to URL launcher method
        final url = Uri.parse(
          "sms:${contact.phoneNumber}?body=${Uri.encodeComponent(message)}",
        );

        if (await canLaunchUrl(url)) {
          await launchUrl(url);
          return true;
        } else {
          print("Could not launch SMS app for ${contact.name}");
          return false;
        }
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
      final phoneNumbers = contacts
          .where((c) => c.isEnabled)
          .map((c) => c.phoneNumber)
          .toList();

      if (phoneNumbers.isEmpty) {
        print("No enabled contacts found");
        return false;
      }
      try {
        // Try to send SMS directly using platform channel
        final success = await _sendDirectSMS(
          message: message,
          phoneNumbers: phoneNumbers,
        );

        if (success) {
          print("Emergency SMS sent to ${phoneNumbers.length} contacts");
        } else {
          throw Exception("Platform channel SMS failed");
        }
      } catch (e) {
        print("Error sending direct SMS: $e");
        // Fallback to URL launcher method if direct sending fails
        for (final contact in contacts.where((c) => c.isEnabled)) {
          try {
            final url = Uri.parse(
              "sms:${contact.phoneNumber}?body=${Uri.encodeComponent(message)}",
            );

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
      case AlertType.manual:
        return "Manual Emergency";
    }
  }

  Future<bool> sendCancellationMessage({
    required List<EmergencyContact> contacts,
    required Alert alert,
  }) async {
    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) {
        print("SMS permissions not granted");
        return false;
      }

      final message = _buildCancellationMessage(alert);

      bool allSent = true;
      final phoneNumbers = contacts
          .where((c) => c.isEnabled)
          .map((c) => c.phoneNumber)
          .toList();

      if (phoneNumbers.isEmpty) {
        print("No enabled contacts found");
        return false;
      }
      try {
        // Try to send SMS directly using platform channel
        final success = await _sendDirectSMS(
          message: message,
          phoneNumbers: phoneNumbers,
        );

        if (success) {
          print("Cancellation SMS sent to ${phoneNumbers.length} contacts");
        } else {
          throw Exception("Platform channel SMS failed");
        }
      } catch (e) {
        print("Error sending direct cancellation SMS: $e");
        // Fallback to URL launcher method
        for (final contact in contacts.where((c) => c.isEnabled)) {
          try {
            final url = Uri.parse(
              "sms:${contact.phoneNumber}?body=${Uri.encodeComponent(message)}",
            );

            if (await canLaunchUrl(url)) {
              await launchUrl(url);
            } else {
              print("Could not launch SMS app for ${contact.name}");
              allSent = false;
            }
          } catch (e) {
            print("Error sending cancellation SMS to ${contact.name}: $e");
            allSent = false;
          }
        }
      }

      return allSent;
    } catch (e) {
      print("Error sending cancellation SMS: $e");
      return false;
    }
  }

  String _buildCancellationMessage(Alert alert) {
    final buffer = StringBuffer();

    buffer.writeln("ALERT CANCELLED");
    buffer.writeln(
      "Previous emergency alert for ${_alertTypeToString(alert.type)} has been cancelled.",
    );
    buffer.writeln(
      "Time cancelled: ${DateTime.now().toString().substring(0, 19)}",
    );
    buffer.writeln("The person is safe and no longer needs assistance.");
    buffer.writeln("Sent via Emergency Alert App");

    return buffer.toString();
  }

  void dispose() {
    _smsSentController.close();
  }
}
