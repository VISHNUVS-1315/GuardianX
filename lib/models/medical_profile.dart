class MedicalProfile {
  const MedicalProfile({
    this.fullName = '',
    this.bloodGroup = '',
    this.allergies = '',
    this.medications = '',
    this.conditions = '',
    this.emergencyNote = '',
  });

  final String fullName;
  final String bloodGroup;
  final String allergies;
  final String medications;
  final String conditions;
  final String emergencyNote;

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'bloodGroup': bloodGroup,
        'allergies': allergies,
        'medications': medications,
        'conditions': conditions,
        'emergencyNote': emergencyNote,
      };

  factory MedicalProfile.fromJson(Map<String, dynamic> json) {
    return MedicalProfile(
      fullName: json['fullName'] as String? ?? '',
      bloodGroup: json['bloodGroup'] as String? ?? '',
      allergies: json['allergies'] as String? ?? '',
      medications: json['medications'] as String? ?? '',
      conditions: json['conditions'] as String? ?? '',
      emergencyNote: json['emergencyNote'] as String? ?? '',
    );
  }

  String toEmergencyText() {
    return [
      'GuardianX Medical ID',
      if (fullName.trim().isNotEmpty) 'Name: ${fullName.trim()}',
      if (bloodGroup.trim().isNotEmpty) 'Blood group: ${bloodGroup.trim()}',
      if (allergies.trim().isNotEmpty) 'Allergies: ${allergies.trim()}',
      if (medications.trim().isNotEmpty)
        'Medications: ${medications.trim()}',
      if (conditions.trim().isNotEmpty) 'Conditions: ${conditions.trim()}',
      if (emergencyNote.trim().isNotEmpty)
        'Emergency note: ${emergencyNote.trim()}',
    ].join('\n');
  }
}
