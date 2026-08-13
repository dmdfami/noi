# Roadmap — branch topics

Keep **main** shippable. Open **new topic branches** for the items below.

## Suggested branches

| Branch idea | Goal |
|---|---|
| `feat/correct-latency` | Measure and cut correct path 3–10s → closer to AI Gateway 1–1.5s (HTTP, serialization, selection AX) |
| `feat/correct-quality` | T4 facts product UX, better demotion of ungrounded claims, optional backend system prompt |
| `feat/tts-stream` | Stream or progressive play if backend supports; else local decode latency |
| `feat/windows-ui` | Windows shell parity |
| `feat/prompt-lab-v2` | More fixtures, CI gate on lang_ok for VI |
| `feat/v2-local-providers` | **Shipped skeleton:** `packages/local-core` + web UI + `apps/macos-v2` (see `docs/V2-LOCAL.md`) |
| `feat/local-byo-polish` | Rotate UX, OAuth helpers, voice picker, Windows v2 shell |

## Do not re-open on main without explicit scope

- Multi-provider marketplace  
- Billing UI  
- Auto Keychain promote on every launch  

## How to continue

```bash
git checkout main && git pull
git checkout -b feat/<topic>
# … implement against docs/PRODUCT.md + docs/ARCHITECTURE.md
```
