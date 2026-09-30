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
- Live safety status updates: **I am safe / On the move / Need help**
- Guardian-facing stale GPS warning and last-update visibility
- Non-enumerable private public-share links with six-hour expiry
- Firebase Hosting for the web app
- Premium black/white Material 3 UI
- Android CI build with downloadable debug APK artifact

## Realtime safety flow

1. Hold the SOS control for three seconds.
2. Start live guardian tracking.
3. Share the private tracking link by SMS, WhatsApp, or copy it manually.
4. GuardianX streams GPS updates to Firestore while the live session is active.
5. The owner can update their live status to **I am safe**, **On the move**, or **Need help**.
6. Anyone with the private link sees the latest status, GPS coordinates, accuracy, last update, movement speed when available, and a warning if the GPS feed becomes stale.
7. Stopping the safety session marks the link as ended. Share documents expire automatically after six hours.

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

GuardianX uses the official FlutterFire generated configuration. On Windows, the repository includes a one-command setup that installs/updates the Firebase and FlutterFire CLIs, signs in to your Google account, creates or reuses the Firebase project, registers Android and Web apps, creates Firestore, enables Anonymous Authentication, deploys the security rules, builds the web app, and deploys Firebase Hosting.

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
- **Cloud Firestore:** Live safety-session data, status updates, share records and per-user metadata.
- **Firebase Hosting:** GuardianX web app and public live-share links.
- **Cloud Storage:** Used by the cloud document vault when available.

### Cloud Storage billing note

New Cloud Storage for Firebase projects require the Blaze billing plan. The setup script therefore does not provision/deploy Storage by default. SOS, GPS, Authentication, Firestore live tracking, nearby services and Firebase Hosting do not depend on the Storage bucket. The cloud document vault requires Storage to be enabled separately.

## Firestore security

The repository includes `firebase.rules`. Firebase setup deploys these rules automatically. Live sessions are owner-controlled. Public share documents are readable only by direct document ID until expiry; collection listing is blocked so active share links cannot be browsed from Firestore.

## Safety behavior

Holding SOS for three seconds opens emergency actions. GuardianX does not automatically call or message anyone on a long press; the user selects the action to reduce accidental emergency calls. A **Need help** live status is a signal to people who already have the private GuardianX tracking link; it is not an automatic emergency-services dispatch.

## CI

`.github/workflows/flutter.yml` runs analysis/tests, builds an Android debug APK and builds Flutter Web on pushes and pull requests.
