import 'package:flutter_test/flutter_test.dart';
import 'package:guardianx_app/models/emergency_contact.dart';
import 'package:guardianx_app/models/medical_profile.dart';

void main() {
  test('EmergencyContact round-trips through json', () {
    const contact = EmergencyContact(name: 'Guardian', phone: '+911234567890');
    final decoded = EmergencyContact.fromJson(contact.toJson());
    expect(decoded.name, contact.name);
    expect(decoded.phone, contact.phone);
  });

  test('MedicalProfile emergency text only includes useful fields', () {
    const profile = MedicalProfile(
      fullName: 'Test User',
      bloodGroup: 'O+',
      allergies: 'None',
    );

    final text = profile.toEmergencyText();
    expect(text, contains('Test User'));
    expect(text, contains('O+'));
    expect(text, contains('None'));
    expect(text, isNot(contains('Medications:')));
  });
}
