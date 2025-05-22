// Service to handle device contacts integration
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/settings_model.dart';

class ContactsService {
  // Check contacts permission
  static Future<bool> checkPermission() async {
    final status = await Permission.contacts.status;
    if (status.isGranted) {
      return true;
    }

    // Request permission if not already granted
    final result = await Permission.contacts.request();
    return result.isGranted;
  }

  // Get contacts from device
  // In a real implementation, this would use a contacts plugin
  // like flutter_contacts to fetch actual device contacts
  static Future<List<EmergencyContact>> getContacts() async {
    if (!await checkPermission()) {
      debugPrint('Contacts permission not granted');
      return [];
    }

    // For demo purposes, we'll return some dummy contacts
    // In a real implementation, you would fetch actual device contacts here
    return [
      const EmergencyContact(name: 'John Doe', phoneNumber: '+1234567890'),
      const EmergencyContact(name: 'Jane Smith', phoneNumber: '+0987654321'),
      const EmergencyContact(name: 'Emergency Services', phoneNumber: '911'),
    ];
  }

  // Format phone number to ensure consistency
  static String formatPhoneNumber(String phone) {
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
  static bool isValidPhoneNumber(String phone) {
    // Simple validation - more advanced would be needed for a real app
    final cleaned = formatPhoneNumber(phone);

    // Check if it's a valid emergency number or has enough digits
    if (cleaned == '911' || cleaned == '112' || cleaned == '999') {
      return true;
    }

    // Check for regular phone numbers
    return cleaned.length >= 10;
  }
}
