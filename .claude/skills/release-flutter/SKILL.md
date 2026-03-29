---
name: release-flutter
description: Build, version bump, changelog, upload to OTA server, sign manifest. Supports all 4 Flutter apps.
argument-hint: <app> [patch|minor|major]
---

# Flutter App Release + OTA Publish

Bump version, build APK, upload to OTA server, sign manifest. No USB install — OTA is the delivery method.

## Usage

Parse `$ARGUMENTS`:

| Arg | Values | Default | Notes |
|-----|--------|---------|-------|
| app name | `booxchat`, `kazyka`, `booxchat_p2p`, `maze_race`, or `all` | **required** | Which app to release. `all` releases all 4. |
| bump type | `patch`, `minor`, `major` | `patch` | Which semver component to bump |

**App directory mapping:**

| appId | Directory | Tag prefix | Display name |
|-------|-----------|------------|-------------|
| `booxchat` | `booxchat_flutter/` | `booxchat-v` | Smarty Pants |
| `kazyka` | `kazyka_flutter/` | `kazyka-v` | Kazyka |
| `booxchat_p2p` | `booxchat_p2p/` | `booxchat_p2p-v` | Pixel Chat |
| `maze_race` | `maze_flutter/` | `maze_race-v` | Maze Race |

## Environment

Every flutter build command MUST be prefixed with:

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
export PATH="$JAVA_HOME/bin:$PATH"
export ANDROID_SDK_ROOT=/opt/homebrew/share/android-commandlinetools
```

## Steps (repeat for each app if `all`)

### 1. Determine new version

Read current version from `<APP_DIR>/pubspec.yaml` (`version: X.Y.Z+N`).

Bump semver component and increment build number by 1.

### 2. Generate changelog entry

```bash
git tag -l '<TAG_PREFIX>*' --sort=-v:refname | head -1
```

If no tag, use all commits. Get commits since tag for `<APP_DIR>/`. Prepend section to `<APP_DIR>/CHANGELOG.md`.

### 3. Update pubspec.yaml

Update `version:` line to `$NEW_VERSION+$NEW_BUILD_NUMBER`.

### 4. Build APK

```bash
cd /Users/kass/dev/BooxDrop/<APP_DIR>
flutter build apk --debug \
  --dart-define=APP_VERSION=$NEW_VERSION \
  --dart-define=BUILD_DATE=$(date +%Y-%m-%d)
```

APK: `<APP_DIR>/build/app/outputs/flutter-apk/app-debug.apk`

### 5. Compute SHA-256 + Upload APK

```bash
cd /Users/kass/dev/BooxDrop
SHA=$(shasum -a 256 <APP_DIR>/build/app/outputs/flutter-apk/app-debug.apk | awk '{print $1}')
scp <APP_DIR>/build/app/outputs/flutter-apk/app-debug.apk feesh9:/var/www/ota/<APPID>-<BUILD_NUMBER>.apk.tmp
ssh feesh9 "mv /var/www/ota/<APPID>-<BUILD_NUMBER>.apk.tmp /var/www/ota/<APPID>-<BUILD_NUMBER>.apk"
```

### 6. Update manifest.json on server using python3

IMPORTANT: Use python3 to read-modify-write the JSON. Do NOT manually construct the full JSON.

```bash
ssh feesh9 "python3 -c \"
import json, datetime
with open('/var/www/ota/manifest.json') as f:
    m = json.load(f)
m['<APPID>'] = {
    'versionName': '$NEW_VERSION',
    'versionCode': $NEW_BUILD_NUMBER,
    'url': 'https://ota.mos6581.cc/<APPID>-$NEW_BUILD_NUMBER.apk',
    'sha256': '$SHA',
    'publishedAt': datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
}
with open('/var/www/ota/manifest.json.tmp', 'w') as f:
    json.dump(m, f, indent=2)
\""
```

### 7. Sign manifest and swap atomically

```bash
ssh feesh9 "sudo openssl pkeyutl -sign -inkey /etc/ota/signing_key.pem -rawin \
  -in /var/www/ota/manifest.json.tmp \
  -out /var/www/ota/manifest.sig.tmp && \
  mv /var/www/ota/manifest.json.tmp /var/www/ota/manifest.json && \
  mv /var/www/ota/manifest.sig.tmp /var/www/ota/manifest.sig"
```

### 8. Verify OTA

```bash
curl -s https://ota.mos6581.cc/manifest.json | python3 -m json.tool
```

Confirm the app entry has the correct versionCode, sha256, and URL.

### 9. Report

Print summary: app name, old version → new version, OTA URL.

Do NOT commit or tag — user will commit when ready.

## Notes

- Working directory: `/Users/kass/dev/BooxDrop`
- Do NOT delete previous APKs from the server (rollback)
- Do NOT commit or push — user controls git
- Do NOT install via USB — OTA is the delivery method
- OTA signing key: `/etc/ota/signing_key.pem` on feesh9
- Requires: Flutter SDK, Android SDK, JAVA_HOME and ANDROID_SDK_ROOT env vars
