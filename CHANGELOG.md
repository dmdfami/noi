# Changelog

Mỗi bản phát hành = một `Noi-<version>.dmg` trên GitHub Releases, khớp `CFBundleShortVersionString`.

## 1.0.3 — trạng thái Cài đặt khớp quyền macOS

- Cửa sổ Cài đặt không còn ghi **Sẵn sàng** khi còn thiếu Trợ năng / Theo dõi phím (ký Developer ID mới = TCC coi như app mới).
- Gỡ prefs cũ `workers_ai` / `@cf/…` còn sót từ bản nội bộ — “Sửa văn bản” chỉ còn Google AI Studio.

## 1.0.2 — Settings không nhận nhầm core cũ

- **Cửa sổ Cài đặt ra JSON `not_found /index.html`** khi cổng `8797` bị process mồ côi của app cũ (ChatGPT Audio Local) chiếm: Nói thấy `/healthz` OK nên không spawn core của mình. Giờ chỉ nhận core có UI HTML; cổng bận thì chọn cổng trống và truyền `PORT`.

## 1.0.1 — sửa dán lặp + notarize

- **Sửa lỗi dán lặp 3 lần sau khi nói** (browser/Electron/terminal): trước đây một lần dán bắn Cmd+V vào cả hai tap HID + session (thành 2 lần) rồi chạy thêm AppleScript backup (lần 3). Giờ chỉ dán đúng một lần; AppleScript chỉ còn là fallback khi thiếu quyền Input Monitoring.
- **Notarize Apple** — ký `Developer ID Application: DUC DO MANH (P9U773F44F)`, staple DMG. Gatekeeper: Notarized Developer ID. Runbook: [docs/SHIP-MAC.md](docs/SHIP-MAC.md).

## 1.0.0 — bản công khai đầu tiên (mã nguồn mở)

Định vị lại về đúng một việc: **nói ra chữ trên Mac bằng tài khoản ChatGPT**.

- **Đổi tên sản phẩm → Nói**; mã nguồn mở giấy phép MIT.
- **STT** qua phiên ChatGPT web, đăng nhập ngay trong app.
- **Sửa văn bản (tuỳ chọn)**: chỉ còn **Google AI Studio** (key free), có thể xoay vòng vài model để né giới hạn free tier.
- **Bỏ hẳn TTS** (nghe) — app không còn cần `ffmpeg`, không còn phụ thuộc ngoài nào.
- **Bỏ** DeepSeek, OpenRouter, Cloudflare Gateway/Workers AI, custom endpoint.
- Settings gọn còn: trạng thái · đăng nhập ChatGPT · một ô key AI Studio. Song ngữ VI/EN.
- Hotkey: giữ/chạm đôi **⌃⌥** nói · chạm đôi **⌥** sửa · **Esc** dừng.
- Bảo mật: core cục bộ bind `127.0.0.1`, không phát CORS; secret ở `~/.config/chatgpt-audio/v2.env` (0600).
- Đóng gói: `.app` tự chứa (nhúng Node), hardened runtime + entitlements để notarize; DMG kéo-vào-Applications.

### Còn lại (cần máy Mac)
- Build `.app`/DMG và notarize thực hiện trên macOS (môi trường phát triển cloud là Linux).
- Xác minh model id AI Studio với key thật trước khi chốt mặc định.

## Trước 1.0 (nội bộ)

Các bản v1 (hosted qua Cloudflare Worker) và v2/v3 (local, tên cũ "Audio Local") chỉ dùng nội bộ, không phát hành công khai.
