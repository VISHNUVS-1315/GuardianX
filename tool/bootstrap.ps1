$ErrorActionPreference = "Stop"

flutter create . `
  --project-name guardianx_app `
  --org com.guardianx `
  --platforms=android,web,windows

dart run tool/configure_android.dart
flutter pub get
flutter analyze
flutter test

Write-Host "GuardianX bootstrap complete."
Write-Host "Run: flutter run"
