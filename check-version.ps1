#!/usr/bin/env pwsh
# Quick version consistency check

Write-Host "`n=== Version Consistency Check ===" -ForegroundColor Cyan

# Extract version from pubspec.yaml
$pubspecContent = Get-Content "pubspec.yaml" -Raw
if ($pubspecContent -match 'version:\s*([0-9]+\.[0-9]+\.[0-9]+\+[0-9]+)') {
    $pubspecVersion = $matches[1]
    Write-Host "pubspec.yaml:        $pubspecVersion" -ForegroundColor White
} else {
    Write-Host "pubspec.yaml:        NOT FOUND" -ForegroundColor Red
    $pubspecVersion = $null
}

# Extract version from version_check.dart
$versionCheckContent = Get-Content "lib/utils/version_check.dart" -Raw
if ($versionCheckContent -match "currentVersion\s*=\s*'([^']+)'") {
    $versionCheckVersion = $matches[1]
    Write-Host "version_check.dart:  $versionCheckVersion" -ForegroundColor White
} else {
    Write-Host "version_check.dart:  NOT FOUND" -ForegroundColor Red
    $versionCheckVersion = $null
}

# Extract version from home_screen.dart
$homeScreenContent = Get-Content "lib/screens/home_screen.dart" -Raw
if ($homeScreenContent -match "Version\s+([0-9]+\.[0-9]+\.[0-9]+\+[0-9]+)") {
    $homeScreenVersion = $matches[1]
    Write-Host "home_screen.dart:    $homeScreenVersion" -ForegroundColor White
} else {
    Write-Host "home_screen.dart:    NOT FOUND" -ForegroundColor Yellow
    $homeScreenVersion = $null
}

# Compare versions
Write-Host ""
if ($pubspecVersion -and $versionCheckVersion -and $pubspecVersion -eq $versionCheckVersion) {
    Write-Host "SUCCESS: Versions match! Ready to deploy." -ForegroundColor Green
    
    if ($homeScreenVersion -and $homeScreenVersion -ne $pubspecVersion) {
        Write-Host "WARNING: home_screen.dart shows different version" -ForegroundColor Yellow
    }
} else {
    Write-Host "ERROR: VERSION MISMATCH! Update before deploying:" -ForegroundColor Red
    Write-Host "  1. pubspec.yaml (line 5)" -ForegroundColor Gray
    Write-Host "  2. lib/utils/version_check.dart (line 6)" -ForegroundColor Gray
    if ($homeScreenVersion) {
        Write-Host "  3. lib/screens/home_screen.dart (version display)" -ForegroundColor Gray
    }
}

Write-Host ""
