# Final UI/UX — Audio Local v3

## Intent

Production macOS utility: hotkey-first, native popover shell, minimal Settings WebView.

Tokens: [`design/tokens.md`](tokens.md). Screens: [`docs/SCREENS.md`](../docs/SCREENS.md).

## Surfaces

| Surface | Role |
|---|---|
| **Status item + popover** | Waveform icon; Ready sheet with hotkeys, account, permissions, settings, quit |
| **Permissions** | Native 3-step onboarding |
| **Login** | Standard window + WKWebView |
| **Settings WebView** | Single page: status + login + collapsed Correct / How it fixes |
| **HUD** | Bottom capsule |

## Normal launch

- `.accessory` (menu bar only)
- First-run: permissions + Settings WebView once
- Config stays in-app (no external browser)

## Supersedes

v2 polish pass (flat NSMenu + 3-tab dashboard) — see `docs/DESIGN-PROMPT-CURSOR.md`.
