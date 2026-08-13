#!/usr/bin/env bash
# Check / prepare Developer ID + notary tooling on this Mac.
# Login to iCloud alone is NOT enough — need Apple Developer Program + Developer ID cert.
set -euo pipefail

echo "=== 1) Prefer full Xcode (not Command Line Tools only) ==="
if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  echo "DEVELOPER_DIR=$DEVELOPER_DIR"
  xcodebuild -version
  xcrun notarytool --help >/dev/null && echo "notarytool: OK"
else
  echo "error: /Applications/Xcode.app not found" >&2
  exit 1
fi

echo ""
echo "=== 2) Code signing identities ==="
security find-identity -v -p codesigning || true
if security find-identity -v -p codesigning 2>/dev/null | grep -q "Developer ID Application"; then
  echo "OK: Developer ID Application present"
  security find-identity -v -p codesigning | grep "Developer ID Application"
else
  echo "MISSING: Developer ID Application"
  echo ""
  echo "Signing in to iCloud on this Mac does NOT create this cert."
  echo "You need:"
  echo "  1) Enroll https://developer.apple.com/programs/  (~\$99/year)"
  echo "  2) Xcode → Settings → Accounts → select team → Manage Certificates"
  echo "     → + → Developer ID Application"
  echo "  OR create at https://developer.apple.com/account/resources/certificates/list"
  echo "  3) Re-run this script"
  echo ""
  echo "Optional: open Xcode accounts UI now"
  open "xcode://settings/accounts" 2>/dev/null || open -a Xcode
  exit 2
fi

echo ""
echo "=== 3) Notary credentials (keychain profile) ==="
PROFILE="${NOTARY_PROFILE:-AC_NOTARY}"
if xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
  echo "OK: notary profile '$PROFILE' works"
else
  echo "MISSING: notary keychain profile '$PROFILE'"
  echo ""
  echo "Create App-Specific Password: https://appleid.apple.com → Sign-In and Security"
  echo "Then run (interactive — you type password):"
  echo ""
  echo "  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer"
  echo "  xcrun notarytool store-credentials \"$PROFILE\" \\"
  echo "    --apple-id \"YOUR_APPLE_ID@email.com\" \\"
  echo "    --team-id \"YOUR_TEAM_ID\" \\"
  echo "    --password \"app-specific-password\""
  echo ""
  echo "Find Team ID: https://developer.apple.com/account → Membership"
  exit 3
fi

echo ""
echo "=== Ready to ship notarized DMG ==="
echo "  cd apps/macos-v2 && ./scripts/build-app.sh"
echo "  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer"
echo "  export CODESIGN_IDENTITY=\"Developer ID Application: …\""
echo "  export NOTARY_PROFILE=$PROFILE"
echo "  ./scripts/make-dmg.sh"
