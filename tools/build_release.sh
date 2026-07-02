#!/bin/bash
# Build, Developer ID-sign, notarize, and staple the menu bar app, producing a
# notarized ClaudeUsage.zip you can attach to a GitHub Release and reference from
# a Homebrew cask.
#
# This app can't ship on the Mac App Store (it shells out to `security` and reads
# another app's Keychain item, which the App Sandbox forbids), so Developer ID +
# notarization is the correct distribution path for a downloadable .app.
#
# Prereqs (one-time):
#   - A paid Apple Developer account and a "Developer ID Application" certificate
#     in your Keychain (Xcode > Settings > Accounts > Manage Certificates >
#     + > Developer ID Application).
#   - Notarization credentials: either a stored notarytool keychain profile, or an
#     App Store Connect API key (.p8).
#
# Usage (keychain profile):
#   xcrun notarytool store-credentials umfc-notary --key AuthKey_XXXX.p8 \
#       --key-id XXXX --issuer xxxxxxxx-...        # one-time
#   export DEVID_IDENTITY="Developer ID Application: Your Name (TEAMID)"
#   export NOTARY_PROFILE=umfc-notary
#   tools/build_release.sh
#
# Usage (API key directly):
#   export DEVID_IDENTITY="Developer ID Application: Your Name (TEAMID)"
#   export ASC_KEY_ID=... ASC_ISSUER_ID=... ASC_KEY_PATH=/path/AuthKey_*.p8
#   tools/build_release.sh
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

: "${DEVID_IDENTITY:?set DEVID_IDENTITY to your 'Developer ID Application: ...' identity}"

echo "==> Building app…"
./build.sh >/dev/null
APP="ClaudeUsage.app"

echo "==> Signing with hardened runtime…"
codesign --force --deep --options runtime --timestamp \
  --sign "$DEVID_IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

ZIP="ClaudeUsage.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Notarizing (this waits for Apple)…"
if [ -n "${NOTARY_PROFILE:-}" ]; then
  xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
else
  : "${ASC_KEY_ID:?set ASC_KEY_ID or NOTARY_PROFILE}"
  : "${ASC_ISSUER_ID:?set ASC_ISSUER_ID}"
  : "${ASC_KEY_PATH:?set ASC_KEY_PATH}"
  KEYDIR="$HOME/.appstoreconnect/private_keys"; mkdir -p "$KEYDIR"
  CLEAN_KEY="$KEYDIR/AuthKey_${ASC_KEY_ID}.p8"; cp "$ASC_KEY_PATH" "$CLEAN_KEY"
  xcrun notarytool submit "$ZIP" \
    --key "$CLEAN_KEY" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID" --wait
fi

echo "==> Stapling…"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Done: $REPO/$ZIP (notarized + stapled)"
echo "    sha256 (for the Homebrew cask):"
shasum -a 256 "$ZIP"
