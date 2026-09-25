#!/usr/bin/env bash
#
# Build, sign with Developer ID, notarize, staple, and zip Timbre for
# distribution to any Mac — yours or a customer's.
#
# One-time setup (both steps are yours to do, they involve credentials):
#
#   1. Developer ID Application certificate for the team below:
#      Xcode › Settings › Accounts › (your Apple ID) › team WX9L5M4Y9Q ›
#      Manage Certificates… › + › Developer ID Application. Xcode makes the
#      signing request and installs the certificate; no CSR by hand.
#      (Account Holder only.)
#
#   2. Notarization credentials, stored in the keychain under a profile name
#      this script expects:
#        xcrun notarytool store-credentials TimbreNotary \
#            --apple-id <your Apple ID email> --team-id WX9L5M4Y9Q
#      It prompts for an app-specific password — create one at
#      account.apple.com › Sign-In and Security › App-Specific Passwords.
#
# Team history: S3793TJ443 was the previous individual membership; its
# certificate may still sit in the keychain and must not be used. The
# preflight checks for the team, not just the certificate type.
#
# Why notarization at all: an un-notarized app is blocked by Gatekeeper on
# every Mac but the one that built it. This is the difference between "works
# here" and "installable anywhere".

set -euo pipefail
cd "$(dirname "$0")/.."

# ---- Preflight: fail with instructions, not mid-pipeline. -------------------
TEAM="WX9L5M4Y9Q"
if ! security find-identity -v -p codesigning | grep -q "Developer ID Application: .*($TEAM)"; then
    echo "No Developer ID Application certificate for team $TEAM in the keychain."
    echo "Create one: Xcode › Settings › Accounts › team $TEAM › Manage Certificates… › +"
    exit 1
fi
if ! xcrun notarytool history --keychain-profile TimbreNotary >/dev/null 2>&1; then
    echo "No notarization profile 'TimbreNotary' in the keychain."
    echo "Store one (prompts for an app-specific password):"
    echo "  xcrun notarytool store-credentials TimbreNotary \\"
    echo "      --apple-id <your Apple ID email> --team-id $TEAM"
    exit 1
fi

VERSION="$(sed -n 's/^MARKETING_VERSION = //p' apps/Timbre/Config/Shared.xcconfig)"
echo "Releasing Timbre $VERSION"

# Release notes come from the changelog, so the app and the repo can never
# disagree about what a version contains. No section, no release.
if ! grep -q "^## \[$VERSION\]" CHANGELOG.md; then
    echo "CHANGELOG.md has no section for $VERSION. Write one first:  ## [$VERSION] — $(date +%F)"
    exit 1
fi

# ---- Archive and export with Developer ID. ----------------------------------

rm -rf build/Timbre.xcarchive build/export
xcodebuild -project apps/Timbre/Timbre.xcodeproj -scheme Timbre \
    -configuration Release archive -archivePath build/Timbre.xcarchive \
    | grep -E '^\*\* ARCHIVE|error:' || true
[ -d build/Timbre.xcarchive ] || { echo "Archive failed"; exit 1; }

xcodebuild -exportArchive -archivePath build/Timbre.xcarchive \
    -exportOptionsPlist tools/ExportOptions.plist -exportPath build/export \
    | grep -E 'EXPORT|error:' || true
APP="build/export/Timbre.app"
[ -d "$APP" ] || { echo "Export failed"; exit 1; }

# ---- Notarize and staple. ----------------------------------------------------

ZIP="build/Timbre-$VERSION.zip"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "Submitting to Apple's notary service (typically 1–5 minutes)…"
xcrun notarytool submit "$ZIP" --keychain-profile TimbreNotary --wait

# Staple the ticket so Gatekeeper trusts it offline, then re-zip the stapled app.
xcrun stapler staple "$APP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

# ---- Disk image: the download page's format (GDR-0013 keeps the zip for updates).
DMG="build/Timbre-$VERSION.dmg"
tools/make-dmg.sh "$APP" "$DMG" "Timbre" >/dev/null
codesign --sign "Developer ID Application: Hugo Pretorius ($TEAM)" --timestamp "$DMG"
echo "Notarizing the disk image…"
xcrun notarytool submit "$DMG" --keychain-profile TimbreNotary --wait | grep -E 'status:' | tail -1
xcrun stapler staple "$DMG" | tail -1

# ---- Files for the website: the version file, the zip and the image (GDR-0013).
# The update check fetches web/static/appcast.json from the site, and the zip
# it names is served from the same host. Publishing a release is committing
# these two files on a release branch and merging it: the deploy is the release.
BUILD="$(sed -n 's/^CURRENT_PROJECT_VERSION = //p' apps/Timbre/Config/Shared.xcconfig)"
mkdir -p web/static/releases
find web/static/releases \( -name 'Timbre-*.zip' -o -name 'Timbre-*.dmg' \) ! -name "Timbre-$VERSION.*" -delete
cp "$ZIP" "web/static/releases/Timbre-$VERSION.zip"
cp "$DMG" "web/static/releases/Timbre-$VERSION.dmg"
python3 - "$VERSION" "$BUILD" "$ZIP" > web/static/appcast.json <<'PY'
import datetime, hashlib, json, os, re, sys
version, build, zip_path = sys.argv[1], int(sys.argv[2]), sys.argv[3]

section = re.search(rf"^## \[{re.escape(version)}\][^\n]*\n(.*?)(?=^## |\Z)",
                    open("CHANGELOG.md").read(), re.S | re.M).group(1)
lines, current = [], None
for raw in section.splitlines():
    line = raw.strip()
    if line.startswith("### "):
        lines.append(f"\n{line[4:]}:")
    elif line.startswith("- "):
        current = "• " + line[2:]
        lines.append(current)
    elif line and lines:
        lines[-1] += " " + line
notes = re.sub(r"[*`]", "", "\n".join(lines)).strip()

data = open(zip_path, "rb").read()
print(json.dumps({"latest": {
    "version": version,
    "build": build,
    "minimumSystemVersion": "26.0",
    "url": f"https://timbre.hugopretorius.dev/releases/Timbre-{version}.zip",
    "dmgURL": f"https://timbre.hugopretorius.dev/releases/Timbre-{version}.dmg",
    "sha256": hashlib.sha256(data).hexdigest(),
    "size": len(data),
    "published": datetime.date.today().isoformat(),
    "notes": notes,
}}, indent=2, ensure_ascii=False))
PY

echo
echo "Ready: $ZIP and $DMG"
echo "Site files: web/static/appcast.json, web/static/releases/Timbre-$VERSION.zip and .dmg"
echo "Check them before publishing:"
echo "  (cd packages/TimbreKit && swift run timbre-eval --verify-update ../../web/static/appcast.json)"
echo "  — that reads the zip from the site, so run it against a file:// copy first; see CLAUDE.md."
echo "Publish: commit both on a release branch, open a PR, merge. The deploy is the release."
