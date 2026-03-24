---
name: release
description: Build, package, and release BooxDrop to GitHub with DMG and Homebrew formula update
argument-hint: <version> [--skip-build] [--skip-brew]
---

# BooxDrop Release

Build the app, create a DMG, push to GitHub, create a release, and update Homebrew formula.

## Usage

Parse `$ARGUMENTS`:

| Flag | Values | Default | Notes |
|------|--------|---------|-------|
| version | semver (e.g. `1.2.0`) | **required** | New version number |
| `--skip-build` | flag | off | Skip build, use existing build/ |
| `--skip-brew` | flag | off | Skip Homebrew formula update |

## Steps

### 1. Bump version in project

Update `MARKETING_VERSION` in `BooxDrop.xcodeproj/project.pbxproj` (all occurrences) to the new version.

### 2. Build Release

```bash
cd /Users/kass/dev/books/BooxDrop
rm -rf build
xcodebuild -project BooxDrop.xcodeproj -scheme BooxDrop -configuration Release -derivedDataPath build 2>&1 | tail -5
```

Verify `** BUILD SUCCEEDED **` in output.

### 3. Create DMG

```bash
hdiutil create -volname "BooxDrop" -srcfolder build/Build/Products/Release/BooxDrop.app -ov -format UDZO BooxDrop-$VERSION.dmg
```

### 4. Install to /Applications

```bash
cp -R build/Build/Products/Release/BooxDrop.app /Applications/BooxDrop.app
```

### 5. Update Homebrew formula

Update `version` in `Formula/booxdrop.rb` to the new version.

### 6. Commit and push

```bash
git add BooxDrop.xcodeproj/project.pbxproj Formula/booxdrop.rb
# Also add any other changed files (icons, code, etc.)
git commit -m "Release v$VERSION"
git push origin main
```

### 7. Create GitHub release

```bash
gh release create v$VERSION BooxDrop-$VERSION.dmg -R 1F47E/booxdrop \
  --title "BooxDrop v$VERSION" \
  --notes "## Install

### Homebrew (CLI)
\`\`\`bash
brew install 1F47E/tap/booxdrop
\`\`\`

### GUI
Download \`BooxDrop-$VERSION.dmg\` below."
```

Add release notes describing what changed (check git log since last tag).

### 8. Verify

```bash
gh release view v$VERSION -R 1F47E/booxdrop
```

## Notes

- Repo: `git@github-1f47e:1F47E/booxdrop.git`
- Requires: Xcode 15+, libmtp (homebrew), gh CLI
- The DMG is gitignored — only uploaded as a release asset
- Build artifacts in `build/` are gitignored
