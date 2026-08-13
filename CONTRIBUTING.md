# Góp ý & đóng góp cho Nói

Cảm ơn bạn quan tâm. Nói cố tình giữ **tối giản** — một việc: nói ra chữ trên Mac.

## Trước khi mở PR

- Giữ đúng phạm vi: STT (đăng nhập ChatGPT) là cốt lõi; sửa văn bản (Google AI Studio) là tuỳ chọn. **Không** thêm provider mới, TTS, hay marketplace.
- Không log audio, transcript, hay token.
- Diff nhỏ, gọn. Ưu tiên sửa đúng một vấn đề.

## Chạy & kiểm thử

```bash
cd packages/local-core && npm test   # test HTTP surface + prompts
npm start                            # thử UI tại http://127.0.0.1:8797
```

App macOS (`apps/macos-v2`) cần máy Mac + Xcode/CLT + Node standalone arm64 (nodejs.org) để build:

```bash
cd apps/macos-v2 && ./scripts/build-app.sh && ./scripts/verify-packaging.sh
```

## Kiểu code

- Node: thuần ESM, không thêm dependency nếu không thật cần (hiện tại là zero-dep).
- Swift: SwiftUI + AppKit, theo cấu trúc file hiện có.
- Không thêm comment thừa mô tả điều code đã tự nói.

## Báo lỗi

Mở [Issue](https://github.com/dmdfami/noi/issues) kèm: macOS + dòng máy, phiên bản Nói, các bước tái hiện. **Đừng** dán token/API key.

Lỗi bảo mật: xem [SECURITY.md](SECURITY.md).
