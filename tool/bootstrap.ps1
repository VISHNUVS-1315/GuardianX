$ErrorActionPreference = "Stop"

flutter create . `
  --project-name guardianx_app `
  --org com.example `
  --platforms=android,web,windows

flutter pub get
flutter analyze
flutter test

Write-Host "GuardianX bootstrap complete."
Write-Host "Run: flutter run"
