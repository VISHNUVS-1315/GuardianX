import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

class CrashSignal {
  const CrashSignal({
    required this.detectedAt,
    required this.accelerationMagnitude,
    required this.rotationMagnitude,
  });

  final DateTime detectedAt;
  final double accelerationMagnitude;
  final double rotationMagnitude;

  double get accelerationG => accelerationMagnitude / 9.80665;
}

class CrashDetectionService {
  CrashDetectionService();

  static const double _impactThreshold = 30.0;
  static const double _severeImpactThreshold = 45.0;
  static const double _rotationThreshold = 3.5;
  static const Duration _rotationWindow = Duration(milliseconds: 1200);
  static const Duration _triggerCooldown = Duration(seconds: 30);

  StreamSubscription<UserAccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  Future<void> Function(CrashSignal signal)? _onPotentialCrash;

  DateTime? _lastRotationAt;
  DateTime? _lastTriggerAt;
  double _lastRotationMagnitude = 0;
  double _lastAccelerationMagnitude = 0;
  bool _monitoring = false;
  String? _error;

  bool get monitoring => _monitoring;
  String? get error => _error;
  double get lastAccelerationMagnitude => _lastAccelerationMagnitude;

  static bool get isSupportedPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> start(
    Future<void> Function(CrashSignal signal) onPotentialCrash,
  ) async {
    await stop();

    if (!isSupportedPlatform) {
      throw UnsupportedError(
        'Crash detection currently requires an Android or iOS device.',
      );
    }

    _onPotentialCrash = onPotentialCrash;
    _error = null;
    _monitoring = true;

    _gyroscopeSubscription = gyroscopeEventStream().listen(
      _handleGyroscope,
      onError: (Object error) {
        _error = 'Gyroscope unavailable: $error';
      },
      cancelOnError: false,
    );

    _accelerometerSubscription = userAccelerometerEventStream().listen(
      _handleAcceleration,
      onError: (Object error) {
        _error = 'Accelerometer unavailable: $error';
        _monitoring = false;
      },
      cancelOnError: false,
    );
  }

  void _handleGyroscope(GyroscopeEvent event) {
    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    _lastRotationMagnitude = magnitude;
    if (magnitude >= _rotationThreshold) {
      _lastRotationAt = DateTime.now();
    }
  }

  void _handleAcceleration(UserAccelerometerEvent event) {
    if (!_monitoring) return;

    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    _lastAccelerationMagnitude = magnitude;

    if (magnitude < _impactThreshold) return;

    final now = DateTime.now();
    final lastTrigger = _lastTriggerAt;
    if (lastTrigger != null && now.difference(lastTrigger) < _triggerCooldown) {
      return;
    }

    final lastRotation = _lastRotationAt;
    final hasRecentRotation = lastRotation != null &&
        now.difference(lastRotation).abs() <= _rotationWindow;
    final severeImpact = magnitude >= _severeImpactThreshold;

    if (!hasRecentRotation && !severeImpact) return;

    _lastTriggerAt = now;
    final callback = _onPotentialCrash;
    if (callback == null) return;

    unawaited(
      callback(
        CrashSignal(
          detectedAt: now,
          accelerationMagnitude: magnitude,
          rotationMagnitude: _lastRotationMagnitude,
        ),
      ),
    );
  }

  Future<void> stop() async {
    await _accelerometerSubscription?.cancel();
    await _gyroscopeSubscription?.cancel();
    _accelerometerSubscription = null;
    _gyroscopeSubscription = null;
    _onPotentialCrash = null;
    _monitoring = false;
  }
}
