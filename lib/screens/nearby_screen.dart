import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/location_service.dart';
import '../services/nearby_service.dart';
import '../services/sos_service.dart';

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen>
    with AutomaticKeepAliveClientMixin {
  Position? _position;
  List<NearbyPlace> _places = const [];
  bool _loading = false;
  String? _error;
  String _filter = 'all';

  @override
  bool get wantKeepAlive => true;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final position = await LocationService.current();
      final places = await NearbyService.fetch(position);
      if (!mounted) return;
      setState(() {
        _position = position;
        _places = places;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<NearbyPlace> get _visible {
    if (_filter == 'all') return _places;
    return _places.where((place) => place.type == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
        children: [
          const Text(
            'Nearby essentials',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Real places around your current GPS location.',
            style: TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _loading ? null : _load,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Icon(Icons.radar),
            label: Text(_places.isEmpty ? 'Find nearby services' : 'Refresh'),
          ),
          if (_position != null) ...[
            const SizedBox(height: 10),
            Text(
              'Searching within 5 km of '
              '${_position!.latitude.toStringAsFixed(4)}, '
              '${_position!.longitude.toStringAsFixed(4)}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in const {
                'all': 'All',
                'hospital': 'Hospitals',
                'police': 'Police',
                'pharmacy': 'Pharmacy',
                'fuel': 'Fuel',
              }.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _filter == entry.key,
                  onSelected: (_) => setState(() => _filter = entry.key),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.white)),
          ],
          const SizedBox(height: 18),
          if (!_loading && _places.isEmpty && _error == null)
            const _EmptyNearby(),
          for (final place in _visible) ...[
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  child: Icon(_iconFor(place.type)),
                ),
                title: Text(
                  place.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${_labelFor(place.type)} • ${place.distanceLabel}',
                ),
                trailing: IconButton(
                  tooltip: 'Navigate',
                  onPressed: () => SosService.openNavigation(
                    place.latitude,
                    place.longitude,
                  ),
                  icon: const Icon(Icons.directions),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  static IconData _iconFor(String type) {
    switch (type) {
      case 'hospital':
        return Icons.local_hospital;
      case 'police':
        return Icons.local_police;
      case 'pharmacy':
        return Icons.medication;
      case 'fuel':
        return Icons.local_gas_station;
      default:
        return Icons.place;
    }
  }

  static String _labelFor(String type) {
    switch (type) {
      case 'hospital':
        return 'Hospital';
      case 'police':
        return 'Police';
      case 'pharmacy':
        return 'Pharmacy';
      case 'fuel':
        return 'Fuel';
      default:
        return 'Service';
    }
  }
}

class _EmptyNearby extends StatelessWidget {
  const _EmptyNearby();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(Icons.place_outlined, size: 42),
            SizedBox(height: 10),
            Text(
              'Use “Find nearby services” to query hospitals, police stations, '
              'pharmacies and fuel stations around your real location.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }
}
