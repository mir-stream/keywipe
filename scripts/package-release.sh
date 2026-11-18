#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
SIGNING_IDENTITY="${KEYWIPE_RELEASE_SIGNING_IDENTITY:-}"
if [[ -z "$SIGNING_IDENTITY" ]]; then
    RELEASE_IDENTITIES=()
    while IFS= read -r identity; do
        [[ -n "$identity" ]] && RELEASE_IDENTITIES+=("$identity")
    done < <(/usr/bin/security find-identity -v -p codesigning | awk '/"Developer ID Application: / { print $2 }')
    if [[ ${#RELEASE_IDENTITIES[@]} -ne 1 ]]; then
        printf '%s\n' 'Set KEYWIPE_RELEASE_SIGNING_IDENTITY to a Developer ID Application identity.' >&2
        exit 1
    fi
    SIGNING_IDENTITY="${RELEASE_IDENTITIES[0]}"
fi
if [[ "$SIGNING_IDENTITY" == "-" ]]; then
    printf '%s\n' 'Distribution requires Developer ID signing, not an ad-hoc signature.' >&2
    exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
RELEASE_DIR="$PROJECT_DIR/dist/releases/v$VERSION"
APP_DIR="$RELEASE_DIR/KeyWipe.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

BINARIES=()
for architecture in arm64 x86_64; do
    BUILD_ARGS=(--configuration release --triple "$architecture-apple-macosx14.0"
        --scratch-path "$PROJECT_DIR/.build/release-$architecture" --product KeyWipe)
    swift build "${BUILD_ARGS[@]}"
    BIN_DIR="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
    BINARIES+=("$BIN_DIR/KeyWipe")
done
lipo -create "${BINARIES[@]}" -output "$APP_DIR/Contents/MacOS/KeyWipe"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
cp LICENSE "$APP_DIR/Contents/Resources/LICENSE"
swift scripts/make-icon.swift "$PROJECT_DIR/.build/KeyWipe-release.iconset"
iconutil -c icns "$PROJECT_DIR/.build/KeyWipe-release.iconset" -o "$APP_DIR/Contents/Resources/KeyWipe.icns"

codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp \
    --identifier local.keywipe.app "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"
SIGNATURE_INFO="$(codesign --display --verbose=2 "$APP_DIR" 2>&1)"
if ! printf '%s\n' "$SIGNATURE_INFO" | awk '/^Authority=Developer ID Application:/ { valid=1 } END { exit !valid }'; then
    printf '%s\n' 'The selected identity is not a Developer ID Application certificate.' >&2
    exit 1
fi
printf '%s\n' "$SIGNATURE_INFO" | awk '/Authority=|TeamIdentifier=|Timestamp=|flags=/'
lipo -archs "$APP_DIR/Contents/MacOS/KeyWipe"

# This archive is an input to notarization, not the public download. Staple the
# accepted app and repackage it before publishing a release.
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$RELEASE_DIR/KeyWipe-notary.zip"
printf 'Prepared for notarization: %s\n' "$RELEASE_DIR/KeyWipe-notary.zip"
