#!/bin/bash
# Double-click this after unzip — removes Gatekeeper quarantine and installs to Applications.
set -euo pipefail
cd "$(dirname "$0")"
APP="Noi.app"

if [[ ! -d "$APP" ]]; then
  osascript -e 'display dialog "Không thấy Noi.app cạnh file này.\nHãy giải nén cả thư mục (không chỉ file .app)." buttons {"OK"} default button 1 with icon stop'
  exit 1
fi

# Browser download stamps quarantine → macOS blocks double-click. Strip it.
xattr -cr "$APP" 2>/dev/null || true

DEST="/Applications/Noi.app"
rm -rf "$DEST"
ditto "$APP" "$DEST"
xattr -cr "$DEST" 2>/dev/null || true

open "$DEST"
osascript -e 'display dialog "Đã cài Nói vào Applications và mở app.\nNói chạy trên menu bar (góc trên phải).\n\nNếu macOS vẫn chặn: Finder → Applications → chuột phải Nói → Mở." buttons {"OK"} default button 1 with title "Nói"'
