# Ship Nói trên Mac này — đừng dò lại

Runbook máy `david-m1max`. Secret **không** nằm trong repo.

## Tài khoản Apple (đã mua)

| | |
|---|---|
| Apple Developer Program | acc **`mpminhngoc@gmail.com`** (không phải `dmd.fami@icloud.com` trên máy) |
| Team | **DUC DO MANH** · Team ID **`P9U773F44F`** · Individual, Admin |
| Membership | ~$99/năm — hết hạn thì **không notarize được bản mới**; app user đã cài vẫn chạy |
| Cert Developer ID Application | `Developer ID Application: DUC DO MANH (P9U773F44F)` · G2 · **tới 2031-08-15** |
| Notary / ASC API | Team key **`noi-notary`** · Key ID **`77WV95ZDHA`** · Admin · **không hết hạn** · Issuer `16b5eb80-c1e4-49e6-b321-119e2bc0dbad` |
| notarytool profile | `AC_NOTARY` (Keychain) |

Login Xcode ≠ đã có Developer ID. Cert phải tạo một lần (portal Certificates → Developer ID Application + CSR). PLA mới phải **Agree** trên [developer.apple.com/account](https://developer.apple.com/account) không thì Xcode báo `PLA Update available`.

API key `.p8` **chỉ tải được một lần**. Đã lưu Infisical + `~/.config/noi/`. Đừng Generate lại trừ khi mất file.

## Secret ở đâu (không commit)

| Chỗ | Nội dung |
|---|---|
| `~/.config/noi/apple.env` | biến `APPLE_*` + `NOTARY_PROFILE` (mode 0600) |
| `~/.config/noi/developer-id/` | `.cer` `.key` `.p12` `.p8` CSR |
| Infisical project machine (`cf-god-machine.env`, env `prod`) | `APPLE_ID` `APPLE_TEAM_ID` `APPLE_API_KEY_ID` `APPLE_API_ISSUER_ID` `APPLE_API_KEY_P8` `APPLE_CODESIGN_IDENTITY` … |
| Keychain login | identity Developer ID + profile `AC_NOTARY` |

Cloudflare Pages/R2: **không** dùng `CLOUDFLARE_API_TOKEN` trong `v2.env` (token AI hẹp). Dùng `CLOUDFLARE_GLOBAL_API_KEY` + `CLOUDFLARE_EMAIL` từ Infisical; wrangler nhận `CLOUDFLARE_API_KEY`.

## Hosting

| URL | Backend |
|---|---|
| https://noi.d92.uk | Pages project **`noi`** (`noi-ayp.pages.dev`) |
| https://dl.d92.uk/Noi-\<ver\>.dmg | R2 bucket **`noi-dl`** · custom domain `dl.d92.uk` · cache 4h |

Nút tải trên landing là **href cứng**. Đổi version thì phải đổi `site/index.html` + nhãn size. Deploy Pages **không** kèm file `.dmg`.

## Một lệnh ship

```bash
cd ~/dev/noi
SHIP_VERSION=x.y.z ./scripts/ship-release.sh
```

Script: build `.app` → DMG + notarize + staple → R2 → Pages → purge cache → gợi ý `gh release`.

Thủ công:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
set -a; source ~/.config/noi/apple.env; set +a
cd ~/dev/noi/apps/macos-v2 && ./scripts/build-app.sh
cd ../..
SHIP_VERSION=x.y.z CODESIGN_IDENTITY="$APPLE_CODESIGN_IDENTITY" \
  NOTARY_PROFILE=AC_NOTARY ./scripts/make-dmg.sh
```

Lần đầu `codesign` trên máy mới: hộp thoại Keychain → mật khẩu Mac → **Luôn Cho phép**.

## Verify bắt buộc trước khi nói “đã ship”

```bash
xcrun stapler validate site/downloads/Noi-<ver>.dmg
# mount DMG rồi:
spctl --assess --type execute -vv /Volumes/…/Noi.app
# phải: accepted / source=Notarized Developer ID
```

Live: curl **có User-Agent trình duyệt** (urllib Python bị CF 403). Tải DMG, so `sha256` với `site/downloads/manifest.json`. Purge `dl.d92.uk` + `noi.d92.uk` sau khi ghi đè cùng tên file.

## App khác trên Mac này

Cùng team/cert/API key. Đổi `bundle id` / entitlements. Không tạo cert Developer ID mới trừ khi hết hạn 2031. Không Generate API key mới trừ khi mất `.p8`.
