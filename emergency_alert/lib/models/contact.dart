class EmergencyContact {
  final String id;
  final String name;
  final String phoneNumber;
  final String? relationship;
  final bool isPrimary;
  final bool isEnabled;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.relationship,
    this.isPrimary = false,
    this.isEnabled = true,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'],
      name: json['name'],
      phoneNumber: json['phoneNumber'],
      relationship: json['relationship'],
      isPrimary: json['isPrimary'] ?? false,
      isEnabled: json['isEnabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'relationship': relationship,
      'isPrimary': isPrimary,
      'isEnabled': isEnabled,
    };
  }

  EmergencyContact copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? relationship,
    bool? isPrimary,
    bool? isEnabled,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      relationship: relationship ?? this.relationship,
      isPrimary: isPrimary ?? this.isPrimary,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  @override
  String toString() {
    return 'EmergencyContact(id: $id, name: $name, phoneNumber: $phoneNumber, relationship: $relationship, isPrimary: $isPrimary, isEnabled: $isEnabled)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EmergencyContact && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
