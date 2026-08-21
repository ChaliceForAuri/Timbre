#!/usr/bin/env bash
#
# Build Timbre (Release) and install it to /Applications.
#
# This is the daily-driver loop: run it after merging a change and you're
# dictating with the new build seconds later. Release matters — Debug is
# compiled -Onone, which is several times slower in exactly the hot paths
# (audio RMS, buffer conversion, SwiftUI diffing).
#
# The Accessibility and Microphone grants carry over from the Xcode build:
# TCC keys on the designated requirement (bundle id + signing cert), and both
# builds share dev.hugopretorius.Timbre and the same development certificate.

set -euo pipefail
cd "$(dirname "$0")/.."

echo "Building Release…"
xcodebuild -project apps/Timbre/Timbre.xcodeproj -scheme Timbre \
    -configuration Release -destination 'platform=macOS' \
    -derivedDataPath build/DerivedData build | grep -E '^\*\* BUILD|error:' || true

APP="build/DerivedData/Build/Products/Release/Timbre.app"
[ -d "$APP" ] || { echo "Build failed — no app at $APP"; exit 1; }

echo "Installing to /Applications…"
osascript -e 'quit app "Timbre"' 2>/dev/null || true
sleep 1
rm -rf /Applications/Timbre.app
ditto "$APP" /Applications/Timbre.app

open /Applications/Timbre.app
echo "Done. $(codesign -dv /Applications/Timbre.app 2>&1 | grep TeamIdentifier)"
