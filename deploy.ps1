#!/usr/bin/env pwsh
# Deployment script with version validation for RoundnetBoard

Write-Host "`n=== RoundnetBoard Deployment Script ===" -ForegroundColor Cyan

# Extract version from pubspec.yaml
$pubspecContent = Get-Content "pubspec.yaml" -Raw
if ($pubspecContent -match 'version:\s*([0-9]+\.[0-9]+\.[0-9]+\+[0-9]+)') {
    $pubspecVersion = $matches[1]
    Write-Host "✓ pubspec.yaml version: $pubspecVersion" -ForegroundColor Green
} else {
    Write-Host "✗ Could not find version in pubspec.yaml" -ForegroundColor Red
    exit 1
}

# Extract version from version_check.dart
$versionCheckContent = Get-Content "lib/utils/version_check.dart" -Raw
if ($versionCheckContent -match "currentVersion\s*=\s*'([^']+)'") {
    $versionCheckVersion = $matches[1]
    Write-Host "✓ version_check.dart version: $versionCheckVersion" -ForegroundColor Green
} else {
    Write-Host "✗ Could not find version in version_check.dart" -ForegroundColor Red
    exit 1
}

# Compare versions
if ($pubspecVersion -ne $versionCheckVersion) {
    Write-Host "`n✗ VERSION MISMATCH!" -ForegroundColor Red
    Write-Host "  pubspec.yaml:        $pubspecVersion" -ForegroundColor Yellow
    Write-Host "  version_check.dart:  $versionCheckVersion" -ForegroundColor Yellow
    Write-Host "`nPlease update both files to have the same version before deploying." -ForegroundColor Red
    Write-Host "Files to update:" -ForegroundColor Yellow
    Write-Host "  1. pubspec.yaml (line 5)" -ForegroundColor Gray
    Write-Host "  2. lib/utils/version_check.dart (line 6)" -ForegroundColor Gray
    Write-Host "  3. lib/screens/home_screen.dart (version display)" -ForegroundColor Gray
    exit 1
}

Write-Host "`n✓ Version check passed: $pubspecVersion" -ForegroundColor Green

# Ask for confirmation
Write-Host "`nReady to deploy version $pubspecVersion to Firebase?" -ForegroundColor Cyan
$confirmation = Read-Host "Continue? (y/n)"
if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
    Write-Host "Deployment cancelled." -ForegroundColor Yellow
    exit 0
}

# Clean build
Write-Host "`n[1/4] Cleaning previous build..." -ForegroundColor Yellow
flutter clean
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Flutter clean failed!" -ForegroundColor Red
    exit 1
}

# Get dependencies
Write-Host "`n[2/4] Getting dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Flutter pub get failed!" -ForegroundColor Red
    exit 1
}

# Build for web
Write-Host "`n[3/4] Building Flutter web app (release mode)..." -ForegroundColor Yellow
flutter build web --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Flutter build failed!" -ForegroundColor Red
    exit 1
}

# Deploy to Firebase
Write-Host "`n[4/4] Deploying to Firebase Hosting..." -ForegroundColor Yellow
firebase deploy --only hosting --force
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Firebase deployment failed!" -ForegroundColor Red
    exit 1
}

Write-Host "`n✓ Deployment complete! Version $pubspecVersion is now live." -ForegroundColor Green
Write-Host "Clear your browser cache or wait a few minutes for CDN propagation." -ForegroundColor Gray
