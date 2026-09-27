import 'package:firebase_core/firebase_core.dart';

/// This placeholder keeps GuardianX buildable before a Firebase project is linked.
///
/// Run `tool/setup_firebase.ps1` (Windows) or `tool/setup_firebase.sh`
/// (macOS/Linux). FlutterFire CLI will replace this file with the real,
/// platform-specific Firebase configuration for Android and Web.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'GuardianX Firebase is not linked yet. Run the Firebase setup script.',
    );
  }
}
