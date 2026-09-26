import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseRuntime {
  FirebaseRuntime._();

  static bool isReady = false;
  static String? error;

  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const _senderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _storageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const _authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');

  static bool get hasConfiguration =>
      _apiKey.isNotEmpty &&
      _appId.isNotEmpty &&
      _senderId.isNotEmpty &&
      _projectId.isNotEmpty;

  static Future<void> initialize() async {
    if (!hasConfiguration) {
      error = 'Firebase env values are not configured; local mode is active.';
      return;
    }

    try {
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

      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      isReady = true;
      error = null;
    } catch (e) {
      isReady = false;
      error = e.toString();
    }
  }
}
