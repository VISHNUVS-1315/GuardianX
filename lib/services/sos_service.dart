import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/emergency_contact.dart';
import 'location_service.dart';

class SosService {
  SosService._();

  static String buildMessage(Position position) {
    return 'GUARDIANX SOS: I may need help. My current location: '
        '${LocationService.mapsUrl(position)}. '
        'Please contact me and emergency services if required.';
  }

  static Future<void> openSms(
    List<EmergencyContact> contacts,
    Position position,
  ) async {
    if (contacts.isEmpty) {
      throw Exception('Add at least one emergency contact first.');
    }

    final phones = contacts.map((item) => item.phone).join(',');
    final message = buildMessage(position);
    final uri = Uri(
      scheme: 'sms',
      path: phones,
      queryParameters: {'body': message},
    );
    await _launch(uri);
  }

  static Future<void> openWhatsApp(Position position) async {
    final message = buildMessage(position);
    final uri = Uri.https('wa.me', '/', {'text': message});
    await _launch(uri, external: true);
  }

  static Future<void> callEmergency() async {
    await _launch(Uri(scheme: 'tel', path: '112'));
  }

  static Future<void> openNavigation(double latitude, double longitude) async {
    final uri = Uri.https(
      'www.google.com',
      '/maps/dir/',
      {'api': '1', 'destination': '$latitude,$longitude'},
    );
    await _launch(uri, external: true);
  }

  static Future<void> _launch(Uri uri, {bool external = false}) async {
    final ok = await launchUrl(
      uri,
      mode: external
          ? LaunchMode.externalApplication
          : LaunchMode.platformDefault,
    );
    if (!ok) throw Exception('Could not open ${uri.scheme}.');
  }
}
