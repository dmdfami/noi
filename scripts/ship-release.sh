#!/usr/bin/env bash
# Official ship: build .app → notarized DMG → R2 + Pages + purge.
# Secrets: ~/.config/noi/apple.env + Infisical (CLOUDFLARE_GLOBAL_API_KEY).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${SHIP_VERSION:?set SHIP_VERSION=x.y.z}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export PATH="$DEVELOPER_DIR/usr/bin:/opt/homebrew/bin:$PATH"

if [[ -f "$HOME/.config/noi/apple.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$HOME/.config/noi/apple.env"
  set +a
fi
: "${APPLE_CODESIGN_IDENTITY:?missing APPLE_CODESIGN_IDENTITY — source ~/.config/noi/apple.env}"
export CODESIGN_IDENTITY="$APPLE_CODESIGN_IDENTITY"
export NOTARY_PROFILE="${NOTARY_PROFILE:-AC_NOTARY}"

if ! security find-identity -v -p codesigning | grep -Fq "$CODESIGN_IDENTITY"; then
  echo "error: codesign identity not in keychain: $CODESIGN_IDENTITY" >&2
  exit 1
fi

echo "building app…" >&2
(cd "$ROOT/apps/macos-v2" && ./scripts/build-app.sh) >&2

echo "dmg + notarize…" >&2
SHIP_VERSION="$VERSION" "$ROOT/scripts/make-dmg.sh" >&2
DMG="$ROOT/site/downloads/Noi-${VERSION}.dmg"
xcrun stapler validate "$DMG"

# Cloudflare: Infisical global key → CLOUDFLARE_API_KEY (not the AI-gateway token)
if [[ -z "${CLOUDFLARE_API_KEY:-}" && -r "$HOME/.config/infisical/cf-god-machine.env" ]]; then
  # shellcheck disable=SC1091
  set -a; source "$HOME/.config/infisical/cf-god-machine.env"; set +a
  INF_TOKEN="$(infisical login --method universal-auth \
    --client-id "$INFISICAL_CLIENT_ID" --client-secret "$INFISICAL_CLIENT_SECRET" \
    --plain --silent --domain "$INFISICAL_DOMAIN")"
  eval "$(
    infisical secrets get CLOUDFLARE_GLOBAL_API_KEY CLOUDFLARE_EMAIL CLOUDFLARE_ACCOUNT_ID \
      --domain "$INFISICAL_DOMAIN" --projectId "$INFISICAL_PROJECT_ID" \
      --env "$INFISICAL_ENV" --token "$INF_TOKEN" --output json \
    | python3 -c 'import json,sys
d=json.load(sys.stdin)
v={i["secretKey"]:i["secretValue"] for i in d}
print("export CLOUDFLARE_API_KEY="+json.dumps(v.get("CLOUDFLARE_GLOBAL_API_KEY","")))
print("export CLOUDFLARE_EMAIL="+json.dumps(v.get("CLOUDFLARE_EMAIL","")))
print("export CLOUDFLARE_ACCOUNT_ID="+json.dumps(v.get("CLOUDFLARE_ACCOUNT_ID","")))
'
  )"
fi
: "${CLOUDFLARE_API_KEY:?need CLOUDFLARE_API_KEY or Infisical global key}"
: "${CLOUDFLARE_ACCOUNT_ID:?need CLOUDFLARE_ACCOUNT_ID}"

echo "upload R2…" >&2
wrangler r2 object put "noi-dl/Noi-${VERSION}.dmg" --file "$DMG" \
  --content-type application/x-apple-diskimage --remote
wrangler r2 object put noi-dl/manifest.json \
  --file "$ROOT/site/downloads/manifest.json" --content-type application/json --remote

STAGE="$(mktemp -d)"
rsync -a --exclude 'downloads/*.dmg' --exclude 'downloads/*.zip' "$ROOT/site/" "$STAGE/"
npx --yes wrangler@4 pages deploy "$STAGE" --project-name noi --commit-dirty=true --branch main
rm -rf "$STAGE"

python3 - <<PY
import json, os, urllib.request
body = json.dumps({"files": [
    f"https://dl.d92.uk/Noi-${VERSION}.dmg",
    "https://dl.d92.uk/manifest.json",
    "https://noi.d92.uk/",
    "https://noi.d92.uk/index.html",
]}).encode()
req = urllib.request.Request(
    "https://api.cloudflare.com/client/v4/zones/b08e44b174c81e758244bcfd6aaddd4e/purge_cache",
    data=body, method="POST",
    headers={
        "X-Auth-Email": os.environ["CLOUDFLARE_EMAIL"],
        "X-Auth-Key": os.environ["CLOUDFLARE_API_KEY"],
        "Content-Type": "application/json",
    },
)
with urllib.request.urlopen(req, timeout=20) as r:
    data = json.load(r)
if not data.get("success"):
    raise SystemExit("purge failed: " + str(data.get("errors")))
print("purged cache", file=__import__("sys").stderr)
PY

echo "shipped $DMG" >&2
echo "next: update site/index.html href if version changed; gh release create v${VERSION} $DMG" >&2
echo "$DMG"
