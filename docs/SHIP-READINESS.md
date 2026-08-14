# Ship readiness

Bản công khai hiện tại: **1.0.1** — [noi.d92.uk](https://noi.d92.uk) · [dl.d92.uk/Noi-1.0.1.dmg](https://dl.d92.uk/Noi-1.0.1.dmg) · [GitHub Releases](https://github.com/dmdfami/noi/releases/latest).

## Đã xong

- App tự chứa (Swift + Node nhúng), DMG kéo vào Applications
- Landing + file tải HTTPS, nút tải khớp version
- Repo public MIT, không commit secret / script SSH nội bộ
- `packages/local-core`: `npm test`

## Còn một việc (cần tài khoản Apple Developer)

**Notarize** — máy build hiện **không** có `Developer ID Application` hay profile `notarytool`. Không notarize được cho đến khi:

1. Đăng ký [Apple Developer Program](https://developer.apple.com/programs/) (~$99/năm)
2. Cài cert Developer ID Application trên máy build
3. `xcrun notarytool store-credentials`
4. `CODESIGN_IDENTITY="Developer ID Application: …" NOTARY_PROFILE=AC_NOTARY ./scripts/make-dmg.sh`

Cho đến lúc đó landing nói đúng: bản chưa notarize, lần đầu chuột phải → Mở. Chi tiết: [SHIP-PUBLIC.md](SHIP-PUBLIC.md).
