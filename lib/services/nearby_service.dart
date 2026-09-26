import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class NearbyPlace {
  const NearbyPlace({
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
  });

  final String name;
  final String type;
  final double latitude;
  final double longitude;
  final double distanceMeters;

  String get distanceLabel {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }
}

class NearbyService {
  NearbyService._();

  static const _endpoint = 'https://overpass-api.de/api/interpreter';

  static Future<List<NearbyPlace>> fetch(
    Position origin, {
    double radiusMeters = 5000,
  }) async {
    final query = '''
[out:json][timeout:18];
(
  nwr["amenity"~"hospital|police|pharmacy|fuel"](around:${radiusMeters.round()},${origin.latitude},${origin.longitude});
);
out center tags;
''';

    final response = await http
        .post(
          Uri.parse(_endpoint),
          headers: const {
            'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
            'User-Agent': 'GuardianX/1.0 personal-safety-app',
          },
          body: {'data': query},
        )
        .timeout(const Duration(seconds: 22));

    if (response.statusCode != 200) {
      throw Exception('Nearby service returned ${response.statusCode}.');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final elements = (payload['elements'] as List<dynamic>? ?? []);

    final places = <NearbyPlace>[];
    for (final raw in elements) {
      if (raw is! Map<String, dynamic>) continue;
      final tags = raw['tags'] as Map<String, dynamic>? ?? const {};
      final center = raw['center'] as Map<String, dynamic>?;

      final lat = (raw['lat'] as num?)?.toDouble() ??
          (center?['lat'] as num?)?.toDouble();
      final lon = (raw['lon'] as num?)?.toDouble() ??
          (center?['lon'] as num?)?.toDouble();
      if (lat == null || lon == null) continue;

      final type = (tags['amenity'] as String? ?? 'service').trim();
      final name = (tags['name'] as String? ?? _fallbackName(type)).trim();
      final distance = Geolocator.distanceBetween(
        origin.latitude,
        origin.longitude,
        lat,
        lon,
      );

      places.add(
        NearbyPlace(
          name: name.isEmpty ? _fallbackName(type) : name,
          type: type,
          latitude: lat,
          longitude: lon,
          distanceMeters: distance,
        ),
      );
    }

    places.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return places.take(40).toList();
  }

  static String _fallbackName(String type) {
    switch (type) {
      case 'hospital':
        return 'Hospital';
      case 'police':
        return 'Police station';
      case 'pharmacy':
        return 'Pharmacy';
      case 'fuel':
        return 'Fuel station';
      default:
        return 'Essential service';
    }
  }
}
