#!/bin/bash
# Builds "Desktop Peeler.app" from the sources in this folder. Run:  bash build.sh
set -euo pipefail
cd "$(dirname "$0")"

if ! xcrun --find swiftc >/dev/null 2>&1; then
    echo "The Swift compiler was not found. Install Xcode, or run: xcode-select --install"
    exit 1
fi

# Every build gets the next build number (kept in Info.plist, shown in the About window and
# in the disk image name). The version itself (CFBundleShortVersionString) is raised by hand.
# Every build must be described in RELEASE_NOTES.md first.
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Info.plist)"
BUILD=$(( $(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' Info.plist) + 1 ))
if ! grep -qxF "## $VERSION (build $BUILD)" RELEASE_NOTES.md; then
    echo "RELEASE_NOTES.md has no entry '## $VERSION (build $BUILD)'. Describe this build there first, then run the build again."
    exit 1
fi
/usr/libexec/PlistBuddy -c "Set CFBundleVersion $BUILD" Info.plist
echo "Version $VERSION (build $BUILD)"

APP="build/Desktop Peeler.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Fonts" "$APP/Contents/Resources/Languages" build/arch

# Universal app: one build for Intel (x86_64) and one for Apple chips (arm64), joined with lipo.
for ARCH in x86_64 arm64; do
    echo "Compiling for $ARCH (takes about a minute)..."
    xcrun swiftc -O -swift-version 5 -parse-as-library \
        -target "${ARCH}-apple-macos12.0" \
        Sources/*.swift \
        -o "build/arch/DesktopPeeler-$ARCH"
done
lipo -create build/arch/DesktopPeeler-x86_64 build/arch/DesktopPeeler-arm64 -output "$APP/Contents/MacOS/DesktopPeeler"

cp Info.plist "$APP/Contents/Info.plist"
cp Resources/Fonts/*.ttf Resources/Fonts/*-OFL.txt "$APP/Contents/Resources/Fonts/"
cp Resources/Languages/*.json "$APP/Contents/Resources/Languages/"
iconutil -c icns Resources/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

codesign --force --sign - "$APP"
touch "$APP"

echo "Done: $(pwd)/$APP"
[ -n "${NO_REVEAL:-}" ] || open -R "$APP"
