# GuardianX

GuardianX is a Flutter personal-safety application rebuilt around real device data instead of mock screens.

## Working MVP

- 3-second hold SOS entry with explicit emergency actions
- Real GPS location and accuracy
- Emergency SMS with a Google Maps location link
- WhatsApp SOS share
- India emergency number 112 dialer action
- Trusted guardian list persisted on-device
- Nearby hospitals, police stations, pharmacies and fuel stations using OpenStreetMap/Overpass data
- Google Maps navigation handoff
- Medical ID stored in encrypted device storage
- GuardianX AI assistant
- Firebase Anonymous Authentication
- Firestore real-time safety-session location sync
- Public guardian live-share page
- Firebase Hosting for the web app
- Premium black/white Material 3 UI
- Android CI build with downloadable debug APK artifact

## First run

### Windows PowerShell

```powershell
./tool/bootstrap.ps1
flutter run -d chrome
```

### macOS / Linux

```bash
chmod +x tool/bootstrap.sh
./tool/bootstrap.sh
flutter run -d chrome
```

## Create and integrate Firebase

GuardianX now uses the official FlutterFire generated configuration. On Windows, the repository includes a one-command setup that installs/updates the Firebase and FlutterFire CLIs, signs in to your Google account, creates or reuses the Firebase project, registers Android and Web apps, creates Firestore, enables Anonymous Authentication, deploys the security rules, builds the web app, and deploys Firebase Hosting.

From the repository root run:

```powershell
./tool/setup_firebase.ps1 -RunChrome
```

Default Firebase project ID:

```text
guardianx-vs1315
```

To choose another globally unique project ID:

```powershell
./tool/setup_firebase.ps1 -ProjectId "your-guardianx-project-id" -RunChrome
```

The setup uses `asia-south1` for Firestore by default. Override it with `-Location` if needed.

After setup, FlutterFire replaces the repository placeholder at `lib/firebase_options.dart` with the actual Android/Web Firebase configuration and GuardianX starts Firebase automatically from `main.dart`.

## Firebase services used

- **Firebase Authentication:** Anonymous sign-in for the current GuardianX MVP.
- **Cloud Firestore:** Live safety-session data, share records and per-user metadata.
- **Firebase Hosting:** GuardianX web app and public live-share links.
- **Cloud Storage:** Used by the cloud document vault when available.

### Cloud Storage billing note

New Cloud Storage for Firebase projects require the Blaze billing plan. The setup script therefore does not provision/deploy Storage by default. SOS, GPS, Authentication, Firestore live tracking, nearby services and Firebase Hosting do not depend on the Storage bucket. The cloud document vault requires Storage to be enabled separately.

## Firestore security

The repository includes `firebase.rules`. Firebase setup deploys these rules automatically. Live sessions are owner-controlled while share documents have an expiry check for public viewing.

## Safety behavior

Holding SOS for three seconds opens emergency actions. GuardianX does not automatically call or message anyone on a long press; the user selects the action to reduce accidental emergency calls.

## CI

`.github/workflows/flutter.yml` runs analysis/tests, builds an Android debug APK and builds Flutter Web on pushes and pull requests.
