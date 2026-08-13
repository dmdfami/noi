# Changelog

Mỗi bản phát hành = một `Noi-<version>.dmg` trên GitHub Releases, khớp `CFBundleShortVersionString`.

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
