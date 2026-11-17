#!/bin/bash
# Builds "Desktop Peeler.app" from the sources in this folder. Run:  bash build.sh
set -euo pipefail
cd "$(dirname "$0")"

if ! xcrun --find swiftc >/dev/null 2>&1; then
    echo "The Swift compiler was not found. Install Xcode, or run: xcode-select --install"
    exit 1
fi

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
