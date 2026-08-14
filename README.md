# Nói

**Nói ra chữ trên Mac — bằng tài khoản ChatGPT của bạn.** Miễn phí, mã nguồn mở.

Giữ **⌃⌥** (Control+Option), nói, thả ra — chữ hiện ngay tại con trỏ trong bất kỳ app nào. Tuỳ chọn: chạm đôi **⌥** để sửa chính tả phần đang chọn bằng một API key Google AI Studio miễn phí.

- Trang chủ / tải về: **https://noi.d92.uk**
- Nền tảng: macOS 13+, **Apple Silicon** (chưa hỗ trợ Intel)
- Không server trung gian — mọi thứ chạy trên máy bạn.

> **Về STT:** Nói dùng phiên đăng nhập ChatGPT web của bạn qua một endpoint **không chính thức**. Nó có thể thay đổi/ngừng chạy khi OpenAI cập nhật. Đây là công cụ cá nhân, không phải sản phẩm của OpenAI.

---

## Cài đặt (người dùng)

Xem hướng dẫn đầy đủ: **[docs/INSTALL-MACOS.md](docs/INSTALL-MACOS.md)** (không cần Terminal).

1. Tải `Noi-1.0.3.dmg` từ [tải trực tiếp](https://dl.d92.uk/Noi-1.0.3.dmg) hoặc [noi.d92.uk](https://noi.d92.uk).
2. Mở DMG → kéo **Nói** vào Applications.
3. Cấp quyền **Micro** + **Accessibility**, đăng nhập ChatGPT trong app.
4. Giữ **⌃⌥** để nói. Chạm đôi **⌥** để sửa (cần key AI Studio). **Esc** để dừng.

| Hotkey | Việc |
|---|---|
| Giữ / chạm đôi **⌃⌥** | Nói → chữ tại con trỏ |
| Chạm đôi **⌥** | Sửa văn bản đang chọn (tuỳ chọn) |
| **Esc** | Dừng |

Riêng tư: **[PRIVACY.md](PRIVACY.md)** · Hỗ trợ: **[SUPPORT.md](SUPPORT.md)** · Thay đổi: **[CHANGELOG.md](CHANGELOG.md)**

---

## Kiến trúc

```
Hotkeys · mic · dán (Swift, apps/macos-v2)
        │  HTTP 127.0.0.1:8797 (loopback)
        ▼
packages/local-core (Node nhúng trong .app)
        │
        ▼
ChatGPT web (STT) · Google AI Studio (sửa, tuỳ chọn)
```

- **STT:** phiên ChatGPT web (đăng nhập trong app, token lưu ở `~/.config/chatgpt-audio/v2.env`, mode 0600).
- **Sửa:** Google AI Studio, dùng key của bạn. Có thể xoay vòng vài model để né giới hạn free tier.
- Core cục bộ bind **chỉ `127.0.0.1`**; trang web ngoài không đọc được (không phát CORS).

## Dành cho developer

```bash
# Core cục bộ (không cần app)
cd packages/local-core && npm start        # http://127.0.0.1:8797
npm test                                    # test HTTP surface + prompts

# Build app macOS (cần máy Mac + Xode/CLT + Node standalone arm64 từ nodejs.org)
cd apps/macos-v2
CHATGPT_AUDIO_NODE_BIN=/path/node-v22-darwin-arm64/bin/node ./scripts/build-app.sh
./scripts/verify-packaging.sh              # kiểm tra .app đã cài

# Đóng DMG cho phát hành
cd ../.. && SHIP_VERSION=1.0.3 ./scripts/make-dmg.sh
```

Ship trên máy này: **[docs/SHIP-MAC.md](docs/SHIP-MAC.md)** (`SHIP_VERSION=x.y.z ./scripts/ship-release.sh`). Đóng gói: **[docs/V2-SINGLE-APP-PACKAGING.md](docs/V2-SINGLE-APP-PACKAGING.md)** · **[docs/SHIP-PUBLIC.md](docs/SHIP-PUBLIC.md)** · **[docs/SHIP-READINESS.md](docs/SHIP-READINESS.md)**.

Góp ý / đóng góp: **[CONTRIBUTING.md](CONTRIBUTING.md)** · Bảo mật: **[SECURITY.md](SECURITY.md)**.

## Nguyên tắc

1. Một việc, làm tốt: nói → ra chữ.
2. Chạy được ngay sau khi đăng nhập — không bắt cấu hình.
3. Không marketplace provider. Sửa văn bản chỉ cần một key AI Studio miễn phí.
4. Không log audio, transcript, hay token.
5. Dữ liệu ở trên máy bạn.

---

# Nói — speak, get text on Mac

**Turn speech into text on your Mac using your own ChatGPT account.** Free and open source.

Hold **⌃⌥**, speak, release — the text appears at your cursor in any app. Optionally double-tap **⌥** to fix the selected text with a free Google AI Studio key.

- Website / download: **https://noi.d92.uk**
- Platform: macOS 13+, **Apple Silicon only**
- No middle server — everything runs on your machine.

> **About STT:** Nói uses your ChatGPT web session via an **unofficial** endpoint. It may break when OpenAI changes things. This is a personal tool, not an OpenAI product.

Install: download `Noi-1.0.3.dmg` → drag **Nói** to Applications → grant Microphone + Accessibility → sign in to ChatGPT → hold **⌃⌥** to dictate. See **[docs/INSTALL-MACOS.md](docs/INSTALL-MACOS.md)**.

MIT licensed — see [LICENSE](LICENSE).

Nói turns speech into text using your own ChatGPT web session (an unofficial endpoint) and, optionally, your own Google AI Studio API key. Your use of those third-party services is governed by their own terms; the MIT license covers only the Nói source code.
