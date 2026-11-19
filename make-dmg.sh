#!/bin/bash
# Builds the app and packs it into a disk image for installing: bash make-dmg.sh
# The user opens the .dmg and drags Desktop Peeler onto the Applications shortcut.
set -euo pipefail
cd "$(dirname "$0")"

NO_REVEAL=1 bash build.sh

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Info.plist)"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' Info.plist)"
STAGE="build/dmg"
DMG="build/DesktopPeeler-$VERSION-build$BUILD.dmg"

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
ditto "build/Desktop Peeler.app" "$STAGE/Desktop Peeler.app"
ln -s /Applications "$STAGE/Applications"

echo "Creating disk image..."
hdiutil create -quiet -volname "Desktop Peeler $VERSION (build $BUILD)" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG"
rm -rf "$STAGE"

echo "Done: $(pwd)/$DMG"
open -R "$DMG"
