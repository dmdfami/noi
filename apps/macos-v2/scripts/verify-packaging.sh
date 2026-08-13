#!/bin/zsh
# Verify self-contained ChatGPT Audio Local.app packaging.
# Drives the real embedded node + cli.mjs (not the git checkout).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$ROOT/../.." && pwd)"
SCRATCH="${CHATGPT_AUDIO_SCRATCH:-${TMPDIR:-/tmp}/chatgpt-audio-pack-verify}"
mkdir -p "$SCRATCH"

APP="${1:-/Applications/Noi.app}"
NODE="$APP/Contents/Resources/runtime/node"
CLI="$APP/Contents/Resources/local-core/cli.mjs"
PUBLIC="$APP/Contents/Resources/local-core/public/index.html"
MANIFEST="$APP/Contents/Resources/bundle-manifest.txt"

echo "inspecting: $APP" | tee "$SCRATCH/app-inspect.log"

fail() { echo "FAIL: $*" | tee -a "$SCRATCH/app-inspect.log" >&2; exit 1; }
ok() { echo "OK: $*" | tee -a "$SCRATCH/app-inspect.log"; }

[[ -d "$APP" ]] || fail "app missing: $APP"
[[ -x "$NODE" ]] || fail "embedded node missing/not executable: $NODE"
[[ -f "$CLI" ]] || fail "embedded cli.mjs missing: $CLI"
[[ -f "$PUBLIC" ]] || fail "embedded public/index.html missing: $PUBLIC"
[[ -f "$MANIFEST" ]] || fail "bundle-manifest.txt missing"

# repo-root.txt must not be required (may be absent)
if [[ -f "$APP/Contents/Resources/repo-root.txt" ]]; then
  echo "NOTE: repo-root.txt present (legacy); bundled path must still work without it" | tee -a "$SCRATCH/app-inspect.log"
else
  ok "no repo-root.txt (ship path is bundled-only)"
fi

ok "runtime/node + local-core/cli.mjs + public/"
{
  echo "NODE=$NODE"
  file "$NODE"
  "$NODE" -v
  echo "CLI=$CLI"
  ls -la "$APP/Contents/Resources/runtime" "$APP/Contents/Resources/local-core" | head -40
} | tee -a "$SCRATCH/app-inspect.log"

# codesign
codesign --verify --deep --strict "$APP" 2>"$SCRATCH/codesign.txt" || fail "codesign verify failed"
ok "codesign --verify" | tee -a "$SCRATCH/codesign.txt"
cat "$SCRATCH/codesign.txt" >>"$SCRATCH/app-inspect.log" || true

# Free port + spawn embedded core from embedded paths only (cwd = local-core inside app)
PORT="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')"
CORE_DIR="$APP/Contents/Resources/local-core"
URL="http://127.0.0.1:${PORT}"

echo "spawning embedded core on :$PORT" | tee -a "$SCRATCH/app-inspect.log"
# Working directory intentionally NOT the git repo
cd /tmp
PORT="$PORT" "$NODE" "$CLI" serve >"$SCRATCH/core-stdout.log" 2>"$SCRATCH/core-stderr.log" &
PID=$!
cleanup() { kill "$PID" 2>/dev/null || true; wait "$PID" 2>/dev/null || true; }
trap cleanup EXIT

ready=0
for i in $(seq 1 40); do
  if curl -fsS --max-time 1 "${URL}/healthz" -o "$SCRATCH/healthz-probe.json" 2>/dev/null; then
    ready=1
    break
  fi
  sleep 0.15
done
[[ "$ready" == "1" ]] || {
  echo "--- core stderr ---" >&2
  cat "$SCRATCH/core-stderr.log" >&2 || true
  fail "healthz never became ready on $URL"
}

curl -fsS "${URL}/healthz" -o "$SCRATCH/healthz-1.json"
curl -fsS "${URL}/healthz" -o "$SCRATCH/healthz-2.json"
# static UI served from embedded public/
curl -fsS "${URL}/" -o "$SCRATCH/index.html"
grep -q "ok" "$SCRATCH/healthz-1.json" || fail "healthz-1 not ok: $(cat "$SCRATCH/healthz-1.json")"
grep -q "ok" "$SCRATCH/healthz-2.json" || fail "healthz-2 not ok"
# both should report version 2
python3 - <<'PY' "$SCRATCH/healthz-1.json" "$SCRATCH/healthz-2.json"
import json,sys
a=json.load(open(sys.argv[1]))
b=json.load(open(sys.argv[2]))
assert a.get("ok") is True and b.get("ok") is True
assert a.get("version")==b.get("version")==2
print("healthz pair consistent", a)
PY
grep -qi "html" "$SCRATCH/index.html" || fail "dashboard HTML not served from embedded public/"
ok "embedded healthz x2 + static index.html"

# Swift source structural checks (in-app dashboard, not browser-only)
SWIFT_MAIN="$ROOT/Sources/main.swift"
SWIFT_CFG="$ROOT/Sources/ChatGPTSession.swift"
rg -n "ConfigDashboardWindowController|resolveCoreLaunch|runtime/node|chatgpt-audio-local|handleDeepLink" \
  "$SWIFT_MAIN" "$SWIFT_CFG" | tee "$SCRATCH/dashboard-ui.txt"
rg -q "ConfigDashboardWindowController" "$SWIFT_CFG" || fail "missing ConfigDashboardWindowController"
rg -q "func openDashboard" "$SWIFT_MAIN" || fail "missing openDashboard"
rg -n "configDashboard\.show|ConfigDashboardWindowController" "$SWIFT_MAIN" | tee -a "$SCRATCH/dashboard-ui.txt"
rg -q "configDashboard\.show" "$SWIFT_MAIN" || fail "openDashboard must call configDashboard.show (in-app WebView)"
# Must NOT be browser-only config
if rg -q "Mở cấu hình trong trình duyệt" "$SWIFT_MAIN"; then
  fail "external browser config menu still present"
fi
rg -q "handleDeepLink|chatgpt-audio-local" "$SWIFT_MAIN" || fail "missing deep link for in-app ChatGPT login"
ok "in-app dashboard + deep-link login present"

echo "ALL PACKAGING CHECKS PASSED" | tee -a "$SCRATCH/app-inspect.log"
echo "scratch=$SCRATCH"
