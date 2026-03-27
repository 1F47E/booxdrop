---
name: release-flutter
description: Build, version bump, changelog, and install Smarty Pants Flutter APK to connected Boox device
argument-hint: <app> [patch|minor|major]
---

# Flutter App Release + OTA Publish

Bump version, generate changelog from git commits, build APK, upload to OTA server, sign manifest, and optionally install to connected device.

## Usage

Parse `$ARGUMENTS`:

| Arg | Values | Default | Notes |
|-----|--------|---------|-------|
| app name | `booxchat`, `kazyka`, `booxchat_p2p`, `maze_race` | **required** | Which app to release |
| bump type | `patch`, `minor`, `major` | `patch` | Which semver component to bump |

**App directory mapping:**

| appId | Directory | Tag prefix |
|-------|-----------|------------|
| `booxchat` | `booxchat_flutter/` | `booxchat-v` |
| `kazyka` | `kazyka_flutter/` | `kazyka-v` |
| `booxchat_p2p` | `booxchat_p2p/` | `booxchat_p2p-v` |
| `maze_race` | `maze_flutter/` | `maze_race-v` |

## Environment

Every flutter build/run/install command MUST be prefixed with:

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
export PATH="$JAVA_HOME/bin:$PATH"
export ANDROID_SDK_ROOT=/opt/homebrew/share/android-commandlinetools
```

## Steps

### 1. Determine new version

Read current version from `<APP_DIR>/pubspec.yaml` (the `version:` line, format `X.Y.Z+N`).

Bump according to the argument:
- `patch`: `1.0.0` → `1.0.1`
- `minor`: `1.0.0` → `1.1.0`
- `major`: `1.0.0` → `2.0.0`

Also increment the build number (`+N`) by 1.

### 2. Generate changelog entry

Get the last git tag matching `<TAG_PREFIX>*`:

```bash
git tag -l '<TAG_PREFIX>*' --sort=-v:refname | head -1
```

If no tag exists, use the first commit. Get commits since that tag:

```bash
git log $LAST_TAG..HEAD --oneline -- <APP_DIR>/
```

Prepend a new section to `<APP_DIR>/CHANGELOG.md` (create if it doesn't exist):

```markdown
## $NEW_VERSION ($DATE)

- commit message 1
- commit message 2
...
```

### 3. Update pubspec.yaml

Update the `version:` line in `<APP_DIR>/pubspec.yaml` to `$NEW_VERSION+$NEW_BUILD_NUMBER`.

### 4. Build APK

```bash
cd /Users/kass/dev/BooxDrop/<APP_DIR>
flutter build apk --debug \
  --dart-define=APP_VERSION=$NEW_VERSION \
  --dart-define=BUILD_DATE=$(date +%Y-%m-%d)
```

NOTE: Use `--debug` (no signing key configured). The APK path will be:
`<APP_DIR>/build/app/outputs/flutter-apk/app-debug.apk`

Verify build succeeds.

### 5. Compute SHA-256

```bash
shasum -a 256 <APP_DIR>/build/app/outputs/flutter-apk/app-debug.apk | awk '{print $1}'
```

### 6. Upload APK to OTA server

Upload to a temp path first, then rename atomically:

```bash
scp <APP_DIR>/build/app/outputs/flutter-apk/app-debug.apk feesh9:/var/www/ota/<APPID>-<BUILD_NUMBER>.apk.tmp
ssh feesh9 "mv /var/www/ota/<APPID>-<BUILD_NUMBER>.apk.tmp /var/www/ota/<APPID>-<BUILD_NUMBER>.apk"
```

### 7. Update manifest.json on server

Read the current manifest, update the entry for this app:

```bash
ssh feesh9 "cat /var/www/ota/manifest.json"
```

Update the app's entry with:
- `versionName`: the new version string
- `versionCode`: the new build number
- `url`: `https://ota.mos6581.cc/<APPID>-<BUILD_NUMBER>.apk`
- `sha256`: the computed SHA-256 from step 5
- `publishedAt`: current UTC timestamp in ISO 8601

Write the updated manifest back:

```bash
ssh feesh9 "cat > /var/www/ota/manifest.json.tmp << 'EOF'
<UPDATED_JSON>
EOF
"
```

### 8. Sign manifest and swap atomically

```bash
ssh feesh9 "sudo openssl pkeyutl -sign -inkey /etc/ota/signing_key.pem -rawin \
  -in /var/www/ota/manifest.json.tmp \
  -out /var/www/ota/manifest.sig.tmp && \
  mv /var/www/ota/manifest.json.tmp /var/www/ota/manifest.json && \
  mv /var/www/ota/manifest.sig.tmp /var/www/ota/manifest.sig"
```

### 9. Commit and tag

```bash
git add <APP_DIR>/pubspec.yaml <APP_DIR>/CHANGELOG.md
git commit -m "Release <APP_NAME> v$NEW_VERSION"
git tag <TAG_PREFIX>$NEW_VERSION
```

### 10. Install to device (optional)

Check for connected device:

```bash
adb devices
```

If a device is connected:

```bash
flutter install -d <DEVICE_ID> --use-application-binary=<APP_DIR>/build/app/outputs/flutter-apk/app-debug.apk
```

If no device found, print the APK path for manual install.

### 11. Verify OTA

```bash
curl -s https://ota.mos6581.cc/manifest.json | python3 -m json.tool
```

Confirm the app entry has the correct versionCode, sha256, and URL.

## Notes

- Working directory: `/Users/kass/dev/BooxDrop`
- Tags use app-specific prefixes to distinguish releases
- Do NOT delete previous APKs from the server (rollback)
- Requires: Flutter SDK, Android SDK, adb, JAVA_HOME and ANDROID_SDK_ROOT env vars
- OTA signing key: `/etc/ota/signing_key.pem` on feesh9
