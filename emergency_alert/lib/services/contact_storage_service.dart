import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/contact.dart';
import '../utils/constants.dart';

class ContactStorageService {
  static final ContactStorageService _instance = ContactStorageService._internal();
  factory ContactStorageService() => _instance;
  ContactStorageService._internal();

  /// Load all emergency contacts from storage
  Future<List<EmergencyContact>> loadContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contactsJson = prefs.getStringList(AppConstants.keyEmergencyContacts) ?? [];
      
      return contactsJson
          .map((json) => EmergencyContact.fromJson(jsonDecode(json)))
          .toList();
    } catch (e) {
      print('Error loading contacts: $e');
      return [];
    }
  }

  /// Save all emergency contacts to storage
  Future<bool> saveContacts(List<EmergencyContact> contacts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contactsJson = contacts
          .map((contact) => jsonEncode(contact.toJson()))
          .toList();
      
      await prefs.setStringList(AppConstants.keyEmergencyContacts, contactsJson);
      return true;
    } catch (e) {
      print('Error saving contacts: $e');
      return false;
    }
  }

  /// Add a new contact
  Future<bool> addContact(EmergencyContact contact) async {
    try {
      final contacts = await loadContacts();
      
      // Check if we're at the limit
      if (contacts.length >= AppConstants.maxEmergencyContacts) {
        print('Maximum number of emergency contacts reached');
        return false;
      }

      // Check for duplicate phone numbers
      if (contacts.any((c) => c.phoneNumber == contact.phoneNumber)) {
        print('Contact with this phone number already exists');
        return false;
      }

      contacts.add(contact);
      return await saveContacts(contacts);
    } catch (e) {
      print('Error adding contact: $e');
      return false;
    }
  }

  /// Update an existing contact
  Future<bool> updateContact(EmergencyContact updatedContact) async {
    try {
      final contacts = await loadContacts();
      final index = contacts.indexWhere((c) => c.id == updatedContact.id);
      
      if (index == -1) {
        print('Contact not found for update');
        return false;
      }

      // Check for duplicate phone numbers (excluding the current contact)
      if (contacts.any((c) => c.id != updatedContact.id && c.phoneNumber == updatedContact.phoneNumber)) {
        print('Another contact with this phone number already exists');
        return false;
      }

      contacts[index] = updatedContact;
      return await saveContacts(contacts);
    } catch (e) {
      print('Error updating contact: $e');
      return false;
    }
  }

  /// Remove a contact
  Future<bool> removeContact(String contactId) async {
    try {
      final contacts = await loadContacts();
      contacts.removeWhere((c) => c.id == contactId);
      return await saveContacts(contacts);
    } catch (e) {
      print('Error removing contact: $e');
      return false;
    }
  }

  /// Toggle contact enabled status
  Future<bool> toggleContactEnabled(String contactId, bool enabled) async {
    try {
      final contacts = await loadContacts();
      final index = contacts.indexWhere((c) => c.id == contactId);
      
      if (index == -1) {
        return false;
      }

      contacts[index] = contacts[index].copyWith(isEnabled: enabled);
      return await saveContacts(contacts);
    } catch (e) {
      print('Error toggling contact status: $e');
      return false;
    }
  }

  /// Get enabled contacts only
  Future<List<EmergencyContact>> getEnabledContacts() async {
    final contacts = await loadContacts();
    return contacts.where((c) => c.isEnabled).toList();
  }

  /// Get primary contacts only
  Future<List<EmergencyContact>> getPrimaryContacts() async {
    final contacts = await loadContacts();
    return contacts.where((c) => c.isPrimary && c.isEnabled).toList();
  }

  /// Validate contact data
  bool validateContact(EmergencyContact contact) {
    if (contact.name.trim().isEmpty) return false;
    if (contact.phoneNumber.trim().isEmpty) return false;
    
    // Basic phone number validation
    final cleanNumber = contact.phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanNumber.length < 10) return false;
    
    return true;
  }

  /// Export contacts to JSON for backup
  Future<String?> exportContacts() async {
    try {
      final contacts = await loadContacts();
      final exportData = {
        'version': '1.0',
        'timestamp': DateTime.now().toIso8601String(),
        'contacts': contacts.map((c) => c.toJson()).toList(),
      };
      
      return jsonEncode(exportData);
    } catch (e) {
      print('Error exporting contacts: $e');
      return null;
    }
  }

  /// Import contacts from JSON backup
  Future<bool> importContacts(String jsonData) async {
    try {
      final data = jsonDecode(jsonData) as Map<String, dynamic>;
      
      if (!data.containsKey('contacts')) {
        print('Invalid import data format');
        return false;
      }

      final importedContacts = (data['contacts'] as List)
          .map((json) => EmergencyContact.fromJson(json))
          .toList();

      // Validate all contacts before importing
      for (final contact in importedContacts) {
        if (!validateContact(contact)) {
          print('Invalid contact data found in import');
          return false;
        }
      }

      return await saveContacts(importedContacts);
    } catch (e) {
      print('Error importing contacts: $e');
      return false;
    }
  }
}
