#!/usr/bin/env bash
set -euo pipefail

flutter create . \
  --project-name guardianx_app \
  --org com.guardianx \
  --platforms=android,web,windows

dart run tool/configure_android.dart
flutter pub get
flutter analyze
flutter test

echo "GuardianX bootstrap complete."
echo "Run: flutter run"
