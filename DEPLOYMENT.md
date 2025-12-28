# Deployment Guide

## Version Management

This project uses automatic version checking to ensure users always get the latest updates on web.

### Files that contain version numbers:
1. **`pubspec.yaml`** (line 5) - Main version source
2. **`lib/utils/version_check.dart`** (line 6) - Used for web update detection
3. **`lib/screens/home_screen.dart`** - Version display in UI

⚠️ **All three files must have the same version number!**

---

## Deployment Scripts

### Quick Version Check
```powershell
.\check-version.ps1
```
This quickly verifies all version numbers match across files.

### Full Deployment
```powershell
.\deploy.ps1
```
This script will:
1. ✅ Check version consistency
2. ⚠️ Prompt for confirmation
3. 🧹 Clean previous build
4. 📦 Get dependencies
5. 🔨 Build for web (release mode)
6. 🚀 Deploy to Firebase Hosting

If versions don't match, the script **stops** and shows which files need updating.

---

## Manual Deployment Workflow

If you prefer to deploy manually:

```powershell
# 1. Check versions match
.\check-version.ps1

# 2. Clean and build
flutter clean
flutter pub get
flutter build web --release

# 3. Deploy
firebase deploy --only hosting --force
```

---

## Before Each Deployment

### Step 1: Update Version Number
Increment the version in these files:

**`pubspec.yaml`:**
```yaml
version: 0.1.0+8  # Change this
```

**`lib/utils/version_check.dart`:**
```dart
static const String currentVersion = '0.1.0+8'; // Change this
```

**`lib/screens/home_screen.dart`:**
```dart
'Version 0.1.0+8',  // Change this
```

### Step 2: Verify Consistency
```powershell
.\check-version.ps1
```

### Step 3: Deploy
```powershell
.\deploy.ps1
```

---

## Version Numbering

We use semantic versioning with build numbers:

```
MAJOR.MINOR.PATCH+BUILD
  0  . 1  . 0   + 7
```

- **MAJOR**: Breaking changes
- **MINOR**: New features (backwards compatible)
- **PATCH**: Bug fixes
- **BUILD**: Build number (increment with each deployment)

### Examples:
- Bug fix: `0.1.0+7` → `0.1.0+8`
- New feature: `0.1.0+8` → `0.2.0+9`
- Breaking change: `0.2.0+9` → `1.0.0+10`

---

## How Version Check Works

When users open the web app:
1. App checks stored version vs. current version
2. If different → Shows "New Version Available" dialog
3. User clicks "Refresh Now" → Page reloads with latest code
4. New version is saved for next visit

This ensures users always see the latest updates without manual cache clearing!

---

## Firebase Cache Configuration

[`firebase.json`](firebase.json) is configured to:
- **Never cache**: `index.html`, `flutter_service_worker.js`
- **Cache 1 week**: JavaScript & CSS files
- **Cache 1 year**: Images, fonts (immutable assets)

This prevents most cache issues automatically.

---

## Troubleshooting

### "Version mismatch" error
Run `.\check-version.ps1` to see which files differ, then update them to match.

### Users don't see updates
1. Wait 5-10 minutes for CDN propagation
2. Check Firebase Console for deployment timestamp
3. Test in incognito/private mode
4. Version check dialog should appear automatically

### Deploy script fails
Check each step:
- `flutter --version` (Flutter installed?)
- `firebase --version` (Firebase CLI installed?)
- `firebase projects:list` (Logged in to Firebase?)

---

## Quick Reference

```powershell
# Check versions
.\check-version.ps1

# Full deployment
.\deploy.ps1

# Manual build only
flutter build web --release

# Deploy only (after build)
firebase deploy --only hosting --force

# Test build locally
firebase serve --only hosting
```
