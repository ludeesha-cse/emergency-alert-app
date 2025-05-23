import 'package:flutter/material.dart';
import '../models/settings_model.dart';
import '../services/emergency_alert_service.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({Key? key}) : super(key: key);

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final _emergencyService = EmergencyAlertService();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();

  List<EmergencyContact> _contacts = [];
  bool _isLoading = true;
  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  // Initialize the emergency service
  Future<void> _initializeService() async {
    try {
      await _emergencyService.initialize();
      debugPrint('Emergency service initialized in screen');
      await _loadContacts();
      await _loadEmergencyMessage();
    } catch (e) {
      debugPrint('Error initializing emergency service: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // Load emergency contacts
  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final contacts = await _emergencyService.getEmergencyContacts();

      setState(() {
        _contacts = contacts;
        _isLoading = false;
      });
    } catch (e) {
      _showErrorSnackBar('Error loading contacts: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Load emergency message
  Future<void> _loadEmergencyMessage() async {
    try {
      final settings = await _emergencyService.getEmergencyMessage();
      setState(() {
        _messageController.text = settings;
      });
    } catch (e) {
      _showErrorSnackBar('Error loading message: $e');
    }
  }

  // Save emergency message
  Future<void> _saveEmergencyMessage() async {
    try {
      final result = await _emergencyService.updateEmergencyMessage(
        _messageController.text.trim(),
      );

      if (result) {
        _showSuccessSnackBar('Emergency message updated');
      } else {
        _showErrorSnackBar('Failed to update message');
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    }
  }

  // Add a new contact
  Future<void> _addContact() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      _showErrorSnackBar('Name and phone number are required');
      return;
    }

    try {
      final success = await _emergencyService.addEmergencyContact(
        name: name,
        phoneNumber: phone,
      );

      if (success) {
        _showSuccessSnackBar('Contact added successfully');
        _nameController.clear();
        _phoneController.clear();
        await _loadContacts();
      } else {
        _showErrorSnackBar(
          'Failed to add contact. Maximum 5 contacts allowed.',
        );
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    }
  }

  // Remove a contact
  Future<void> _removeContact(String phoneNumber) async {
    try {
      final success = await _emergencyService.removeEmergencyContact(
        phoneNumber,
      );

      if (success) {
        _showSuccessSnackBar('Contact removed');
        await _loadContacts();
      } else {
        _showErrorSnackBar('Failed to remove contact');
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    }
  }

  // Test sending emergency alerts
  Future<void> _testEmergencyAlert() async {
    try {
      final success = await _emergencyService.sendEmergencyAlerts(
        customMessage: "THIS IS A TEST: " + _messageController.text,
      );

      if (success) {
        _showSuccessSnackBar('Test alert sent successfully');
      } else {
        _showErrorSnackBar('Failed to send test alert');
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    }
  }

  // Show success message
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  // Show error message
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Contacts')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Emergency message section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Emergency Message',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _messageController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: 'Enter your emergency message',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ElevatedButton(
                                onPressed: _saveEmergencyMessage,
                                child: const Text('Save Message'),
                              ),
                              ElevatedButton(
                                onPressed: _testEmergencyAlert,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                ),
                                child: const Text('Test Alert'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Contacts list
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Emergency Contacts (Max 5)',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),

                          if (_contacts.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                'No emergency contacts added yet.',
                                style: TextStyle(fontStyle: FontStyle.italic),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _contacts.length,
                              itemBuilder: (context, index) {
                                final contact = _contacts[index];
                                return ListTile(
                                  title: Text(contact.name),
                                  subtitle: Text(contact.phoneNumber),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () =>
                                        _removeContact(contact.phoneNumber),
                                  ),
                                );
                              },
                            ),

                          const Divider(),
                          const SizedBox(height: 8),

                          // Add new contact form
                          if (_contacts.length < 5) ...[
                            TextField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Name',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Phone Number',
                                border: OutlineInputBorder(),
                                hintText: '+1234567890',
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _addContact,
                              child: const Text('Add Contact'),
                            ),
                          ] else
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'Maximum number of contacts (5) reached.',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
