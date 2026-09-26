import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseRuntime {
  FirebaseRuntime._();

  static bool isReady = false;
  static bool authReady = false;
  static String? error;

  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const _senderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _storageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const _authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const _configuredPublicWebUrl =
      String.fromEnvironment('GUARDIANX_PUBLIC_WEB_URL');

  static bool get hasConfiguration =>
      _apiKey.isNotEmpty &&
      _appId.isNotEmpty &&
      _senderId.isNotEmpty &&
      _projectId.isNotEmpty;

  static String get projectId => _projectId;

  static String get publicWebUrl {
    final configured = _configuredPublicWebUrl.trim();
    if (configured.isNotEmpty) {
      return configured.endsWith('/')
          ? configured.substring(0, configured.length - 1)
          : configured;
    }
    return 'https://$_projectId.web.app';
  }

  static Future<void> initialize() async {
    isReady = false;
    authReady = false;

    if (!hasConfiguration) {
      error = 'Firebase env values are not configured; local mode is active.';
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: _apiKey,
            appId: _appId,
            messagingSenderId: _senderId,
            projectId: _projectId,
            storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
            authDomain: kIsWeb && _authDomain.isNotEmpty ? _authDomain : null,
          ),
        );
      }
      isReady = true;
    } catch (e) {
      error = 'Firebase initialization failed: $e';
      return;
    }

    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      authReady = FirebaseAuth.instance.currentUser != null;
      error = authReady ? null : 'Firebase connected but authentication is unavailable.';
    } catch (e) {
      // Public live-share viewers only need Firebase itself, not authentication.
      authReady = false;
      error = 'Firebase connected; anonymous authentication failed: $e';
    }
  }
}
