#!/usr/bin/env bash
# Pack Noi.app into a standard macOS DMG:
#   open DMG → drag app to Applications → eject → open from Applications
#
# Optional notarize (requires Developer ID + notarytool keychain profile):
#   NOTARY_PROFILE=AC_NOTARY ./scripts/make-dmg.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${APP_PATH:-/Applications/Noi.app}"
VERSION="${SHIP_VERSION:-1.0.3}"
OUT_DIR="${OUT_DIR:-$ROOT/site/downloads}"
VOL_NAME="Nói"
DMG_NAME="Noi-${VERSION}.dmg"
if [[ -z "${CODESIGN_IDENTITY:-}" && -f "$HOME/.config/noi/apple.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$HOME/.config/noi/apple.env"
  set +a
fi
IDENTITY="${CODESIGN_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
ENTITLEMENTS="$ROOT/apps/macos-v2/ChatGPTAudioLocal.entitlements"

if [[ ! -d "$APP" ]]; then
  echo "error: app not found: $APP — run apps/macos-v2/scripts/build-app.sh first" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
STAGE="$(mktemp -d)/dmg-root"
mkdir -p "$STAGE"
trap 'rm -rf "$(dirname "$STAGE")"' EXIT

# Fresh copy for packaging
ditto "$APP" "$STAGE/Noi.app"
xattr -cr "$STAGE/Noi.app" 2>/dev/null || true

# Standard install UX: link to Applications
ln -s /Applications "$STAGE/Applications"

# Short install note (visible in DMG window)
cat > "$STAGE/Cach-cai.txt" <<'EOF'
Nói — cài trên Mac (Apple Silicon)

1. Kéo "Nói" vào thư mục Applications (bên cạnh).
2. Mở Launchpad / Applications → mở Nói (chạy trên menu bar).
3. Đăng nhập ChatGPT trong app → giữ ⌃⌥ để nói.

Nếu macOS báo "chưa được mở":
  • Bản đã notarize: hiếm khi xảy ra — thử chuột phải → Mở.
  • Bản chưa notarize: chuột phải app → Mở → Mở (một lần).

Free · mã nguồn mở · dữ liệu trên máy bạn.
EOF

# Prefer Developer ID if present
if [[ -z "$IDENTITY" ]]; then
  if security find-identity -v -p codesigning 2>/dev/null | grep -q 'Developer ID Application'; then
    IDENTITY="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' | head -1)"
  fi
fi

SIGN_OPTS=(--force --deep --options runtime)
if [[ -f "$ENTITLEMENTS" ]]; then
  SIGN_OPTS+=(--entitlements "$ENTITLEMENTS")
else
  echo "warn: entitlements missing ($ENTITLEMENTS) — notarized build may crash on embedded Node" >&2
fi

if [[ -n "$IDENTITY" ]]; then
  echo "codesign: $IDENTITY" >&2
  codesign "${SIGN_OPTS[@]}" --timestamp \
    --sign "$IDENTITY" \
    --identifier "dev.dmdfami.chatgpt-audio-local" \
    "$STAGE/Noi.app"
  codesign --verify --deep --strict "$STAGE/Noi.app"
else
  echo "warn: no Developer ID Application cert — signing ad-hoc (Gatekeeper will warn after download)" >&2
  codesign "${SIGN_OPTS[@]}" --sign - \
    --identifier "dev.dmdfami.chatgpt-audio-local" \
    "$STAGE/Noi.app" || true
fi

DMG_PATH="$OUT_DIR/$DMG_NAME"
rm -f "$DMG_PATH"
# UDZO compressed read-only DMG
hdiutil create \
  -volname "$VOL_NAME" \
  -srcfolder "$STAGE" \
  -ov -format UDZO \
  "$DMG_PATH" >/dev/null

# Notarize DMG when credentials available
if [[ -n "$NOTARY_PROFILE" ]] && [[ -n "$IDENTITY" ]] && [[ "$IDENTITY" == Developer\ ID* ]]; then
  echo "submitting to Apple notary service (profile=$NOTARY_PROFILE)…" >&2
  xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait
  xcrun stapler staple "$DMG_PATH"
  # Also staple the app inside a writable copy is harder; staple DMG is enough for Gatekeeper
  spctl --assess --type open --context context:primary-signature -v "$DMG_PATH" 2>&1 || true
  echo "notarized + stapled: $DMG_PATH" >&2
else
  echo "skip notarize (set NOTARY_PROFILE=… and install Developer ID Application cert)" >&2
fi

SIZE="$(du -h "$DMG_PATH" | awk '{print $1}')"
SHA="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
# Also refresh zip name pointer on landing
cat > "$OUT_DIR/manifest.json" <<EOF
{
  "product": "Nói",
  "version": "$VERSION",
  "file": "$DMG_NAME",
  "format": "dmg",
  "arch": "arm64",
  "minOS": "13.0",
  "size": "$SIZE",
  "sha256": "$SHA",
  "builtAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "install": "Open DMG → drag app to Applications → open from Applications",
  "notarized": $([ -n "${NOTARY_PROFILE:-}" ] && [ -n "${IDENTITY:-}" ] && [[ "${IDENTITY}" == Developer\ ID* ]] && echo true || echo false)
}
EOF

echo "$DMG_PATH"
echo "size=$SIZE sha256=$SHA" >&2
