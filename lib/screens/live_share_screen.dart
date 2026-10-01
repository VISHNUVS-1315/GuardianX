import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/firebase_runtime.dart';
import '../core/theme.dart';

class LiveShareScreen extends StatelessWidget {
  LiveShareScreen({super.key, required this.shareId});

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

  String _statusLabel(String status, bool active) {
    if (!active) return 'Session ended';
    return switch (status) {
      'safe' => 'I am safe',
      'moving' => 'On the move',
      'help' => 'NEED HELP',
      _ => 'Live tracking',
    };
  }

  String _statusMessage(String status, bool active) {
    if (!active) {
      return 'The owner stopped this GuardianX safety session.';
    }
    return switch (status) {
      'safe' => 'The owner has checked in as safe.',
      'moving' => 'The owner says they are currently on the move.',
      'help' => 'The owner has marked that they need help. Contact them and use emergency services when appropriate.',
      _ => 'GuardianX is sharing the owner’s latest available location.',
    };
  }

  IconData _statusIcon(String status, bool active) {
    if (!active) return Icons.location_off;
    return switch (status) {
      'safe' => Icons.verified_user_outlined,
      'moving' => Icons.directions_walk,
      'help' => Icons.warning_amber_rounded,
      _ => Icons.location_searching,
    };
  }

  Color _statusColor(BuildContext context, String status, bool active) {
    if (!active) return Theme.of(context).colorScheme.outlineVariant;
    return switch (status) {
      'help' => GuardianXTheme.danger,
      _ => Theme.of(context).colorScheme.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!FirebaseRuntime.isReady) {
      return Scaffold(
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
      appBar: AppBar(title: Text('GuardianX Live Safety')),
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
            return Center(child: CircularProgressIndicator());
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
          final speed = location is Map
              ? (location['speed'] as num?)?.toDouble()
              : null;
          final active = data['active'] == true;
          final status = data['status'] as String? ?? 'tracking';
          final guardianCount = (data['guardianCount'] as num?)?.toInt();

          final updated = data['updatedAt'];
          final updatedAt = updated is Timestamp ? updated.toDate() : null;
          final statusUpdated = data['statusUpdatedAt'];
          final statusUpdatedAt =
              statusUpdated is Timestamp ? statusUpdated.toDate() : null;
          final isStale = active &&
              updatedAt != null &&
              DateTime.now().toUtc().difference(updatedAt.toUtc()) >
                  Duration(minutes: 2);

          final statusColor = _statusColor(context, status, active);

          return ListView(
            padding: EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: statusColor,
                        foregroundColor: !active
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : status == 'help'
                                ? Colors.white
                                : Theme.of(context).colorScheme.onPrimary,
                        child: Icon(_statusIcon(status, active)),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _statusLabel(status, active),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: status == 'help' && active
                                    ? GuardianXTheme.danger
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              _statusMessage(status, active),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                            if (statusUpdatedAt != null) ...[
                              SizedBox(height: 5),
                              Text(
                                'Status updated: ${statusUpdatedAt.toLocal()}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.outline,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isStale) ...[
                SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.sync_problem_outlined),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Location update may be stale',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Last GPS update: ${updatedAt.toLocal()}. The phone may be offline or location updates may be paused.',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Current location',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (guardianCount != null)
                            Text(
                              '$guardianCount guardian${guardianCount == 1 ? '' : 's'}',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                        ],
                      ),
                      SizedBox(height: 12),
                      if (latitude != null && longitude != null) ...[
                        Text(
                          '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
                          style: TextStyle(fontSize: 16),
                        ),
                        if (accuracy != null) ...[
                          SizedBox(height: 5),
                          Text(
                            'Accuracy ±${accuracy.toStringAsFixed(0)} m',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ],
                        if (speed != null && speed > 0.8) ...[
                          SizedBox(height: 5),
                          Text(
                            'Reported speed ${(speed * 3.6).toStringAsFixed(1)} km/h',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ],
                        if (updatedAt != null) ...[
                          SizedBox(height: 5),
                          Text(
                            'Last GPS update: ${updatedAt.toLocal()}',
                            style: TextStyle(color: Theme.of(context).colorScheme.outline),
                          ),
                        ],
                        SizedBox(height: 18),
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
                          icon: Icon(Icons.map_outlined),
                          label: Text('Open in Google Maps'),
                        ),
                      ] else
                        Text(
                          'Waiting for GPS…',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'For emergencies in India, call 112. GuardianX tracking is a support tool and is not an emergency response service.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, height: 1.4),
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
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 58),
            SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
