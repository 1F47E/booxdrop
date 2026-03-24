---
name: release-flutter
description: Build, version bump, changelog, and install Smarty Pants Flutter APK to connected Boox device
argument-hint: [patch|minor|major]
---

# Smarty Pants (Flutter) Release

Bump version, generate changelog from git commits, build APK with baked-in version/date, and install to connected device.

## Usage

Parse `$ARGUMENTS`:

| Arg | Values | Default | Notes |
|-----|--------|---------|-------|
| bump type | `patch`, `minor`, `major` | `patch` | Which semver component to bump |

## Steps

### 1. Determine new version

Read current version from `booxchat_flutter/pubspec.yaml` (the `version:` line, format `X.Y.Z+N`).

Bump according to the argument:
- `patch`: `1.0.0` → `1.0.1`
- `minor`: `1.0.0` → `1.1.0`
- `major`: `1.0.0` → `2.0.0`

Also increment the build number (`+N`) by 1.

### 2. Generate changelog entry

Get the last git tag matching `flutter-v*`:

```bash
git tag -l 'flutter-v*' --sort=-v:refname | head -1
```

If no tag exists, use the first commit. Get commits since that tag:

```bash
git log $LAST_TAG..HEAD --oneline -- booxchat_flutter/
```

Prepend a new section to `booxchat_flutter/CHANGELOG.md`:

```markdown
## $NEW_VERSION ($DATE)

- commit message 1
- commit message 2
...
```

### 3. Update pubspec.yaml

Update the `version:` line in `booxchat_flutter/pubspec.yaml` to `$NEW_VERSION+$NEW_BUILD_NUMBER`.

### 4. Build APK

```bash
cd /Users/kass/dev/BooxDrop/booxchat_flutter
flutter build apk --release \
  --dart-define=APP_VERSION=$NEW_VERSION \
  --dart-define=BUILD_DATE=$(date +%Y-%m-%d)
```

Verify build succeeds.

### 5. Commit and tag

```bash
git add booxchat_flutter/pubspec.yaml booxchat_flutter/CHANGELOG.md
git commit -m "Release Smarty Pants v$NEW_VERSION"
git tag flutter-v$NEW_VERSION
```

### 6. Install to device

Check for connected device:

```bash
adb devices
```

If a device is connected:

```bash
adb install -r booxchat_flutter/build/app/outputs/flutter-apk/app-release.apk
```

If no device found, print the APK path for manual install.

## Notes

- Working directory: `/Users/kass/dev/BooxDrop`
- Flutter app is in `booxchat_flutter/` subdirectory
- Tags use `flutter-v` prefix to distinguish from macOS BooxDrop releases
- APK is in `booxchat_flutter/build/app/outputs/flutter-apk/app-release.apk`
- Requires: Flutter SDK, Android SDK, adb, JAVA_HOME and ANDROID_SDK_ROOT env vars
