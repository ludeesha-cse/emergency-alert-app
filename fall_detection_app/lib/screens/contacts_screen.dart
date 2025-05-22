// Screen for managing emergency contacts
import 'package:flutter/material.dart';
import '../models/settings_model.dart';
import '../services/settings_service.dart';
import '../services/contacts_service.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  // List of emergency contacts
  List<EmergencyContact> _contacts = [];

  // Loading state
  bool _isLoading = true;

  // Controllers for adding new contacts
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // Load saved emergency contacts
  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
    });

    final settings = await SettingsService.getSettings();

    setState(() {
      _contacts = settings.emergencyContacts;
      _isLoading = false;
    });
  }

  // Save contacts to settings
  Future<void> _saveContacts() async {
    final settings = await SettingsService.getSettings();
    final updatedSettings = settings.copyWith(emergencyContacts: _contacts);

    await SettingsService.saveSettings(updatedSettings);
  }

  // Add a new emergency contact
  Future<void> _addContact(EmergencyContact contact) async {
    setState(() {
      _contacts.add(contact);
    });

    await _saveContacts();
  }

  // Remove an emergency contact
  Future<void> _removeContact(int index) async {
    setState(() {
      _contacts.removeAt(index);
    });

    await _saveContacts();
  }

  // Show dialog to add a new contact
  void _showAddContactDialog() {
    // Clear previous values
    _nameController.clear();
    _phoneController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Emergency Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Enter contact name',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: 'Enter phone number',
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              // Validate input
              final name = _nameController.text.trim();
              final phone = _phoneController.text.trim();

              if (name.isEmpty || phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields')),
                );
                return;
              }

              if (!ContactsService.isValidPhoneNumber(phone)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid phone number')),
                );
                return;
              }

              // Format phone number
              final formattedPhone = ContactsService.formatPhoneNumber(phone);

              // Add contact
              _addContact(
                EmergencyContact(name: name, phoneNumber: formattedPhone),
              );

              Navigator.of(context).pop();
            },
            child: const Text('ADD'),
          ),
        ],
      ),
    );
  }

  // Show dialog to import from device contacts
  Future<void> _importFromContacts() async {
    // Check contacts permission
    final hasPermission = await ContactsService.checkPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contacts permission not granted')),
        );
      }
      return;
    }

    // Get contacts from device
    final contacts = await ContactsService.getContacts();

    // Show contact picker
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Contacts'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: contacts.length,
              itemBuilder: (context, index) {
                final contact = contacts[index];
                return ListTile(
                  title: Text(contact.name),
                  subtitle: Text(contact.phoneNumber),
                  onTap: () {
                    // Check if already added
                    final exists = _contacts.any(
                      (c) => c.phoneNumber == contact.phoneNumber,
                    );

                    if (!exists) {
                      _addContact(contact);
                    }

                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCEL'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Info card
                Card(
                  margin: const EdgeInsets.all(16),
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Add emergency contacts who will be notified '
                      'when a fall is detected. An SMS message with '
                      'your location will be sent to these contacts.',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),

                // Contact list
                Expanded(
                  child: _contacts.isEmpty
                      ? const Center(
                          child: Text(
                            'No emergency contacts added yet',
                            style: TextStyle(fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _contacts.length,
                          itemBuilder: (context, index) {
                            final contact = _contacts[index];
                            return ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.person),
                              ),
                              title: Text(contact.name),
                              subtitle: Text(contact.phoneNumber),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _removeContact(index),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Contact'),
                  onPressed: _showAddContactDialog,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.import_contacts),
                  label: const Text('Import'),
                  onPressed: _importFromContacts,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
