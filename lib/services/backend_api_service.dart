import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class BackendApiService {
  BackendApiService._();

  static const _configuredBaseUrl = String.fromEnvironment(
    'GUARDIANX_API_URL',
    defaultValue: 'https://guardianx-api-391z.onrender.com',
  );

  static String get baseUrl {
    final value = _configuredBaseUrl.trim();
    if (value.endsWith('/')) return value.substring(0, value.length - 1);
    return value;
  }

  static Future<String?> reportIncident({
    required String type,
    required Position position,
    String? shareUrl,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/incidents'),
            headers: const {
              'Content-Type': 'application/json',
              'X-GuardianX-Client': 'flutter',
            },
            body: jsonEncode({
              'type': type,
              'location': {
                'latitude': position.latitude,
                'longitude': position.longitude,
                'accuracy': position.accuracy,
                'deviceTime': position.timestamp.toIso8601String(),
              },
              if (shareUrl != null && shareUrl.isNotEmpty) 'shareUrl': shareUrl,
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode < 200 || response.statusCode >= 300) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      final incidentId = decoded['incidentId'];
      return incidentId is String && incidentId.isNotEmpty ? incidentId : null;
    } catch (_) {
      // Safety actions must keep working even if the cloud API is unavailable.
      return null;
    }
  }
}
