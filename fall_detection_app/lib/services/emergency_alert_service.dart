// Emergency Alert Service for SMS notifications during fall detection emergencies
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/settings_model.dart';
import 'location_service.dart';
import 'settings_service.dart';
import 'sms_service.dart';

/// A service class for managing emergency alert communications.
/// Handles sending SMS alerts with location information when falls are detected.
class EmergencyAlertService {
  // Singleton pattern
  static final EmergencyAlertService _instance =
      EmergencyAlertService._internal();
  factory EmergencyAlertService() => _instance;
  EmergencyAlertService._internal();

  // Keys for preferences
  static const String _contactsKey = 'emergency_contacts';
  static const int _maxContacts = 5;

  // Cached location service
  LocationService? _locationService;

  /// Initialize the emergency alert service with necessary dependencies
  Future<void> initialize() async {
    try {
      debugPrint('Initializing EmergencyAlertService');
      _locationService = await LocationService.initialize();

      // Verify settings can be accessed
      final settings = await SettingsService.getSettings();
      debugPrint(
        'Settings loaded, contacts count: ${settings.emergencyContacts.length}',
      );
    } catch (e) {
      debugPrint('Error initializing EmergencyAlertService: $e');
    }
  }

  /// Send emergency alerts to all configured contacts
  /// Returns true if at least one alert was sent successfully
  Future<bool> sendEmergencyAlerts({String? customMessage}) async {
    try {
      // Get the stored emergency contacts
      final settings = await SettingsService.getSettings();
      final contacts = settings.emergencyContacts;

      // Check if any contacts are configured
      if (contacts.isEmpty) {
        debugPrint('No emergency contacts configured');
        return false;
      }

      // Ensure we have SMS permission
      final hasPermission = await _checkSmsPermission();
      if (!hasPermission) {
        debugPrint('SMS permission not granted');
        return false;
      }

      // Get the current/last location
      Position? position;

      // Try to get current location first
      if (_locationService != null) {
        position = await _locationService!.getCurrentLocation();

        // Fall back to last known location if current location isn't available
        if (position == null) {
          position = _locationService!.getStoredLocation();
        }
      }

      // Get emergency message from settings or use custom message
      final message = customMessage ?? settings.emergencyMessage;

      // Extract phone numbers from contacts
      final phoneNumbers = contacts
          .map((contact) => contact.phoneNumber)
          .toList();

      // Send SMS with location data
      return await SmsService.sendSms(
        recipients: phoneNumbers,
        message: message,
        position: position,
      );
    } catch (e) {
      debugPrint('Error sending emergency alerts: $e');
      return false;
    }
  }

  /// Check for SMS permission and request if not granted
  Future<bool> _checkSmsPermission() async {
    final status = await Permission.sms.status;

    if (status.isGranted) {
      return true;
    }

    // Request permission
    final result = await Permission.sms.request();

    // If still not granted, show fallback options
    if (!result.isGranted) {
      _showFallbackOptions();
      return false;
    }

    return true;
  }

  /// Adds a new emergency contact if space is available
  /// Returns true if the contact was added successfully
  Future<bool> addEmergencyContact({
    required String name,
    required String phoneNumber,
  }) async {
    debugPrint('Adding contact - Name: $name, Phone: $phoneNumber');

    // Get current settings
    final settings = await SettingsService.getSettings();
    final contacts = List<EmergencyContact>.from(settings.emergencyContacts);
    debugPrint('Current contacts count: ${contacts.length}');

    // Check if limit reached
    if (contacts.length >= _maxContacts) {
      debugPrint('Maximum number of emergency contacts reached');
      return false;
    }

    // Format and validate the phone number
    final formattedPhone = _formatPhoneNumber(phoneNumber);
    debugPrint('Formatted phone number: $formattedPhone');

    if (!_isValidPhoneNumber(formattedPhone)) {
      debugPrint('Invalid phone number format');
      return false;
    }

    // Check if contact already exists
    if (contacts.any((contact) => contact.phoneNumber == formattedPhone)) {
      debugPrint('Contact already exists');
      return true; // Return true since it's already saved
    }

    // Add the new contact
    contacts.add(EmergencyContact(name: name, phoneNumber: formattedPhone));
    debugPrint('New contact added, new count: ${contacts.length}');

    // Save updated settings
    final success = await SettingsService.saveSettings(
      settings.copyWith(emergencyContacts: contacts),
    );

    debugPrint('Save settings result: $success');
    return success;
  }

  /// Removes an emergency contact by phone number
  Future<bool> removeEmergencyContact(String phoneNumber) async {
    return await SettingsService.removeEmergencyContact(phoneNumber);
  }

  /// Updates an existing emergency contact
  Future<bool> updateEmergencyContact({
    required String oldPhoneNumber,
    required String name,
    required String newPhoneNumber,
  }) async {
    // Get current settings
    final settings = await SettingsService.getSettings();
    final contacts = List<EmergencyContact>.from(settings.emergencyContacts);

    // Find the index of the contact to update
    final index = contacts.indexWhere(
      (contact) => contact.phoneNumber == oldPhoneNumber,
    );

    if (index == -1) {
      debugPrint('Contact not found');
      return false;
    }

    // Format and validate the new phone number
    final formattedPhone = _formatPhoneNumber(newPhoneNumber);
    if (!_isValidPhoneNumber(formattedPhone)) {
      debugPrint('Invalid phone number format');
      return false;
    }

    // Replace the contact
    contacts[index] = EmergencyContact(name: name, phoneNumber: formattedPhone);

    // Save updated settings
    return await SettingsService.saveSettings(
      settings.copyWith(emergencyContacts: contacts),
    );
  }

  /// Get all configured emergency contacts
  Future<List<EmergencyContact>> getEmergencyContacts() async {
    final settings = await SettingsService.getSettings();

    // Clean up any potentially corrupt contacts (with empty phone numbers)
    List<EmergencyContact> validContacts = settings.emergencyContacts
        .where(
          (contact) =>
              contact.phoneNumber.isNotEmpty && contact.name.isNotEmpty,
        )
        .toList();

    // If we found and removed invalid contacts, save the cleaned list
    if (validContacts.length != settings.emergencyContacts.length) {
      debugPrint(
        'Removed ${settings.emergencyContacts.length - validContacts.length} invalid contacts',
      );
      await SettingsService.saveSettings(
        settings.copyWith(emergencyContacts: validContacts),
      );
    }

    debugPrint('Fetched contacts: ${validContacts.length}');

    // Print each contact for debugging
    validContacts.forEach((contact) {
      debugPrint('Contact: ${contact.name}, ${contact.phoneNumber}');
    });

    return validContacts;
  }

  // Format phone number to ensure consistency
  String _formatPhoneNumber(String phone) {
    // Remove all non-numeric characters
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');

    // Ensure it starts with + for international format if it doesn't begin with a local emergency number
    if (!cleaned.startsWith('+') &&
        !cleaned.startsWith('911') &&
        !cleaned.startsWith('112') &&
        !cleaned.startsWith('999')) {
      if (cleaned.startsWith('1')) {
        // US numbers
        cleaned = '+$cleaned';
      }
    }

    return cleaned;
  }

  // Validate phone number
  bool _isValidPhoneNumber(String phone) {
    // Simple validation - more advanced would be needed for a real app
    final cleaned = _formatPhoneNumber(phone);

    // Check if it's a valid emergency number or has enough digits
    if (cleaned == '911' || cleaned == '112' || cleaned == '999') {
      return true;
    }

    // Check for regular phone numbers
    return cleaned.length >= 10;
  }

  /// Update the emergency message template
  Future<bool> updateEmergencyMessage(String message) async {
    return await SettingsService.updateEmergencyMessage(message);
  }

  /// Retrieve the current emergency message
  Future<String> getEmergencyMessage() async {
    final settings = await SettingsService.getSettings();
    return settings.emergencyMessage;
  }

  /// Handle fallback options when SMS permission is denied
  void _showFallbackOptions() {
    // This would typically prompt a UI dialog with options
    // For now, we'll just log the information
    debugPrint('SMS permission denied. Fallback options include:');
    debugPrint('1. Enable permission in device settings');
    debugPrint('2. Use alternative communication methods');
    debugPrint('3. Configure fewer but high-priority contacts');
  }

  /// Check if we can send emergency alerts based on current permissions
  Future<bool> canSendAlerts() async {
    // Check if SMS permission is granted
    final smsPermissionGranted = await Permission.sms.isGranted;

    // Check if we have any contacts configured
    final settings = await SettingsService.getSettings();
    final hasContacts = settings.emergencyContacts.isNotEmpty;

    return smsPermissionGranted && hasContacts;
  }
}
