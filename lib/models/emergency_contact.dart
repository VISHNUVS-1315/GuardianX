class EmergencyContact {
  const EmergencyContact({required this.name, required this.phone});

  final String name;
  final String phone;

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: (json['name'] as String? ?? '').trim(),
      phone: (json['phone'] as String? ?? '').trim(),
    );
  }
}
