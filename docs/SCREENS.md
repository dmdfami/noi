# Screens — Audio Local v3 (macOS)

Design tokens: [`design/tokens.md`](../design/tokens.md)

## 1. Menu bar popover (primary)

Click the **waveform** status item → `NSPopover` (not a flat NSMenu).

```
┌──────────────────────────────┐
│ Audio Local          Ready   │
│ STT ready · Fix optional     │
├──────────────────────────────┤
│ ⌃⌥  Hold / double-tap dictate│
│ ⌥⌥  Double-tap · fix         │
│ ⌃⌃  Double-tap · speak       │
├──────────────────────────────┤
│ Sign in / Switch ChatGPT     │
│ Permissions · ● Mic ● Ax ○ … │
│ Settings…                    │
│ Stop (Esc)   [when busy]     │
├──────────────────────────────┤
│ ☐ Auto-fix after STT       │
│ ☐ Open at login              │
├──────────────────────────────┤
│ Quit Audio Local             │
└──────────────────────────────┘
```

- Template SF Symbol; orange badge when permissions incomplete
- Daily use = hotkeys + this popover

## 2. Permissions onboarding

Native window: 3 step cards (Mic · Accessibility · Input Monitoring), progress, success → “hold ⌃⌥”.

## 3. ChatGPT login

Standard titled window + Cancel; WKWebView; auto token capture.

## 4. Settings (in-app WebView)

**Single page** at `http://127.0.0.1:8797/` — not a 3-tab dashboard:

1. Compact STT / TTS / Fix status  
2. Sign in ChatGPT CTA  
3. Hotkey strip  
4. Collapsed **Text fix (optional)**  
5. Collapsed **How it fixes**  
6. VI | EN segment  

## 5. Floating HUD

Bottom capsule: SF Symbol + label + Esc. System material (popover).

## Visual tone

macOS hybrid: SF Pro / system materials native; web Settings uses `-apple-system` + light/dark adaptive — no marketing display fonts.
