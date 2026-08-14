# AGENTS.md — Nói

## Sản phẩm

**Nói** — app menu bar cho macOS: giữ `⌃⌥`, nói, thả ra → chữ hiện tại con trỏ, dùng phiên đăng nhập ChatGPT web của người dùng. Tuỳ chọn: chạm đôi `⌥` để sửa văn bản đang chọn bằng Google AI Studio.

Trang chủ: https://noi.d92.uk · Tải: https://dl.d92.uk/Noi-1.0.0.dmg

## Scope — giữ tối giản, không nới

- **Cốt lõi:** STT qua phiên ChatGPT web. Không cần API key.
- **Tuỳ chọn:** sửa văn bản, **chỉ Google AI Studio** (key free của người dùng), có xoay vòng model để né giới hạn free tier.
- **Không thêm:** TTS, provider khác, custom endpoint, marketplace, backend hosted, billing UI.
- **Nền tảng:** macOS 13+, Apple Silicon. (iOS/Android/Windows: ngoài phạm vi.)

## Kiến trúc

```
apps/macos-v2 (Swift, menu bar: hotkey · mic · dán)
        │  HTTP 127.0.0.1:8797 (chỉ loopback, không phát CORS)
        ▼
packages/local-core (Node nhúng trong .app)
        │
        ▼
ChatGPT web (STT) · Google AI Studio (sửa, tuỳ chọn)
```

| Đường dẫn | Vai trò |
|---|---|
| `apps/macos-v2/Sources/` | App Swift: `main.swift`, `StatusPopover`, `FloatingHUD`, `MenuBarController`, `ChatGPTSession`, `AppStrings`, `DesignTokens` |
| `apps/macos-v2/scripts/` | `build-app.sh` (đóng .app tự chứa), `verify-packaging.sh` |
| `packages/local-core/` | Core Node: server, provider, prompts, UI Settings (`public/`) |
| `site/` | Landing (Cloudflare Pages → noi.d92.uk) |
| `scripts/` | `make-dmg.sh`, `deploy-landing.sh`, `cloud-connect.sh`, `setup-developer-id.sh` |

## Quy tắc code

1. **Không bao giờ log** audio, transcript, hay token.
2. Secret chỉ nằm ở `~/.config/chatgpt-audio/v2.env` (mode 0600). Không commit secret.
3. Core bind **chỉ `127.0.0.1`**, không phát `access-control-allow-origin`.
4. `local-core` giữ **zero dependency** (chỉ Node stdlib).
5. Diff nhỏ, không phình design system. Không thêm comment mô tả điều code đã tự nói.
6. Node nhúng phải là bản standalone từ nodejs.org (script chặn bản liên kết Homebrew).

## Chạy & kiểm thử

```bash
cd packages/local-core && npm test      # HTTP surface + prompts
npm start                                # UI Settings tại http://127.0.0.1:8797

cd apps/macos-v2 && ./scripts/build-app.sh && ./scripts/verify-packaging.sh   # cần máy Mac
```

## Cursor Cloud

- Môi trường cloud là **Linux** → build Swift/DMG phải chạy trên máy Mac.
- `scripts/cloud-connect.sh` (chạy tự động qua `.cursor/environment.json`) nối agent vào tailnet và mở sẵn `ssh mac` / `ssh vps`. Build từ xa:
  ```bash
  bash scripts/cloud-connect.sh
  git archive --format=tar HEAD | ssh mac 'rm -rf ~/noi-build && mkdir -p ~/noi-build && tar -x -C ~/noi-build'
  ssh mac 'cd ~/noi-build/apps/macos-v2 && ./scripts/build-app.sh && ./scripts/verify-packaging.sh'
  ```
- Deploy landing: `scripts/deploy-landing.sh` (Cloudflare Pages, project `noi`).

### Chạy & kiểm thử trên Cloud (Linux)

- Phần test được trên Linux là `packages/local-core` (zero-dependency, chỉ Node stdlib): `npm test` (8 test) và `npm start` (UI Settings + API tại `http://127.0.0.1:8797`). App Swift/DMG cần máy Mac.
- **STT** không thể test headless trên Linux: cần đăng nhập ChatGPT web thật (`CHATGPT_ACCESS_TOKEN`) + micro; endpoint không chính thức. `/v1/status` sẽ báo `degraded` khi chưa có token — đó là bình thường.
- **Correct** (tuỳ chọn) cần một `GOOGLE_AI_STUDIO_API_KEY` mà **project GCP tương ứng đã bật Generative Language API**. Nếu API bị tắt sẽ trả HTTP 403 dù key hợp lệ. Server đọc key từ `~/.config/chatgpt-audio/v2.env` hoặc biến môi trường cùng tên (alias `GEMINI_API_KEY`).

## Tài liệu cần cập nhật khi đổi hành vi

`README.md` · `docs/INSTALL-MACOS.md` · `docs/HOTKEYS.md` · `docs/SCREENS.md` · `PRIVACY.md` · `CHANGELOG.md`
