# Hỗ trợ — Nói

## Tự xử lý trước

Phần lớn sự cố cài đặt nằm trong **[docs/INSTALL-MACOS.md](docs/INSTALL-MACOS.md#gặp-sự-cố)** — hotkey không chạy, không dán được chữ, không thấy app.

## Kiểm tra nhanh trạng thái

Menu bar → **Cài đặt**. Hai dòng trạng thái cho biết đang thiếu gì:

| Trạng thái | Nghĩa |
|---|---|
| Nói ra chữ (STT): *Cần đăng nhập ChatGPT* | Bấm **Đăng nhập…** |
| Nói ra chữ (STT): *Token hết hạn* | Bấm **Đổi tài khoản…** |
| Sửa văn bản: *Chưa có key AI Studio* | Dán API key AI Studio (tuỳ chọn) |
| Cả trang không tải | Core cục bộ chưa chạy — thoát app và mở lại |

## Báo lỗi

Mở [GitHub Issues](https://github.com/dmdfami/noi/issues), kèm (đừng dán token/API key/nội dung riêng tư):

1. Phiên bản macOS + dòng máy (vd macOS 14.5, MacBook Air M2).
2. Phiên bản Nói (menu bar → Cài đặt, chân trang).
3. Bạn bấm gì / hotkey nào, và điều gì xảy ra.
4. Trạng thái hiện trong Cài đặt.

Lỗi bảo mật: xem [SECURITY.md](SECURITY.md) — báo riêng, không mở Issue công khai.
