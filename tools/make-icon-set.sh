#!/bin/bash
# Renders the app icon and fills the asset catalogue with every size macOS
# asks for. Run after changing tools/app-icon.swift or the palette.
#
#   tools/make-icon-set.sh [variant]      (default: charcoal)
set -euo pipefail
cd "$(dirname "$0")/.."
VARIANT="${1:-charcoal}"
SET="apps/Timbre/Sources/Assets.xcassets/AppIcon.appiconset"
mkdir -p "$SET"
swift tools/app-icon.swift "$VARIANT" "$SET/icon_1024.png" 1024 >/dev/null
for px in 16 32 64 128 256 512; do
  sips -z "$px" "$px" "$SET/icon_1024.png" --out "$SET/icon_$px.png" >/dev/null
done
cat > "$SET/Contents.json" <<'JSON'
{
  "images" : [
    { "filename" : "icon_16.png",   "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_32.png",   "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32.png",   "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_64.png",   "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128.png",  "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_256.png",  "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256.png",  "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_512.png",  "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512.png",  "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_1024.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON
echo "icon set ($VARIANT) → $SET"
