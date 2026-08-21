#!/usr/bin/env bash
#
# Build, sign with Developer ID, notarize, staple, and zip Timbre for
# distribution to any Mac — yours or a customer's.
#
# One-time setup (both steps are yours to do, they involve credentials):
#
#   1. Developer ID Application certificate:
#      Xcode › Settings › Accounts › S3793TJ443 › Manage Certificates…
#      › + › Developer ID Application. (Account Holder only.)
#
#   2. Notarization credentials, stored in the keychain under a profile name
#      this script expects:
#        xcrun notarytool store-credentials SpokeNotary \
#            --apple-id hi@hugopretorius.dev --team-id S3793TJ443
#      It prompts for an app-specific password — create one at
#      account.apple.com › Sign-In and Security › App-Specific Passwords.
#
# Why notarization at all: an un-notarized app is blocked by Gatekeeper on
# every Mac but the one that built it. This is the difference between "works
# here" and "installable anywhere".

set -euo pipefail
cd "$(dirname "$0")/.."

# ---- Preflight: fail with instructions, not mid-pipeline. -------------------

if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    echo "No Developer ID Application certificate in the keychain."
    echo "Create one: Xcode › Settings › Accounts › Manage Certificates… › +"
    exit 1
fi

if ! xcrun notarytool history --keychain-profile SpokeNotary >/dev/null 2>&1; then
    echo "No notarization profile 'SpokeNotary' in the keychain."
    echo "Store one (prompts for an app-specific password):"
    echo "  xcrun notarytool store-credentials SpokeNotary \\"
    echo "      --apple-id hi@hugopretorius.dev --team-id S3793TJ443"
    exit 1
fi

VERSION="$(sed -n 's/^MARKETING_VERSION = //p' apps/Timbre/Config/Shared.xcconfig)"
echo "Releasing Timbre $VERSION"

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
xcrun notarytool submit "$ZIP" --keychain-profile SpokeNotary --wait

# Staple the ticket so Gatekeeper trusts it offline, then re-zip the stapled app.
xcrun stapler staple "$APP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo
echo "Ready: $ZIP"
echo "Verify on another Mac: unzip, then  spctl -a -vv Timbre.app"
