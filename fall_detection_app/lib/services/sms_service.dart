import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

/// A service class for handling SMS functionality.
class SmsService {
  /// Sends an SMS message with the specified text to a list of recipients.
  /// If a position is provided, it will be appended to the message.
  static Future<bool> sendSms({
    required List<String> recipients,
    required String message,
    Position? position,
  }) async {
    try {
      // Check for SMS permission
      if (!await _checkSmsPermission()) {
        debugPrint('SMS permission not granted');
        return false;
      }

      // Append location information if available
      String finalMessage = message;
      if (position != null) {
        // Add Google Maps link
        final locationLink =
            'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';
        finalMessage += '\nMy current location: $locationLink';
      }

      // Use platform-specific SMS sending
      if (Platform.isAndroid) {
        return await _sendSmsAndroid(recipients, finalMessage);
      } else if (Platform.isIOS) {
        return await _sendSmsIos(recipients, finalMessage);
      }

      return false;
    } catch (e) {
      debugPrint('Error sending SMS: $e');
      return false;
    }
  }

  /// Checks if SMS permission is granted
  static Future<bool> _checkSmsPermission() async {
    final status = await Permission.sms.status;
    if (status.isGranted) {
      return true;
    }

    final result = await Permission.sms.request();
    return result.isGranted;
  }

  /// Send SMS on Android using platform channels
  static Future<bool> _sendSmsAndroid(
    List<String> recipients,
    String message,
  ) async {
    try {
      // In a real implementation, this would use a platform channel to call
      // Android's SmsManager. For now, we'll simulate it.
      for (final recipient in recipients) {
        debugPrint('Would send SMS to $recipient: $message');
      }
      return true;
    } catch (e) {
      debugPrint('Android SMS error: $e');
      return false;
    }
  }

  /// Send SMS on iOS using platform channels
  static Future<bool> _sendSmsIos(
    List<String> recipients,
    String message,
  ) async {
    try {
      // In a real implementation, this would use a platform channel to call
      // iOS's MFMessageComposeViewController. For now, we'll simulate it.
      for (final recipient in recipients) {
        debugPrint('Would send SMS to $recipient: $message');
      }
      return true;
    } catch (e) {
      debugPrint('iOS SMS error: $e');
      return false;
    }
  }
}
