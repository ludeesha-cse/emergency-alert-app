import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/contact.dart';

class AddContactScreen extends StatefulWidget {
  final EmergencyContact? contact;

  const AddContactScreen({super.key, this.contact});

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _relationshipController = TextEditingController();

  bool _isPrimary = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.contact != null;

    if (_isEditing) {
      _nameController.text = widget.contact!.name;
      _phoneController.text = widget.contact!.phoneNumber;
      _relationshipController.text = widget.contact!.relationship ?? '';
      _isPrimary = widget.contact!.isPrimary;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Contact' : 'Add Contact'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          TextButton(onPressed: _saveContact, child: const Text('Save')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contact Information',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),

                      // Name field
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name *',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a name';
                          }
                          return null;
                        },
                        textCapitalization: TextCapitalization.words,
                      ),

                      const SizedBox(height: 16),

                      // Phone field
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number *',
                          prefixIcon: Icon(Icons.phone),
                          border: OutlineInputBorder(),
                          hintText: '+1 (555) 123-4567',
                        ),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[\d\s\-\(\)\+]'),
                          ),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a phone number';
                          }
                          // Basic phone number validation
                          final cleanNumber = value.replaceAll(
                            RegExp(r'[\s\-\(\)]'),
                            '',
                          );
                          if (cleanNumber.length < 10) {
                            return 'Please enter a valid phone number';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Relationship field
                      TextFormField(
                        controller: _relationshipController,
                        decoration: const InputDecoration(
                          labelText: 'Relationship (Optional)',
                          prefixIcon: Icon(Icons.family_restroom),
                          border: OutlineInputBorder(),
                          hintText: 'e.g., Spouse, Parent, Friend',
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),

                      const SizedBox(height: 16),

                      // Primary contact toggle
                      SwitchListTile(
                        title: const Text('Primary Contact'),
                        subtitle: const Text(
                          'Primary contacts are notified first in emergencies',
                        ),
                        value: _isPrimary,
                        onChanged: (value) {
                          setState(() {
                            _isPrimary = value;
                          });
                        },
                        secondary: const Icon(Icons.star),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Info card
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade700,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Emergency Contact Tips',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Add 3-5 trusted contacts\n'
                        '• Include at least one local contact\n'
                        '• Verify phone numbers are correct\n'
                        '• Inform contacts they\'re listed for emergencies',
                        style: TextStyle(color: Colors.blue.shade700),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Save button
              ElevatedButton.icon(
                onPressed: _saveContact,
                icon: const Icon(Icons.save),
                label: Text(_isEditing ? 'Update Contact' : 'Add Contact'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),

              if (_isEditing) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _deleteContact,
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete Contact'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _saveContact() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final contact = EmergencyContact(
      id: _isEditing
          ? widget.contact!.id
          : DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      relationship: _relationshipController.text.trim().isEmpty
          ? null
          : _relationshipController.text.trim(),
      isPrimary: _isPrimary,
    );

    Navigator.of(context).pop(contact);
  }

  void _deleteContact() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text(
          'Are you sure you want to delete ${_nameController.text}? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop('delete'); // Return to previous screen
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
