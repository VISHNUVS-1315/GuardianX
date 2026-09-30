import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/emergency_contact.dart';
import '../models/medical_profile.dart';

class LocalStore {
  LocalStore._();

  static const _contactsKey = 'guardianx_emergency_contacts';
  static const _medicalKey = 'guardianx_medical_profile';
  static const _crashDetectionKey = 'guardianx_crash_detection_enabled';
  static const _secure = FlutterSecureStorage();

  static Future<List<EmergencyContact>> loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_contactsKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .whereType<Map>()
        .map((item) => EmergencyContact.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ))
        .where((contact) => contact.phone.isNotEmpty)
        .toList();
  }

  static Future<void> saveContacts(List<EmergencyContact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _contactsKey,
      jsonEncode(contacts.map((item) => item.toJson()).toList()),
    );
  }

  static Future<bool> loadCrashDetectionEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_crashDetectionKey) ?? false;
  }

  static Future<void> saveCrashDetectionEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_crashDetectionKey, enabled);
  }

  static Future<MedicalProfile> loadMedicalProfile() async {
    final raw = await _secure.read(key: _medicalKey);
    if (raw == null || raw.isEmpty) return const MedicalProfile();

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return MedicalProfile.fromJson(decoded);
  }

  static Future<void> saveMedicalProfile(MedicalProfile profile) async {
    await _secure.write(key: _medicalKey, value: jsonEncode(profile.toJson()));
  }
}
