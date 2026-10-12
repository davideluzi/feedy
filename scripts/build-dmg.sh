#!/bin/bash
# Builds a universal Release of Feedy, ad-hoc signed (no Apple Developer
# account needed), and packages it as build/Feedy-<version>.dmg.
#
# The app is not notarized: on first launch users must allow it in
# System Settings → Privacy & Security → "Open Anyway".
#
# Hardened runtime is disabled: its library validation rejects the embedded
# SwiftSoup.framework when nothing has a Team ID (ad-hoc signing), so the app
# would crash at launch. It's only required for notarization anyway.
#
# Usage: scripts/build-dmg.sh   (from anywhere inside the repo)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$REPO_ROOT/build"
DERIVED_DATA="$BUILD_DIR/DerivedData"
STAGING="$BUILD_DIR/dmg-staging"

cd "$REPO_ROOT/Feedy"

VERSION="$(xcodebuild -scheme Feedy -configuration Release -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/ MARKETING_VERSION /{print $2; exit}')"
DMG="$BUILD_DIR/Feedy-$VERSION.dmg"

echo "==> Building Feedy $VERSION (Release, universal, ad-hoc signed)"
rm -rf "$DERIVED_DATA" "$STAGING" "$DMG"
xcodebuild \
  -scheme Feedy \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM= \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  ENABLE_HARDENED_RUNTIME=NO \
  build -quiet

APP="$DERIVED_DATA/Build/Products/Release/Feedy.app"

echo "==> Verifying signature"
codesign --verify --deep --strict "$APP"
lipo -archs "$APP/Contents/MacOS/Feedy"

echo "==> Creating $DMG"
mkdir -p "$STAGING"
ditto "$APP" "$STAGING/Feedy.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create \
  -volname "Feedy $VERSION" \
  -srcfolder "$STAGING" \
  -fs HFS+ \
  -format UDZO \
  -ov \
  "$DMG" >/dev/null
rm -rf "$STAGING"

echo "==> Done: $DMG"
