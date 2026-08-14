# Ship readiness

Bản công khai hiện tại: **1.0.1** — [noi.d92.uk](https://noi.d92.uk) · [dl.d92.uk/Noi-1.0.1.dmg](https://dl.d92.uk/Noi-1.0.1.dmg) · [GitHub Releases](https://github.com/dmdfami/noi/releases/latest).

## Đã xong

- App tự chứa (Swift + Node nhúng), DMG kéo vào Applications
- Landing + file tải HTTPS, nút tải khớp version
- Repo public MIT, không commit secret / script SSH nội bộ
- `packages/local-core`: `npm test`

## Notarize — đã bật (2026-08-14)

Bản `1.0.1` trên [dl.d92.uk](https://dl.d92.uk/Noi-1.0.1.dmg) ký **Developer ID Application: DUC DO MANH (P9U773F44F)** và đã notarize + staple. Gatekeeper: `accepted / Notarized Developer ID`.

Ship lại DMG:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
set -a; source ~/.config/noi/apple.env; set +a
cd ~/dev/noi
SHIP_VERSION=x.y.z CODESIGN_IDENTITY="$APPLE_CODESIGN_IDENTITY" NOTARY_PROFILE=AC_NOTARY ./scripts/make-dmg.sh
```

Cert Developer ID tới **2031-08-15**. API key App Store Connect `noi-notary` không hết hạn (Infisical + `~/.config/noi/apple.env`). Membership Apple vẫn cần gia hạn ~$99/năm nếu muốn notarize bản *mới* sau khi hết hạn hội viên.

Runbook đầy đủ trên máy này: **[SHIP-MAC.md](SHIP-MAC.md)**. Chi tiết kỹ thuật chung: [SHIP-PUBLIC.md](SHIP-PUBLIC.md).
