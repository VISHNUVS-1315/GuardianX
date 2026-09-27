param(
  [string]$ProjectId = "guardianx-vs1315",
  [string]$Location = "asia-south1",
  [switch]$RunChrome
)

$ErrorActionPreference = "Stop"

function Require-LastExit([string]$Step) {
  if ($LASTEXITCODE -ne 0) {
    throw "$Step failed with exit code $LASTEXITCODE"
  }
}

Write-Host "=== GuardianX Firebase Setup ===" -ForegroundColor Cyan
Write-Host "Project: $ProjectId"
Write-Host "Firestore location: $Location"

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw "Flutter is not installed or not available in PATH."
}

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  throw "Node.js 18+ is required for Firebase CLI. Install Node.js and rerun this script."
}

if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
  Write-Host "Installing Firebase CLI..." -ForegroundColor Yellow
  npm install -g firebase-tools
  Require-LastExit "Firebase CLI installation"
}

Write-Host "Updating FlutterFire CLI..." -ForegroundColor Yellow
dart pub global activate flutterfire_cli
Require-LastExit "FlutterFire CLI installation"

if (-not (Get-Command flutterfire -ErrorAction SilentlyContinue)) {
  $pubCacheBin = Join-Path $env:LOCALAPPDATA "Pub\Cache\bin"
  if (Test-Path $pubCacheBin) {
    $env:PATH = "$pubCacheBin;$env:PATH"
  }
}

if (-not (Get-Command flutterfire -ErrorAction SilentlyContinue)) {
  throw "flutterfire command was installed but is not in PATH. Add your Dart Pub Cache bin folder to PATH and rerun."
}

Write-Host "Signing in to Firebase..." -ForegroundColor Yellow
firebase login
Require-LastExit "Firebase login"

$projectsRaw = firebase projects:list --json
Require-LastExit "Firebase project list"
$projectsJson = $projectsRaw | ConvertFrom-Json
$projects = @($projectsJson.result)
$projectExists = $projects | Where-Object { $_.projectId -eq $ProjectId }

if (-not $projectExists) {
  Write-Host "Creating Firebase project $ProjectId..." -ForegroundColor Yellow
  firebase projects:create $ProjectId --display-name "GuardianX"
  Require-LastExit "Firebase project creation"
} else {
  Write-Host "Firebase project already exists; reusing it." -ForegroundColor Green
}

@{
  projects = @{
    default = $ProjectId
  }
} | ConvertTo-Json -Depth 4 | Set-Content -Encoding UTF8 .firebaserc

if (-not (Test-Path "android") -or -not (Test-Path "web")) {
  Write-Host "Generating Flutter Android/Web runners..." -ForegroundColor Yellow
  flutter create . --project-name guardianx_app --org com.guardianx --platforms=android,web
  Require-LastExit "Flutter runner generation"
}

dart run tool/configure_android.dart
Require-LastExit "Android permission configuration"

flutter pub get
Require-LastExit "Flutter package restore"

Write-Host "Registering GuardianX Android + Web apps with Firebase..." -ForegroundColor Yellow
flutterfire configure `
  --yes `
  --project=$ProjectId `
  --platforms=android,web `
  --android-package-name=com.guardianx.guardianx_app `
  --display-name=GuardianX
Require-LastExit "FlutterFire configuration"

dart run tool/configure_firebase.dart
Require-LastExit "Firebase config normalization"

Write-Host "Checking Firestore database..." -ForegroundColor Yellow
firebase firestore:databases:get "(default)" --project=$ProjectId --json *> $null
if ($LASTEXITCODE -ne 0) {
  Write-Host "Creating Firestore database in $Location..." -ForegroundColor Yellow
  firebase firestore:databases:create "(default)" --location=$Location --project=$ProjectId
  Require-LastExit "Firestore database creation"
} else {
  Write-Host "Firestore database already exists." -ForegroundColor Green
}

Write-Host "Enabling Anonymous Authentication and deploying Firestore rules..." -ForegroundColor Yellow
firebase deploy --only "auth,firestore:rules" --project=$ProjectId
Require-LastExit "Firebase Auth / Firestore rules deployment"

Write-Host "Building GuardianX Web..." -ForegroundColor Yellow
flutter build web --release
Require-LastExit "Flutter web build"

Write-Host "Deploying GuardianX to Firebase Hosting..." -ForegroundColor Yellow
firebase deploy --only hosting --project=$ProjectId
Require-LastExit "Firebase Hosting deployment"

Write-Host "" 
Write-Host "GuardianX Firebase integration complete." -ForegroundColor Green
Write-Host "Hosting: https://$ProjectId.web.app"
Write-Host "Android package: com.guardianx.guardianx_app"
Write-Host "Anonymous Auth: enabled"
Write-Host "Firestore: configured with repo security rules"
Write-Host ""
Write-Host "Cloud Storage is intentionally not provisioned by this script because new Firebase Storage projects require the Blaze billing plan. Core SOS/live tracking/Auth/Hosting work without it." -ForegroundColor DarkYellow

if ($RunChrome) {
  Write-Host "Launching GuardianX in Chrome..." -ForegroundColor Cyan
  flutter run -d chrome
} else {
  Write-Host "Run in Chrome: flutter run -d chrome"
}
