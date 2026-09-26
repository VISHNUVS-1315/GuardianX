import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import '../core/firebase_runtime.dart';
import '../models/emergency_contact.dart';
import 'location_service.dart';

class RealtimeSyncService {
  StreamSubscription<Position>? _subscription;
  String? _sessionId;

  bool get active => _subscription != null;
  String? get sessionId => _sessionId;

  Future<String> start(List<EmergencyContact> contacts) async {
    if (!FirebaseRuntime.isReady) {
      throw Exception(
        FirebaseRuntime.error ?? 'Firebase is not configured.',
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Firebase authentication is unavailable.');

    await stop();

    final doc = FirebaseFirestore.instance.collection('safety_sessions').doc();
    _sessionId = doc.id;
    await doc.set({
      'ownerUid': user.uid,
      'active': true,
      'startedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'guardianCount': contacts.length,
    });

    _subscription = LocationService.stream().listen(
      (position) async {
        try {
          await doc.set(
            {
              'active': true,
              'updatedAt': FieldValue.serverTimestamp(),
              'location': {
                'latitude': position.latitude,
                'longitude': position.longitude,
                'accuracy': position.accuracy,
                'speed': position.speed,
                'heading': position.heading,
                'deviceTime': position.timestamp.toIso8601String(),
              },
            },
            SetOptions(merge: true),
          );
        } catch (_) {
          // Keep the GPS stream alive; the next update can recover.
        }
      },
    );

    return doc.id;
  }

  Future<void> stop() async {
    final id = _sessionId;
    await _subscription?.cancel();
    _subscription = null;
    _sessionId = null;

    if (id != null && FirebaseRuntime.isReady) {
      try {
        await FirebaseFirestore.instance
            .collection('safety_sessions')
            .doc(id)
            .set(
          {
            'active': false,
            'updatedAt': FieldValue.serverTimestamp(),
            'endedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } catch (_) {
        // Session shutdown should never block local emergency features.
      }
    }
  }
}
