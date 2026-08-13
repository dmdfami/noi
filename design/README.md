# Design — ChatGPT Audio (macOS)

## Direction

Native macOS **utility**: menu bar + compact popover Home, Permissions as a sheet.  
Calm, translucent, system materials — not Electron, not purple AI chrome.

## Visual tokens

| Token | Choice |
|---|---|
| Material | `.ultraThinMaterial` / `.regularMaterial` panels |
| Accent | System blue (`Color.accentColor`) |
| Icons | SF Symbols only (`mic.fill`, `text.badge.checkmark`, `speaker.wave.2.fill`, `checkmark.circle.fill`) |
| Typography | System SF; title 13 semibold, body 12, captions 11 secondary |
| Spacing | 12–16 pt outer; 8 pt row gaps; 10 pt corner radius |
| Light / Dark | Automatic via system; no custom palette |

## Surfaces

1. **Home** (popover ~320×380) — backend online dot, STT/Correct/TTS ready rows + today’s usage, single-select profile radio, last result line, action buttons (Record / Correct / Speak), link to Permissions.
2. **Permissions** (sheet) — Mic / Accessibility / Input Monitoring status + Open System Settings, hotkey legend, optional secure token replace.

## HUD states (overlay or status line)

| State | Feedback |
|---|---|
| idle | Hidden / quiet |
| listening | Red pulse + “Listening…” |
| working | Spinner + “Transcribing…” / “Correcting…” / “Speaking…” |
| done | Brief check |
| error | One-line message (no stack traces) |

## Out of scope for design

Provider pickers, model menus, ChatGPT login, rebind hotkeys UI, design-system packages.
