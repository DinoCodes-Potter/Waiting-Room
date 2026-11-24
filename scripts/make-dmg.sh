#!/usr/bin/env bash
# Builds Waiting Room.app and a drag-to-install DMG. Run on a Mac.
#   scripts/make-dmg.sh 0.2
set -euo pipefail

VERSION="${1:?usage: scripts/make-dmg.sh <version>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

swift build -c release --arch arm64
BIN="$(swift build -c release --arch arm64 --show-bin-path)/WaitingRoom"

OUT="$ROOT/dist"
APP="$OUT/Waiting Room.app"
rm -rf "$OUT"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/WaitingRoom"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Resources/Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"

# Ad-hoc signature: enough for Apple silicon to run it. Not notarized.
codesign --force --deep --sign - "$APP"

STAGE="$OUT/dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Waiting Room" -srcfolder "$STAGE" -ov -format UDZO "$OUT/WaitingRoom-$VERSION.dmg"

echo "Built $OUT/WaitingRoom-$VERSION.dmg"
