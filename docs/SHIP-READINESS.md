# Ship readiness

Bản công khai hiện tại: **1.0.1** — [noi.d92.uk](https://noi.d92.uk) · [dl.d92.uk/Noi-1.0.1.dmg](https://dl.d92.uk/Noi-1.0.1.dmg) · [GitHub Releases](https://github.com/dmdfami/noi/releases/latest).

## Đã xong

- App tự chứa (Swift + Node nhúng), DMG kéo vào Applications
- Landing + file tải HTTPS, nút tải khớp version
- Repo public MIT, không commit secret / script SSH nội bộ
- `packages/local-core`: `npm test`

## Notarize — chủ đích không làm

Không notarize. Đây là app mã nguồn mở phân phối ngoài App Store; người dùng cài bằng chuột phải → Mở. Landing đã nói rõ.

Lý do (quyết định 2026-08-14):

- **Developer ID + notarize cần Apple Developer Program**, phí ~$99 **mỗi năm** (gia hạn membership). Hết hạn thì không nộp bản mới lên notary được. Không đáng cho một dự án miễn phí.
- Đăng nhập Apple ID / Xcode trên máy **không** phải Developer ID Application. Máy này chỉ có cert local `ChatGPT Audio Local Code Signing` (tự ký, tới 2036).
- Cài OSS bằng chuột phải → Mở là đường chuẩn, không phải “hỏng”.

Nếu sau này đổi ý: cần membership đang hiệu lực, cert `Developer ID Application`, rồi `NOTARY_PROFILE=… ./scripts/make-dmg.sh`. Chi tiết kỹ thuật: [SHIP-PUBLIC.md](SHIP-PUBLIC.md).
