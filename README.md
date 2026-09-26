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
- Official grievance and e-Challan portal shortcuts
- Optional Firebase anonymous authentication + Firestore live safety-session location sync
- Premium black/white Material 3 UI
- Android CI build with downloadable debug APK artifact

## First run

Generate the Flutter platform folders once:

### Windows PowerShell

```powershell
./tool/bootstrap.ps1
flutter run
```

### macOS / Linux

```bash
chmod +x tool/bootstrap.sh
./tool/bootstrap.sh
flutter run
```

## Firebase live sync

Core SOS/GPS/nearby/Medical ID features run without Firebase. To enable the cloud live-safety session, enable Anonymous Authentication and Firestore in your Firebase project, deploy `firebase.rules`, then build with your Firebase values:

```bash
flutter run \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_PROJECT_ID=... \
  --dart-define=FIREBASE_STORAGE_BUCKET=...
```

No API keys are committed to Git.

## Firestore

Deploy the included restrictive rules with Firebase CLI:

```bash
firebase deploy --only firestore:rules
```

The current live session is owner-only. Guardian-facing authenticated sharing should be added before production family tracking.

## Safety behavior

Holding SOS for three seconds opens emergency actions. GuardianX does not automatically call or message anyone on a long press; the user selects the action to reduce accidental emergency calls.

## CI

`.github/workflows/flutter.yml` runs analysis/tests and builds a debug APK on pushes and pull requests.
