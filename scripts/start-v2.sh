#!/usr/bin/env bash
# Start ChatGPT Audio v2 local-core + open web UI.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${PORT:-8797}"
URL="http://127.0.0.1:${PORT}"

export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"

if curl -fsS --max-time 1 "${URL}/healthz" >/dev/null 2>&1 \
  && curl -fsS --max-time 1 "${URL}/" | grep -qi '<html'; then
  echo "local-core already up at ${URL}"
else
  echo "starting local-core on :${PORT}…"
  node "$ROOT/packages/local-core/cli.mjs" serve &
  PID=$!
  echo "$PID" > /tmp/chatgpt-audio-v2.pid
  for i in $(seq 1 30); do
    if curl -fsS --max-time 1 "${URL}/healthz" >/dev/null 2>&1; then
      break
    fi
    sleep 0.2
  done
fi

echo "UI: ${URL}/"
echo "env: ~/.config/chatgpt-audio/v2.env"
if command -v open >/dev/null 2>&1; then
  open "${URL}/"
fi

# Keep foreground if we started the server in this shell without &
if [[ -n "${PID:-}" ]]; then
  wait "$PID"
fi
