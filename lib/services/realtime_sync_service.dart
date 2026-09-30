import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import '../core/firebase_runtime.dart';
import '../models/emergency_contact.dart';
import 'location_service.dart';

class RealtimeSyncService {
  StreamSubscription<Position>? _subscription;
  String? _sessionId;
  String? _shareId;
  String _status = 'ended';

  static const _allowedStatuses = {'tracking', 'safe', 'moving', 'help'};

  bool get active => _subscription != null;
  String? get sessionId => _sessionId;
  String? get shareId => _shareId;
  String get status => _status;
  String? get shareUrl => _shareId == null
      ? null
      : '${FirebaseRuntime.publicWebUrl}/#/share/$_shareId';

  Future<String> start(List<EmergencyContact> contacts) async {
    if (!FirebaseRuntime.authReady) {
      throw Exception(
        FirebaseRuntime.error ?? 'Firebase authentication is not ready.',
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Firebase authentication is unavailable.');

    await stop();

    final db = FirebaseFirestore.instance;
    final sessionDoc = db.collection('safety_sessions').doc();
    final shareDoc = db.collection('sos_shares').doc(_secureToken());
    final firstPosition = await LocationService.current();
    final expiresAt = DateTime.now().toUtc().add(const Duration(hours: 6));

    _sessionId = sessionDoc.id;
    _shareId = shareDoc.id;
    _status = 'tracking';

    final initialLocation = _locationMap(firstPosition);
    final batch = db.batch();
    batch.set(sessionDoc, {
      'ownerUid': user.uid,
      'active': true,
      'status': _status,
      'statusUpdatedAt': FieldValue.serverTimestamp(),
      'startedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'guardianCount': contacts.length,
      'location': initialLocation,
    });
    batch.set(shareDoc, {
      'ownerUid': user.uid,
      'active': true,
      'status': _status,
      'statusUpdatedAt': FieldValue.serverTimestamp(),
      'startedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'guardianCount': contacts.length,
      'location': initialLocation,
    });
    await batch.commit();

    _subscription = LocationService.stream().listen(
      (position) async {
        try {
          final updateBatch = db.batch();
          final update = {
            'active': true,
            'updatedAt': FieldValue.serverTimestamp(),
            'location': _locationMap(position),
          };
          updateBatch.set(sessionDoc, update, SetOptions(merge: true));
          updateBatch.set(shareDoc, update, SetOptions(merge: true));
          await updateBatch.commit();
        } catch (_) {
          // Keep GPS alive so the next update can recover from network loss.
        }
      },
      onError: (_) {
        // Local SOS remains available even if live GPS streaming fails.
      },
    );

    return shareUrl ?? sessionDoc.id;
  }

  Future<void> updateStatus(String status) async {
    if (!_allowedStatuses.contains(status)) {
      throw ArgumentError.value(status, 'status', 'Unsupported safety status.');
    }
    final sessionId = _sessionId;
    final shareId = _shareId;
    if (!active || sessionId == null || shareId == null) {
      throw Exception('Start live guardian tracking before updating status.');
    }
    if (!FirebaseRuntime.authReady) {
      throw Exception('Firebase live sync is unavailable.');
    }

    final db = FirebaseFirestore.instance;
    final update = {
      'status': status,
      'statusUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final batch = db.batch();
    batch.set(
      db.collection('safety_sessions').doc(sessionId),
      update,
      SetOptions(merge: true),
    );
    batch.set(
      db.collection('sos_shares').doc(shareId),
      update,
      SetOptions(merge: true),
    );
    await batch.commit();
    _status = status;
  }

  Future<void> stop() async {
    final sessionId = _sessionId;
    final shareId = _shareId;
    await _subscription?.cancel();
    _subscription = null;
    _sessionId = null;
    _shareId = null;
    _status = 'ended';

    if (!FirebaseRuntime.isReady) return;

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      final ended = {
        'active': false,
        'status': 'ended',
        'statusUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'endedAt': FieldValue.serverTimestamp(),
      };
      if (sessionId != null) {
        batch.set(
          db.collection('safety_sessions').doc(sessionId),
          ended,
          SetOptions(merge: true),
        );
      }
      if (shareId != null) {
        batch.set(
          db.collection('sos_shares').doc(shareId),
          ended,
          SetOptions(merge: true),
        );
      }
      if (sessionId != null || shareId != null) await batch.commit();
    } catch (_) {
      // Shutdown must never block the rest of the app.
    }
  }

  static Map<String, dynamic> _locationMap(Position position) {
    return {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'speed': position.speed,
      'heading': position.heading,
      'deviceTime': position.timestamp.toIso8601String(),
    };
  }

  static String _secureToken() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(40, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
