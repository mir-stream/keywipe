#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

# TCC remembers a code-signing requirement, not just the bundle identifier.
# An ad-hoc signature ties that requirement to one build's hash and leaves a
# stale Accessibility entry after an update. Require a certificate identity.
SIGNING_IDENTITY="${KEYWIPE_SIGNING_IDENTITY:-}"
if [[ -z "$SIGNING_IDENTITY" ]]; then
    DEVELOPMENT_IDENTITIES=()
    while IFS= read -r identity; do
        [[ -n "$identity" ]] && DEVELOPMENT_IDENTITIES+=("$identity")
    done < <(/usr/bin/security find-identity -v -p codesigning | awk '/"Apple Development: / { print $2 }')
    if [[ ${#DEVELOPMENT_IDENTITIES[@]} -ne 1 ]]; then
        printf '%s\n' 'Set KEYWIPE_SIGNING_IDENTITY to an Apple Development signing identity. Ad-hoc signing is disabled to preserve Accessibility permissions.' >&2
        exit 1
    fi
    SIGNING_IDENTITY="${DEVELOPMENT_IDENTITIES[0]}"
fi
if [[ "$SIGNING_IDENTITY" == "-" ]]; then
    printf '%s\n' 'Ad-hoc signing is not supported: use a certificate signing identity.' >&2
    exit 1
fi

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
APP_DIR="$PROJECT_DIR/dist/KeyWipe.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/KeyWipe" "$APP_DIR/Contents/MacOS/KeyWipe"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
cp LICENSE "$APP_DIR/Contents/Resources/LICENSE"
swift scripts/make-icon.swift "$PROJECT_DIR/.build/KeyWipe.iconset"
iconutil -c icns "$PROJECT_DIR/.build/KeyWipe.iconset" -o "$APP_DIR/Contents/Resources/KeyWipe.icns"
codesign --force --sign "$SIGNING_IDENTITY" --timestamp=none --identifier local.keywipe.app "$APP_DIR"
codesign --verify --strict "$APP_DIR"
printf 'Built: %s\n' "$APP_DIR"
