#!/bin/zsh
# Build + install ChatGPT Audio Local (v2) as a self-contained .app:
# menu-bar binary + embedded arm64 Node + packages/local-core under Resources.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$ROOT/../.." && pwd)"
cd "$ROOT"

BUNDLE_ID="dev.dmdfami.chatgpt-audio-local"
APP_NAME="Noi"
DEFAULT_IDENTITY="ChatGPT Audio Local Code Signing"
SIGN_IDENTITY="${CHATGPT_AUDIO_CODESIGN_IDENTITY:-$DEFAULT_IDENTITY}"
ENTITLEMENTS="$ROOT/ChatGPTAudioLocal.entitlements"

# --- resolve Node binary to embed (arm64 preferred) ---
resolve_node() {
  if [[ -n "${CHATGPT_AUDIO_NODE_BIN:-}" && -x "${CHATGPT_AUDIO_NODE_BIN}" ]]; then
    echo "${CHATGPT_AUDIO_NODE_BIN}"
    return
  fi
  local candidates=(
    "$HOME/.hermes/node/bin/node"
    "$HOME/.local/bin/node"
    "$(command -v node 2>/dev/null || true)"
    /opt/homebrew/bin/node
    /usr/local/bin/node
  )
  local c real
  for c in "${candidates[@]}"; do
    [[ -z "$c" || ! -x "$c" ]] && continue
    real="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$c" 2>/dev/null || echo "$c")"
    if file "$real" 2>/dev/null | grep -q "arm64"; then
      echo "$real"
      return
    fi
  done
  echo "error: no arm64 Node binary found to embed (set CHATGPT_AUDIO_NODE_BIN)" >&2
  exit 1
}

NODE_BIN="$(resolve_node)"
echo "embedding Node: $NODE_BIN ($(file -b "$NODE_BIN"))" >&2
NODE_VER="$("$NODE_BIN" -v 2>/dev/null || echo unknown)"
# Require Node ≥20 for local-core
NODE_MAJOR="${NODE_VER#v}"
NODE_MAJOR="${NODE_MAJOR%%.*}"
if [[ "${NODE_MAJOR}" -lt 20 ]]; then
  echo "error: embedded Node must be ≥20 (got $NODE_VER)" >&2
  exit 1
fi

# A Homebrew-linked Node runs here but dies on a user's Mac (no /opt/homebrew).
# Ship the official standalone build from nodejs.org instead.
NODE_LINKS="$(otool -L "$NODE_BIN" 2>/dev/null | awk 'NR>1 {print $1}' \
  | grep -Ev '^(/usr/lib/|/System/Library/)' || true)"
if [[ -n "$NODE_LINKS" ]]; then
  echo "error: embedded Node links non-system libraries — it will not run on a clean Mac:" >&2
  echo "$NODE_LINKS" | sed 's/^/  /' >&2
  echo "fix: download node-v*-darwin-arm64.tar.gz from nodejs.org and set" >&2
  echo "     CHATGPT_AUDIO_NODE_BIN=/path/to/node-v*/bin/node (or CHATGPT_AUDIO_ALLOW_LINKED_NODE=1 to override)" >&2
  [[ "${CHATGPT_AUDIO_ALLOW_LINKED_NODE:-0}" != "1" ]] && exit 1
fi

LOCAL_CORE_SRC="$REPO/packages/local-core"
if [[ ! -f "$LOCAL_CORE_SRC/cli.mjs" ]]; then
  echo "error: missing $LOCAL_CORE_SRC/cli.mjs" >&2
  exit 1
fi

echo "building ChatGPTAudioV2 (release)…" >&2
swift build -c release --product ChatGPTAudioV2 --jobs "${CHATGPT_AUDIO_JOBS:-4}" >&2

BUNDLE_DIR="$ROOT/.build/app-bundle"
APP="$BUNDLE_DIR/${APP_NAME}.app"
rm -rf "$BUNDLE_DIR"
mkdir -p \
  "$APP/Contents/MacOS" \
  "$APP/Contents/Resources/runtime" \
  "$APP/Contents/Resources/local-core"

cp .build/release/ChatGPTAudioV2 "$APP/Contents/MacOS/ChatGPTAudioV2"
cp Info.plist "$APP/Contents/Info.plist"

# App icon
if [[ -f Resources/AppIcon.icns ]]; then
  cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

# Embed Node runtime (standalone path for shipped installs — no system node required)
cp "$NODE_BIN" "$APP/Contents/Resources/runtime/node"
chmod 755 "$APP/Contents/Resources/runtime/node"

# Embed local-core (pure ESM, no node_modules)
# Exclude tests and junk; public/ + src/ + cli.mjs required for serve + static UI
rsync -a \
  --exclude '.DS_Store' \
  --exclude 'node_modules' \
  --exclude '.git' \
  --exclude '*.test.mjs' \
  --exclude 'artifacts' \
  "$LOCAL_CORE_SRC/" "$APP/Contents/Resources/local-core/"

# Manifest for debugging / verify-packaging
cat > "$APP/Contents/Resources/bundle-manifest.txt" <<EOF
product=Nói
bundle_id=$BUNDLE_ID
embedded_node=$NODE_VER
local_core=packages/local-core
layout=Resources/runtime/node + Resources/local-core/cli.mjs
ship_path=bundled (repo-root.txt not required)
built_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

# Do NOT write repo-root.txt — shipped path must work without git checkout.

identity_available() {
  security find-identity -v -p codesigning 2>/dev/null | grep -F "\"$1\"" >/dev/null 2>&1
}

# Hardened runtime + entitlements from the first local build on: the embedded
# Node needs JIT/library exceptions, and notarization refuses bundles signed
# without them. Keeping dev builds identical to shipped builds surfaces
# TCC/paste regressions here instead of on a user's Mac.
sign_app() {
  local target="$1"
  local opts=(--force --deep --options runtime)
  [[ -f "$ENTITLEMENTS" ]] && opts+=(--entitlements "$ENTITLEMENTS")
  if [[ -n "${SIGN_IDENTITY}" ]] && identity_available "$SIGN_IDENTITY"; then
    codesign "${opts[@]}" --sign "$SIGN_IDENTITY" --identifier "$BUNDLE_ID" "$target" >&2
    echo "signed identity=$SIGN_IDENTITY id=$BUNDLE_ID hardened=yes" >&2
  else
    codesign "${opts[@]}" --sign - --identifier "$BUNDLE_ID" \
      --requirements "=designated => identifier \"$BUNDLE_ID\"" \
      "$target" >&2
    echo "signed identity=adhoc id=$BUNDLE_ID hardened=yes" >&2
  fi
  codesign --verify --deep --strict "$target" >&2
}

sign_app "$APP"

INSTALL_APP="/Applications/${APP_NAME}.app"
rm -rf "$INSTALL_APP"
cp -R "$APP" "$INSTALL_APP"
sign_app "$INSTALL_APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -f "$INSTALL_APP" 2>/dev/null || true

echo "embedded:" >&2
echo "  node: $INSTALL_APP/Contents/Resources/runtime/node" >&2
echo "  core: $INSTALL_APP/Contents/Resources/local-core/cli.mjs" >&2
echo "$INSTALL_APP"
