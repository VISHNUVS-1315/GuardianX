#!/usr/bin/env bash
set -euo pipefail

flutter create . \
  --project-name guardianx_app \
  --org com.example \
  --platforms=android,web,windows

flutter pub get
flutter analyze
flutter test

echo "GuardianX bootstrap complete."
echo "Run: flutter run"
