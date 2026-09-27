import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

class FirebaseRuntime {
  FirebaseRuntime._();

  static bool isReady = false;
  static bool authReady = false;
  static String? error;

  static const _configuredPublicWebUrl =
      String.fromEnvironment('GUARDIANX_PUBLIC_WEB_URL');

  static String get projectId {
    if (Firebase.apps.isEmpty) return '';
    return Firebase.app().options.projectId;
  }

  static String get publicWebUrl {
    final configured = _configuredPublicWebUrl.trim();
    if (configured.isNotEmpty) {
      return configured.endsWith('/')
          ? configured.substring(0, configured.length - 1)
          : configured;
    }

    final id = projectId;
    return id.isEmpty ? '' : 'https://$id.web.app';
  }

  static Future<void> initialize() async {
    isReady = false;
    authReady = false;
    error = null;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      isReady = true;
    } catch (e) {
      error = 'Firebase is not configured yet. Run tool/setup_firebase.ps1. $e';
      return;
    }

    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
      authReady = FirebaseAuth.instance.currentUser != null;
      error = authReady
          ? null
          : 'Firebase connected but anonymous authentication is unavailable.';
    } catch (e) {
      authReady = false;
      error = 'Firebase connected; anonymous authentication failed: $e';
    }
  }
}
