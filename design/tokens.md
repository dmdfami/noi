# Audio Local v3 — design tokens

Hybrid macOS production: native shell first; web Settings inherits system look.

## Native (prefer semantic system colors)

| Role | Native API |
|---|---|
| Primary text | `NSColor.labelColor` / SwiftUI `.primary` |
| Secondary | `NSColor.secondaryLabelColor` / `.secondary` |
| Separators | `NSColor.separatorColor` |
| Controls | `NSColor.controlBackgroundColor` |
| Accent (sparse) | Indigo `#6C7CFF` — primary buttons / active only |
| Ready | `NSColor.systemGreen` |
| Warn / setup badge | `NSColor.systemOrange` |

## Web Settings (adaptive)

| Token | Light | Dark | CSS |
|---|---|---|---|
| Background | `#F5F5F7` | `#1C1C1E` | `--bg` |
| Surface | `#FFFFFF` | `#2C2C2E` | `--surface` |
| Text | `#1D1D1F` | `#F5F5F7` | `--text` |
| Mute | `#6E6E73` | `#98989D` | `--mute` |
| Line | `#D2D2D7` | `#3A3A3C` | `--line` |
| Accent | `#6C7CFF` | `#6C7CFF` | `--accent` |
| Ready | `#34C759` | `#30D158` | `--ready` |

Fonts: `-apple-system, system-ui, "SF Pro Text", sans-serif` only — no Fraunces / marketing display faces.

Radius: 8px controls, 12px cards, 20px pills.

## SF Symbol map

| Context | Symbol |
|---|---|
| Menu bar idle | `waveform` |
| Listening | `mic.fill` |
| Working | `ellipsis.circle` |
| Error | `exclamationmark.triangle.fill` |
| Setup badge | orange 8pt overlay |
| Mic / AX / Keys | `mic.fill`, `accessibility`, `keyboard` |
| HUD | `mic.fill`, `waveform`, `wand.and.stars`, `speaker.wave.2.fill`, `checkmark.circle.fill`, `stop.circle`, `exclamationmark.circle.fill` |

## Brand

User-facing: **Audio Local**. Bundle name unchanged.
