#!/bin/bash
#
# Builds macos-dockwake.app and packages it for a GitHub Release.
#
# Output in build/:
#   macos-dockwake.app             the app (Apple silicon and Intel)
#   macos-dockwake-<version>.dmg   disk image with an install arrow and first-launch steps
#   macos-dockwake-<version>.zip   zip of the app
#
# Usage:
#   scripts/build-app.sh
#   VERSION=1.2.0 scripts/build-app.sh
#
# The version defaults to the latest git tag (v1.2.0 becomes 1.2.0).
# The app is ad-hoc signed, not signed with an Apple Developer ID, so macOS
# asks people to approve it once in System Settings > Privacy & Security.
# Requires Xcode or the Xcode Command Line Tools, Python 3, and internet access
# to install dmgbuild.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NAME="macos-dockwake"
VERSION="${VERSION:-$(git -C "$ROOT" describe --tags --abbrev=0 2>/dev/null || true)}"
VERSION="${VERSION#v}"
VERSION="${VERSION:-0.0.0}"
MIN_MACOS="13.0"
DMGBUILD_VERSION="1.6.7"

BUILD="$ROOT/build"
WORK="$BUILD/work"
APP="$BUILD/$NAME.app"
DMG="$BUILD/$NAME-$VERSION.dmg"
ZIP="$BUILD/$NAME-$VERSION.zip"

# Extra compiler flags, for example a module cache path in a sandbox.
read -r -a EXTRA_FLAGS <<< "${SWIFTC_FLAGS:-}"

echo "Building $NAME $VERSION..."
rm -rf "$BUILD"
mkdir -p "$WORK" "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Compile once per chip type, then join them into one universal program.
for arch in arm64 x86_64; do
  xcrun swiftc -O -swift-version 5 -target "$arch-apple-macos$MIN_MACOS" \
    ${EXTRA_FLAGS[@]+"${EXTRA_FLAGS[@]}"} \
    "$ROOT"/app/Sources/*.swift -o "$WORK/$NAME-$arch"
done
lipo -create "$WORK/$NAME-arm64" "$WORK/$NAME-x86_64" -output "$APP/Contents/MacOS/$NAME"

sed "s/__VERSION__/$VERSION/g" "$ROOT/app/Info.plist" > "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist" >/dev/null

echo "Drawing the icon..."
xcrun swiftc -O -swift-version 5 ${EXTRA_FLAGS[@]+"${EXTRA_FLAGS[@]}"} \
  "$ROOT/app/make-icon.swift" -o "$WORK/make-icon"
"$WORK/make-icon" "$WORK/icon-1024.png"
ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$WORK/icon-1024.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$WORK/icon-1024.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

echo "Signing (ad hoc)..."
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --strict "$APP"

echo "Packaging..."
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

# The disk image window shows a background with an arrow to Applications and
# the steps for opening the app the first time. dmgbuild lays the window out
# without scripting Finder, so it also works on GitHub's build machines.
echo "Drawing the disk image background..."
xcrun swiftc -O -swift-version 5 ${EXTRA_FLAGS[@]+"${EXTRA_FLAGS[@]}"} \
  "$ROOT/app/make-dmg-background.swift" -o "$WORK/make-dmg-background"
"$WORK/make-dmg-background" "$WORK/dmg-background.png" 1
"$WORK/make-dmg-background" "$WORK/dmg-background@2x.png" 2
tiffutil -cathidpicheck "$WORK/dmg-background.png" "$WORK/dmg-background@2x.png" \
  -out "$WORK/dmg-background.tiff" 2>/dev/null

echo "Installing dmgbuild..."
python3 -m venv "$WORK/venv"
"$WORK/venv/bin/pip" install --quiet --disable-pip-version-check "dmgbuild==$DMGBUILD_VERSION"

"$WORK/venv/bin/dmgbuild" -s "$ROOT/app/dmg-settings.py" \
  -D app="$APP" \
  -D background="$WORK/dmg-background.tiff" \
  -D icon="$APP/Contents/Resources/AppIcon.icns" \
  "$NAME $VERSION" "$DMG" >/dev/null

rm -rf "$WORK"
echo
echo "Built:"
ls -lh "$DMG" "$ZIP" | awk '{print "  " $5 "  " $NF}'
echo "  $APP"
