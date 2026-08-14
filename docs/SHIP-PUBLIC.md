# Ship public (free app) — chuẩn Mac “tải về → cài”

## Trải nghiệm đúng chuẩn

```
User tải .dmg
  → double-click mở DMG
  → kéo app vào Applications
  → mở app từ Applications (không hộp thoại vàng)
```

Điều **bắt buộc** để đạt chuẩn đó: **Developer ID + Notarize** (Apple).  
Cert self-signed / ad-hoc (hiện tại) **không** đủ — Safari/Chrome gắn quarantine → Gatekeeper chặn.

## Checklist một lần (bạn làm trên Apple)

1. Đăng ký [Apple Developer Program](https://developer.apple.com/programs/) (~$99/năm).
2. Xcode → Settings → Accounts → Download **Developer ID Application** certificate.
3. Tạo App Store Connect API key (hoặc app-specific password) cho notary.
4. Lưu credentials:

```bash
xcrun notarytool store-credentials "AC_NOTARY" \
  --apple-id "you@email.com" \
  --team-id "TEAMID12" \
  --password "app-specific-password-or-api-key-setup"
```

(Hoặc dùng `--key` / `--key-id` / `--issuer` với file `.p8`.)

5. Xác nhận:

```bash
security find-identity -v -p codesigning | grep "Developer ID Application"
xcrun notarytool history --keychain-profile AC_NOTARY
```

## Build + ship (khi đã có cert)

```bash
# 1) Build .app
cd apps/macos-v2 && ./scripts/build-app.sh

# 2) DMG + notarize + staple
export CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export NOTARY_PROFILE="AC_NOTARY"
./scripts/make-dmg.sh

# 3) Host site/downloads/*.dmg + manifest.json trên HTTPS
# Landing: site/index.html → nút tải trỏ file .dmg
```

## Hiện trạng

| Hạng mục | Status |
|---|---|
| Repo public + landing + DMG | ✅ `https://noi.d92.uk` · `https://dl.d92.uk/Noi-1.0.1.dmg` |
| Self-contained `.app` | ✅ |
| DMG “kéo vào Applications” | ✅ `scripts/make-dmg.sh` |
| Developer ID cert trên máy build | ❌ chỉ có cert local (`ChatGPT Audio Local Code Signing`) |
| notarytool credentials | ❌ chưa store |
| Double-click sau tải web không cảnh báo | ❌ cần notarize |

## Tạm thời (beta / free chưa notarize)

- Zip + `Cai-dat.command` hoặc chuột phải → Mở  
- Landing phải nói rõ: bản beta, chưa notarize  

**Không** claim “tải về click cài như app Mac chuẩn” cho đến khi `manifest.notarized: true` và `spctl --assess` pass trên máy sạch.
