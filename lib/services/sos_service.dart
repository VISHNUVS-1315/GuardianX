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

  static String buildCrashMessage(
    Position position, {
    String? liveShareUrl,
  }) {
    final livePart = liveShareUrl == null || liveShareUrl.isEmpty
        ? ''
        : ' Live tracking: $liveShareUrl.';
    return 'GUARDIANX POSSIBLE CRASH ALERT: My phone detected a strong impact '
        'and I did not cancel the alert. My latest location: '
        '${LocationService.mapsUrl(position)}.$livePart '
        'Please contact me now. If I do not respond and there appears to be an '
        'emergency, contact emergency services.';
  }

  static String buildLiveShareMessage(String shareUrl) {
    return 'GUARDIANX LIVE SAFETY: Follow my live location here: $shareUrl. '
        'If I appear to be in danger, please contact me and emergency services.';
  }

  static Future<void> openSms(
    List<EmergencyContact> contacts,
    Position position,
  ) async {
    if (contacts.isEmpty) {
      throw Exception('Add at least one emergency contact first.');
    }

    final phones = contacts.map((item) => item.phone).join(',');
    final uri = Uri(
      scheme: 'sms',
      path: phones,
      queryParameters: {'body': buildMessage(position)},
    );
    await _launch(uri);
  }

  static Future<void> openCrashAlertSms(
    List<EmergencyContact> contacts,
    Position position, {
    String? liveShareUrl,
  }) async {
    if (contacts.isEmpty) {
      throw Exception('Add at least one emergency contact first.');
    }

    final phones = contacts.map((item) => item.phone).join(',');
    final uri = Uri(
      scheme: 'sms',
      path: phones,
      queryParameters: {
        'body': buildCrashMessage(position, liveShareUrl: liveShareUrl),
      },
    );
    await _launch(uri);
  }

  static Future<void> openLiveShareSms(
    List<EmergencyContact> contacts,
    String shareUrl,
  ) async {
    if (contacts.isEmpty) {
      throw Exception('Add at least one emergency contact first.');
    }
    final phones = contacts.map((item) => item.phone).join(',');
    final uri = Uri(
      scheme: 'sms',
      path: phones,
      queryParameters: {'body': buildLiveShareMessage(shareUrl)},
    );
    await _launch(uri);
  }

  static Future<void> openWhatsApp(Position position) async {
    final uri = Uri.https(
      'wa.me',
      '/',
      {'text': buildMessage(position)},
    );
    await _launch(uri, external: true);
  }

  static Future<void> openLiveShareWhatsApp(String shareUrl) async {
    final uri = Uri.https(
      'wa.me',
      '/',
      {'text': buildLiveShareMessage(shareUrl)},
    );
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
