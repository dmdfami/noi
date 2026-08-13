#!/usr/bin/env bash
# Build .app, pack zip with install helper (strips Gatekeeper quarantine), site/downloads + manifest.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${SHIP_VERSION:-1.0.0}"
SITE="$ROOT/site"
DL="$SITE/downloads"
mkdir -p "$DL"

echo "building app…" >&2
(cd "$ROOT/apps/macos-v2" && ./scripts/build-app.sh) >&2

APP="/Applications/Noi.app"
if [[ ! -d "$APP" ]]; then
  echo "error: missing $APP" >&2
  exit 1
fi

# Stage folder: app + install helper (browser download always sets quarantine on .app)
STAGE="$(mktemp -d)/Noi"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/Noi.app"
# Clear quarantine on staged app so zip is cleaner (browser may re-stamp the zip itself)
xattr -cr "$STAGE/Noi.app" 2>/dev/null || true

cp "$SITE/install/Cai-dat.command" "$STAGE/Cai-dat.command"
cp "$SITE/install/README-CAI-DAT.txt" "$STAGE/README-CAI-DAT.txt"
chmod +x "$STAGE/Cai-dat.command"

ZIP_NAME="Noi.zip"
ZIP_PATH="$DL/$ZIP_NAME"
rm -f "$ZIP_PATH"
# Zip the folder (not bare .app) so install script sits next to the app
ditto -c -k --keepParent "$STAGE" "$ZIP_PATH"
rm -rf "$(dirname "$STAGE")"

SIZE="$(du -h "$ZIP_PATH" | awk '{print $1}')"
SHA="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
BUILT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

cat > "$DL/manifest.json" <<EOF
{
  "product": "Nói",
  "version": "$VERSION",
  "file": "$ZIP_NAME",
  "arch": "arm64",
  "minOS": "13.0",
  "size": "$SIZE",
  "sha256": "$SHA",
  "builtAt": "$BUILT",
  "install": "Unzip → double-click Cai-dat.command (or right-click .app → Open)"
}
EOF

echo "site download: $ZIP_PATH ($SIZE)" >&2
echo "sha256: $SHA" >&2
echo "landing: $SITE/index.html" >&2
echo "serve:  python3 -m http.server 8780 --directory $SITE" >&2
echo "$ZIP_PATH"
