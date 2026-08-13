# Đóng gói **một app Mac** (self-contained)

## Trạng thái (đã implement)

```
ChatGPT Audio Local.app
├── MacOS/ChatGPTAudioV2          # menu bar + hotkeys + mic
└── Resources/
    ├── runtime/node              # arm64 Node ≥20 (embedded)
    ├── local-core/               # packages/local-core (cli + public + src)
    └── bundle-manifest.txt
```

| Mục | Status |
|---|---|
| Embed Node + local-core | **Done** — `apps/macos-v2/scripts/build-app.sh` |
| Spawn embedded core on launch | **Done** — `V2Config.resolveCoreLaunch` → `runtime/node` + `local-core/cli.mjs` |
| In-app config UI | **Done** — `ConfigDashboardWindowController` (WKWebView); external browser = fallback menu |
| Codesign (local identity) | **Done** on build |
| Verify script | `apps/macos-v2/scripts/verify-packaging.sh` |
| Developer ID + **Notarize** | **Not done** — requires Apple Developer account; needed for Gatekeeper on stranger Macs |
| Pure Swift port of providers | Non-goal |

## Build / install

```bash
cd apps/macos-v2
./scripts/build-app.sh
# → /Applications/ChatGPT Audio Local.app

# Optional: override Node binary to embed
# CHATGPT_AUDIO_NODE_BIN=/path/to/node-arm64 ./scripts/build-app.sh

./scripts/verify-packaging.sh
```

User **không** cần:

- System-wide Node
- Clone `~/dev/chatgpt-audio-client`
- `repo-root.txt` (removed from ship path)

## Runtime resolution order

1. **Bundled:** `Contents/Resources/runtime/node` + `…/local-core/cli.mjs`
2. **Dev fallback:** system Node + git checkout (for engineers running unbundled binary)

## Config UI

- Menu **Cấu hình…** → **only** in-app WKWebView → `http://127.0.0.1:8797/` (no external browser)
- Guide tab CTA **Đăng nhập ChatGPT…** → deep link `chatgpt-audio-local://login` → native login window
- Menu **Đăng nhập ChatGPT…** still available as shortcut
- First launch opens config once after `ensureCore`

## Public landing + download zip

```bash
./scripts/ship-site.sh
# → site/downloads/ChatGPT-Audio-Local.zip + manifest.json
# → open site/index.html or: python3 -m http.server 8780 --directory site
```

## End-user distribution (remaining)

| Step | Notes |
|---|---|
| Apple Developer Program | Required for Developer ID Application cert |
| `codesign` with Developer ID | Replace local “ChatGPT Audio Local Code Signing” |
| `notarytool submit` + staple | Without this, other Macs show Gatekeeper block |
| DMG / ZIP | Optional packaging polish |
| Sparkle updates | Future |

Until notarized: ship is fine for **your machines** and users who right-click → Open, or for TestFlight-style internal use. Not “Mac App Store ready”.

## Size

Embedded Node ≈ 100MB+ → app total ~110MB+. Acceptable for local-first product.
