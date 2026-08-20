#!/bin/zsh

set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
CONFIGURATION="${CONFIGURATION:-release}"
VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
OUTPUT_DIR="$PROJECT_DIR/.build/app"
APP_BUNDLE="$OUTPUT_DIR/MousePortal.app"

cd "$PROJECT_DIR"
if [[ -n "${MOUSEPORTAL_BINARY:-}" ]]; then
    BINARY_PATH="$MOUSEPORTAL_BINARY"
else
    swift build -c "$CONFIGURATION" --product MousePortal
    BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"
    BINARY_PATH="$BIN_DIR/MousePortal"
fi

if [[ ! -x "$BINARY_PATH" ]]; then
    echo "MousePortal executable not found: $BINARY_PATH" >&2
    exit 1
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BINARY_PATH" "$APP_BUNDLE/Contents/MacOS/MousePortal"
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$PROJECT_DIR/Resources/MousePortal.icns" "$APP_BUNDLE/Contents/Resources/MousePortal.icns"

plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP_BUNDLE/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$APP_BUNDLE/Contents/Info.plist"

if [[ "${SKIP_ADHOC_SIGNING:-0}" != "1" ]]; then
    codesign --force --deep --sign - "$APP_BUNDLE"
fi

echo "$APP_BUNDLE"
