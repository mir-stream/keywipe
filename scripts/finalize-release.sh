#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
RELEASE_DIR="$PROJECT_DIR/dist/releases/v$VERSION"
APP_DIR="$RELEASE_DIR/KeyWipe.app"

# Fail rather than label an unnotarized archive as the finished download.
xcrun stapler staple "$APP_DIR"
xcrun stapler validate "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"
spctl --assess --type execute --verbose=2 "$APP_DIR"

ARCHIVE="KeyWipe-macOS-universal.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$RELEASE_DIR/$ARCHIVE"
cd "$RELEASE_DIR"
shasum -a 256 "$ARCHIVE" > SHA256SUMS.txt
printf 'Ready to publish: %s\n' "$RELEASE_DIR/$ARCHIVE"
