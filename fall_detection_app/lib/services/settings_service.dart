// Settings service to save and load user preferences
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings_model.dart';

class SettingsService {
  // Key for shared preferences
  static const String _settingsKey = 'fall_detection_settings';

  // Cached settings
  static AppSettings? _cachedSettings;

  // Get settings from cache or load from storage
  static Future<AppSettings> getSettings() async {
    if (_cachedSettings != null) {
      return _cachedSettings!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_settingsKey);

      if (settingsJson != null) {
        final Map<String, dynamic> jsonMap = json.decode(settingsJson);
        _cachedSettings = AppSettings.fromJson(jsonMap);
        return _cachedSettings!;
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }

    // Return default settings if loading fails
    _cachedSettings = AppSettings();
    return _cachedSettings!;
  }

  // Save settings to storage
  static Future<bool> saveSettings(AppSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = json.encode(settings.toJson());

      // Update cache
      _cachedSettings = settings;

      // Save to storage
      return await prefs.setString(_settingsKey, settingsJson);
    } catch (e) {
      debugPrint('Error saving settings: $e');
      return false;
    }
  }

  // Add an emergency contact
  static Future<bool> addEmergencyContact(EmergencyContact contact) async {
    final settings = await getSettings();
    final contacts = List<EmergencyContact>.from(settings.emergencyContacts);

    // Check if contact already exists
    final exists = contacts.any((c) => c.phoneNumber == contact.phoneNumber);
    if (!exists) {
      contacts.add(contact);
      return saveSettings(settings.copyWith(emergencyContacts: contacts));
    }
    return true;
  }

  // Remove an emergency contact
  static Future<bool> removeEmergencyContact(String phoneNumber) async {
    final settings = await getSettings();
    final contacts = List<EmergencyContact>.from(settings.emergencyContacts);
    contacts.removeWhere((contact) => contact.phoneNumber == phoneNumber);
    return saveSettings(settings.copyWith(emergencyContacts: contacts));
  }

  // Update fall detection sensitivity
  static Future<bool> updateSensitivity(double sensitivity) async {
    final settings = await getSettings();
    return saveSettings(
      settings.copyWith(fallDetectionSensitivity: sensitivity),
    );
  }

  // Update emergency message
  static Future<bool> updateEmergencyMessage(String message) async {
    final settings = await getSettings();
    return saveSettings(settings.copyWith(emergencyMessage: message));
  }
}
