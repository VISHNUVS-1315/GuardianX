import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/firebase_runtime.dart';

class LiveShareScreen extends StatelessWidget {
  const LiveShareScreen({super.key, required this.shareId});

  final String shareId;

  Future<void> _openMaps(double latitude, double longitude) async {
    final uri = Uri.https(
      'www.google.com',
      '/maps/search/',
      {'api': '1', 'query': '$latitude,$longitude'},
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) throw Exception('Unable to open Google Maps.');
  }

  @override
  Widget build(BuildContext context) {
    if (!FirebaseRuntime.isReady) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Text(
              'GuardianX live tracking is not configured on this web build.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('GuardianX Live Safety')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('sos_shares')
            .doc(shareId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _MessageState(
              icon: Icons.link_off,
              title: 'Tracking link unavailable',
              message:
                  'This link may have expired, ended, or no longer be accessible.',
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data();
          if (!snapshot.data!.exists || data == null) {
            return const _MessageState(
              icon: Icons.hourglass_empty,
              title: 'Waiting for location',
              message: 'The safety session has not published a location yet.',
            );
          }

          final location = data['location'];
          final latitude = location is Map
              ? (location['latitude'] as num?)?.toDouble()
              : null;
          final longitude = location is Map
              ? (location['longitude'] as num?)?.toDouble()
              : null;
          final accuracy = location is Map
              ? (location['accuracy'] as num?)?.toDouble()
              : null;
          final active = data['active'] == true;
          final updated = data['updatedAt'];
          final updatedAt = updated is Timestamp ? updated.toDate() : null;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor:
                            active ? Colors.greenAccent : Colors.white24,
                        foregroundColor: Colors.black,
                        child: Icon(
                          active ? Icons.location_searching : Icons.location_off,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              active ? 'Live session active' : 'Session ended',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              updatedAt == null
                                  ? 'Waiting for an update…'
                                  : 'Last update: ${updatedAt.toLocal()}',
                              style: const TextStyle(color: Colors.white60),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current location',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (latitude != null && longitude != null) ...[
                        Text(
                          '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        if (accuracy != null) ...[
                          const SizedBox(height: 5),
                          Text(
                            'Accuracy ±${accuracy.toStringAsFixed(0)} m',
                            style: const TextStyle(color: Colors.white60),
                          ),
                        ],
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: () async {
                            try {
                              await _openMaps(latitude, longitude);
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          },
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('Open in Google Maps'),
                        ),
                      ] else
                        const Text(
                          'Waiting for GPS…',
                          style: TextStyle(color: Colors.white60),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'For emergencies in India, call 112. GuardianX tracking is a support tool and is not an emergency response service.',
                style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 58),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: Colors.white60, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
