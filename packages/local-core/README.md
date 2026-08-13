# local-core — Nói (STT + Correct)

Core cục bộ chạy trong `Nói.app` (hoặc độc lập). Không phụ thuộc server nào của chúng tôi.

| Path | Provider | Credential |
|---|---|---|
| **STT** | ChatGPT Web `/backend-api/transcribe` (không chính thức) | `CHATGPT_ACCESS_TOKEN` |
| **Correct** (tuỳ chọn) | Google AI Studio | `GOOGLE_AI_STUDIO_API_KEY` |

## Quick start

```bash
node packages/local-core/cli.mjs serve
open http://127.0.0.1:8797/
```

Server bind **chỉ `127.0.0.1`**; không phát CORS (trang web ngoài không đọc được).

## Config (không dùng Keychain)

| File | Vai trò |
|---|---|
| `~/.config/chatgpt-audio/v2.env` | Secrets (mode 0600) |
| `~/.config/chatgpt-audio/v2.json` | Prefs: model, rotate, ngôn ngữ |

`v2.env`:

```bash
CHATGPT_ACCESS_TOKEN=…           # STT (đăng nhập trên menu bar)
GOOGLE_AI_STUDIO_API_KEY=…       # Sửa văn bản (tuỳ chọn)
LOCAL_CORE_TOKEN=…               # tự sinh cho client menu bar
```

Model sửa mặc định: **Gemma 4 26B** (`gemma-4-26b-a4b-it`) qua AI Studio. Chế độ: `single` (một model) hoặc `rotate` (xoay vòng để né giới hạn free tier).

## CLI

```bash
node cli.mjs status                              # có/không có credential (không in giá trị)
node cli.mjs catalog                             # provider cố định (chỉ AI Studio)
node cli.mjs set-env GOOGLE_AI_STUDIO_API_KEY=xxx
node cli.mjs correct "xin chao Clude"
node cli.mjs smoke                               # correct nếu có key
```

## API (localhost)

| Method | Path | Ghi chú |
|---|---|---|
| GET | `/healthz` | mở |
| GET | `/v1/bootstrap` | bootstrap UI + set cookie |
| GET | `/v1/status` | cờ ready (STT + correct) |
| GET | `/v1/catalog` | provider cố định (AI Studio) |
| GET | `/v1/models?provider=aistudio` | model live/khi có key |
| PUT | `/v1/config/secrets` | ghi env key |
| PUT | `/v1/config/prefs` | model / rotate / locale |
| POST | `/v1/audio/transcriptions` | STT |
| POST | `/v1/text/correct` | Correct |

Auth: loopback tin cậy; hoặc `Authorization: Bearer $LOCAL_CORE_TOKEN` / cookie same-origin.

## Test

```bash
npm test   # HTTP surface (loopback, secret hints, 0600), prompts locale
```
