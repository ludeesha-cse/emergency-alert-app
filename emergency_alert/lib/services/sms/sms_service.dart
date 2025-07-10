import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/contact.dart';
import '../../models/alert.dart';
import '../../services/logger/logger_service.dart';

class SmsService {
  static final SmsService _instance = SmsService._internal();
  factory SmsService() => _instance;

  // Method channel for native SMS sending
  final MethodChannel _channel = const MethodChannel('com.emergency_alert/sms');

  // Status stream
  final StreamController<bool> _smsSentController =
      StreamController<bool>.broadcast();
  Stream<bool> get smsSentStream => _smsSentController.stream;

  // Track if we've had a successful SMS send
  bool _hasSuccessfulSend = false;

  SmsService._internal() {
    // Print debug info at initialization
    LoggerService.info('SMS Service initialized');
    _logPlatformInfo();
  }

  // Log platform information for debugging
  void _logPlatformInfo() {
    if (Platform.isAndroid) {
      LoggerService.debug('Running on Android - direct SMS sending available');
    } else if (Platform.isIOS) {
      LoggerService.debug('Running on iOS - direct SMS sending NOT available');
    } else {
      LoggerService.debug(
        'Running on ${Platform.operatingSystem} - SMS capabilities unknown',
      );
    }
  }

  Future<bool> checkPermissions() async {
    try {
      if (!Platform.isAndroid) {
        // iOS doesn't support direct SMS sending but we'll return true
        // since we'll use URL launcher as a fallback
        LoggerService.info(
          'SMS permissions not needed on ${Platform.operatingSystem}',
        );
        return true;
      }

      // First check if permission is already granted
      var status = await Permission.sms.status;

      LoggerService.info('Current SMS permission status: $status');

      if (status == PermissionStatus.granted) {
        return true;
      }

      // If not granted, request it
      LoggerService.info('Requesting SMS permission...');
      status = await Permission.sms.request();

      LoggerService.info('SMS permission request result: $status');
      return status == PermissionStatus.granted;
    } catch (e) {
      LoggerService.error('Error checking SMS permissions: $e');
      return false;
    }
  }

  /// Ensure SMS permissions are ready and try to request them if not
  Future<bool> ensureSmsPermissions() async {
    try {
      // Skip permission check on non-Android platforms
      if (!Platform.isAndroid) {
        LoggerService.info('Not on Android, skipping SMS permission check');
        return true;
      }

      // First check current status
      var status = await Permission.sms.status;
      LoggerService.info('Current SMS permission status: $status');

      if (status == PermissionStatus.granted) {
        return true;
      }

      // If not granted, request permission - try multiple times if needed
      for (int attempt = 1; attempt <= 3; attempt++) {
        LoggerService.info('Requesting SMS permission (attempt $attempt)');

        status = await Permission.sms.request();
        LoggerService.info('SMS permission request result: $status');

        if (status == PermissionStatus.granted) {
          return true;
        }

        if (attempt < 3) {
          // Short delay before retry
          await Future.delayed(Duration(milliseconds: 500));
        }
      }

      // If we reach here, permission was denied despite multiple attempts
      LoggerService.warning('SMS permission denied after multiple attempts');
      return false;
    } catch (e) {
      LoggerService.error('Error checking SMS permissions: $e');
      return false;
    }
  }

  // Added for ContactsScreen
  Future<bool> sendTestMessage(
    EmergencyContact contact,
    String userName,
  ) async {
    try {
      LoggerService.info("📱 Starting test SMS process");

      if (contact.phoneNumber.trim().isEmpty) {
        LoggerService.warning(
          "Empty phone number for test message to ${contact.name}",
        );
        return false;
      }

      // Check permissions for Android
      if (Platform.isAndroid) {
        final hasPermission = await checkPermissions();
        if (!hasPermission) {
          LoggerService.error("SMS permissions not granted for test message");
          return false;
        }
      }

      final message =
          "This is a test message from $userName's Emergency Alert app.";

      LoggerService.info(
        "📝 Test message created, sending to ${contact.name} (${contact.phoneNumber})",
      );

      // For test messages, try automatic SMS via Telephony first, then URL launcher as fallback
      bool success;

      try {
        // Try native SMS first for automatic sending on Android
        if (Platform.isAndroid) {
          success = await _sendDirectSms(contact.phoneNumber, message);

          if (success) {
            LoggerService.info(
              "Automatic SMS sent successfully via native channel to ${contact.name}",
            );
            _hasSuccessfulSend = true;
            return true;
          }
        } else {
          success = false;
        }

        // If telephony sending fails or not on Android, use URL launcher as fallback
        if (!success) {
          success = await _sendSmsViaUrlLauncher(contact.phoneNumber, message);
        }

        if (success) {
          _hasSuccessfulSend = true; // Track successful sending
          LoggerService.info("✅ Test SMS sent successfully to ${contact.name}");
        } else {
          LoggerService.warning(
            "⚠️ Test SMS sending failed for ${contact.name}",
          );
        }
        return success;
      } catch (error) {
        LoggerService.error("❌ Error sending test SMS: $error");
        return false;
      }
    } catch (e) {
      LoggerService.error("❌ Error in test SMS process: $e");
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
      LoggerService.info("🚨 Starting emergency SMS alert process");

      // Validate contacts
      final enabledContacts = contacts.where((c) => c.isEnabled).toList();
      if (enabledContacts.isEmpty) {
        LoggerService.warning("No enabled contacts to send SMS to");
        _smsSentController.add(false);
        return false;
      }

      // Ensure SMS permissions on Android - use our improved method
      if (Platform.isAndroid) {
        final hasPermission = await ensureSmsPermissions();
        if (!hasPermission) {
          LoggerService.error(
            "SMS permissions not granted after multiple attempts - trying to send anyway",
          );
          // We'll still try to send, but log the issue
        } else {
          LoggerService.info("✅ SMS permissions confirmed");
        }
      }

      // Build the emergency message
      final message = _buildEmergencyMessage(
        alert: alert,
        customMessage: customMessage,
        locationInfo: locationInfo,
      );

      LoggerService.info(
        "📝 Emergency message created, sending to ${enabledContacts.length} contacts",
      );

      bool allSent = true;
      int successCount = 0;

      // Process each contact
      for (final contact in enabledContacts) {
        try {
          final phoneNumber = contact.phoneNumber.trim();
          if (phoneNumber.isEmpty) {
            LoggerService.warning("Empty phone number for ${contact.name}");
            continue;
          }

          LoggerService.info(
            "📤 Sending SMS to ${contact.name} ($phoneNumber)",
          );

          // First attempt to send via native SMS for automatic background sending
          // If that fails, fall back to URL launcher
          bool success = false;

          if (Platform.isAndroid) {
            // On Android, use native method channel for automatic sending
            success = await _sendDirectSms(phoneNumber, message);

            if (success) {
              LoggerService.info(
                "Emergency SMS sent automatically via native channel to ${contact.name}",
              );
            } else {
              success = await _sendSmsViaUrlLauncher(phoneNumber, message);
            }
          } else {
            // On iOS and other platforms, use URL launcher directly
            success = await _sendSmsViaUrlLauncher(phoneNumber, message);
          }

          if (success) {
            successCount++;
            LoggerService.info("✅ SMS sent successfully to ${contact.name}");
            _hasSuccessfulSend = true;
          } else {
            LoggerService.warning("⚠️ SMS sending failed for ${contact.name}");
            allSent = false;
          }
        } catch (e) {
          LoggerService.error("❌ Error sending SMS to ${contact.name}: $e");
          allSent = false;
        }
      }

      LoggerService.info(
        "📊 SMS sending complete. Success: $successCount/${enabledContacts.length}",
      );

      _smsSentController.add(allSent && successCount > 0);
      return allSent && successCount > 0;
    } catch (e) {
      LoggerService.error("❌ Error in emergency SMS process: $e");
      _smsSentController.add(false);
      return false;
    }
  }

  // Helper method for direct SMS sending via native channel
  Future<bool> _sendDirectSms(String phoneNumber, String message) async {
    try {
      LoggerService.info("Using native SMS channel for $phoneNumber");

      // Check if we're on Android (native SMS only works on Android)
      if (!Platform.isAndroid) {
        LoggerService.warning(
          "Native SMS only works on Android, not on ${Platform.operatingSystem}",
        );
        return false;
      }

      // Clean the phone number to ensure compatibility
      final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

      if (cleanPhone.isEmpty || cleanPhone.length < 10) {
        LoggerService.warning(
          "Invalid phone number after cleaning: $cleanPhone",
        );
        return false;
      }

      // Add retry logic for more reliability
      bool result = false;
      int maxRetries = 5; // Increased from 3 to 5
      int currentTry = 0;

      while (currentTry < maxRetries && result != true) {
        currentTry++;

        try {
          // Invoke the native method
          final methodResult = await _channel
              .invokeMethod<bool>('sendSMS', {
                'phoneNumber': cleanPhone,
                'message': message,
              })
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  return false;
                },
              );

          result = methodResult == true;

          if (result) {
            LoggerService.info(
              "Native SMS sent successfully on attempt $currentTry",
            );
            break;
          } else {
            LoggerService.warning(
              "Native SMS attempt $currentTry returned false",
            );
            // Small delay before retry with increasing duration
            await Future.delayed(Duration(milliseconds: 500 * currentTry));
          }
        } catch (e) {
          LoggerService.error("Error in native SMS attempt $currentTry: $e");
          // Small delay before retry with increasing duration
          await Future.delayed(Duration(milliseconds: 500 * currentTry));
        }
      }

      return result;
    } on PlatformException catch (e) {
      LoggerService.error(
        "Platform exception in native SMS sending: ${e.message}",
      );
      return false;
    } catch (e) {
      LoggerService.error("Error in direct SMS sending: $e");
      return false;
    }
  }

  // Helper method for SMS via URL launcher
  Future<bool> _sendSmsViaUrlLauncher(
    String phoneNumber,
    String message,
  ) async {
    try {
      LoggerService.info("Using URL launcher for SMS to $phoneNumber");

      // Clean phone number again just to be safe
      final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

      // Format the SMS URL - using different formats for different platforms
      Uri smsUri;

      // iOS uses a different URL format than Android
      if (Platform.isIOS) {
        // iOS format
        smsUri = Uri.parse(
          'sms:$cleanPhone&body=${Uri.encodeComponent(message)}',
        );
      } else {
        // Android format
        smsUri = Uri.parse(
          'sms:$cleanPhone?body=${Uri.encodeComponent(message)}',
        );
      }

      // Check if the URL can be launched
      if (await canLaunchUrl(smsUri)) {
        // Use LaunchMode.externalApplication to ensure it opens in the SMS app
        final result = await launchUrl(
          smsUri,
          mode: LaunchMode.externalApplication,
        );

        return result;
      } else {
        LoggerService.error("Cannot launch SMS URL for $phoneNumber");

        // Try an alternative format as last resort
        final altUri = Uri.parse('sms:$cleanPhone');
        if (await canLaunchUrl(altUri)) {
          return await launchUrl(altUri, mode: LaunchMode.externalApplication);
        }

        return false;
      }
    } catch (e) {
      LoggerService.error("Error sending SMS via URL launcher: $e");
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
      LoggerService.info("📱 Starting cancellation SMS process");

      // Only send cancellation if we previously had a successful send
      if (!_hasSuccessfulSend) {
        LoggerService.warning(
          "No prior successful SMS send, skipping cancellation",
        );
        return true;
      }

      // Validate contacts
      final enabledContacts = contacts.where((c) => c.isEnabled).toList();
      if (enabledContacts.isEmpty) {
        LoggerService.warning(
          "No enabled contacts to send cancellation SMS to",
        );
        return false;
      }

      // Check permissions for Android
      if (Platform.isAndroid) {
        final hasPermission = await checkPermissions();
        if (!hasPermission) {
          LoggerService.error(
            "SMS permissions not granted - cancellation cannot be sent",
          );
          return false;
        }
        LoggerService.info("✅ SMS permissions confirmed for cancellation");
      }

      final message = _buildCancellationMessage(alert);
      LoggerService.info(
        "📝 Cancellation message created, sending to ${enabledContacts.length} contacts",
      );

      bool allSent = true;
      int successCount = 0;

      // Process each contact
      for (final contact in enabledContacts) {
        try {
          final phoneNumber = contact.phoneNumber.trim();
          if (phoneNumber.isEmpty) {
            LoggerService.warning("Empty phone number for ${contact.name}");
            continue;
          }

          LoggerService.info(
            "📤 Sending cancellation SMS to ${contact.name} ($phoneNumber)",
          );

          // First attempt to send via native SMS for automatic background sending
          // If that fails, fall back to URL launcher
          bool success = false;

          if (Platform.isAndroid) {
            // On Android, use native method channel for automatic sending
            success = await _sendDirectSms(phoneNumber, message);

            if (success) {
              LoggerService.info(
                "Cancellation SMS sent automatically via native channel to ${contact.name}",
              );
            } else {
              success = await _sendSmsViaUrlLauncher(phoneNumber, message);
            }
          } else {
            // On iOS and other platforms, use URL launcher directly
            success = await _sendSmsViaUrlLauncher(phoneNumber, message);
          }

          if (success) {
            successCount++;
            LoggerService.info(
              "✅ Cancellation SMS sent successfully to ${contact.name}",
            );
          } else {
            LoggerService.warning(
              "⚠️ Cancellation SMS sending failed for ${contact.name}",
            );
            allSent = false;
          }
        } catch (e) {
          LoggerService.error(
            "❌ Error sending cancellation SMS to ${contact.name}: $e",
          );
          allSent = false;
        }
      }

      LoggerService.info(
        "📊 Cancellation SMS sending complete. Success: $successCount/${enabledContacts.length}",
      );
      return allSent && successCount > 0;
    } catch (e) {
      LoggerService.error("❌ Error in cancellation SMS process: $e");
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
