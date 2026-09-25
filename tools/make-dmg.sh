#!/usr/bin/env bash
#
# Wraps a built Timbre.app in a disk image with an Applications drop target:
# the install is "drag it across", which is what people expect from a Mac
# download. The zip stays the update format (ADR-0010); this is the download
# page's format.
#
# Usage: tools/make-dmg.sh <Timbre.app> <output.dmg> [volume name]
#
# The window layout (icon positions, background) is set by Finder through
# AppleScript, which needs a logged-in session; on a headless machine the
# image still builds, just without the layout.
set -euo pipefail

APP="$1"; OUT="$2"; VOLNAME="${3:-Timbre}"
[ -d "$APP" ] || { echo "no app at $APP"; exit 1; }
WORK="$(mktemp -d)"; STAGE="$WORK/stage"; RW="$WORK/rw.dmg"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$STAGE/.background"
ditto "$APP" "$STAGE/Timbre.app"
ln -s /Applications "$STAGE/Applications"
swift "$(dirname "$0")/dmg-background.swift" "$STAGE/.background/background.png"

hdiutil create -quiet -srcfolder "$STAGE" -volname "$VOLNAME" -fs HFS+ -format UDRW -size 40m "$RW"
MOUNT="$(hdiutil attach -readwrite -noverify -noautoopen -plist "$RW" | plutil -extract 'system-entities' json -o - - | python3 -c 'import json,sys; print(next(e["mount-point"] for e in json.load(sys.stdin) if e.get("mount-point")))')"
[ -n "$MOUNT" ] || { echo "mount failed"; exit 1; }
# Finder addresses the disk by its mounted name — which is "Timbre 1" if a
# stale "Timbre" is still mounted somewhere. Use the name macOS gave it.
DISK="$(basename "$MOUNT")"

# Finder lays the window out: icon view, background, two icons side by side.
osascript <<APPLESCRIPT || echo "(Finder layout skipped)"
tell application "Finder"
    tell disk "$DISK"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 860, 520}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set text size of viewOptions to 14
        set background picture of viewOptions to file ".background:background.png"
        set position of item "Timbre.app" of container window to {180, 190}
        set position of item "Applications" of container window to {480, 190}
        close
        open
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT
sync
[ -f "$MOUNT/.DS_Store" ] && echo "layout saved" || echo "(no .DS_Store: Finder did not save the layout)"
hdiutil detach -quiet "$MOUNT"
rm -f "$OUT"
hdiutil convert -quiet "$RW" -format UDZO -imagekey zlib-level=9 -o "$OUT"
echo "$OUT"
