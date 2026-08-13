# Hotkeys (mặc định)

Platform: tên phím macOS.

| Việc | Thao tác | Ghi chú |
|---|---|---|
| **Nói (STT)** | **Giữ Control+Option** | Push-to-talk: ghi âm khi giữ (≥ ~180ms); thả → upload → dán |
| **Nói (STT)** | **Chạm đôi Control+Option** | Toggle trong ~400ms (nói dài, rảnh tay) |
| **Sửa** | **Chạm đôi Option** | Sửa văn bản đang chọn (cần key AI Studio). Đích: vùng chọn → cả field → clipboard (CLI) |
| **Dừng** | **Escape** | Huỷ ghi âm, dừng sửa |
| **Dừng khi bận** | **Bấm lại cùng hotkey** | ⌥⌥ lần nữa khi đang bận → huỷ |

Bare Control **không** phải hotkey (TTS đã bỏ) — nên **Ctrl+C / Ctrl+V** vẫn bình thường.

### Cách xác định văn bản đích (Sửa)

1. **AX selection** nếu đang bôi đen trong editor.
2. Nếu không → **clipboard** nếu khác rỗng.
3. Nếu không → **field đang focus** (`AXTextField`/`AXTextArea`), không lấy scrollback terminal.
4. **Không** dùng Cmd+C giả lập.

Ghi kết quả: dán vào vùng chọn/field; nếu chỉ có clipboard → kết quả nằm trên pasteboard (Cmd+V).

## Trọng tài phím

1. Chord Control+Option làm chủ STT (giữ hoặc chạm đôi); chặn chạm đôi bare Option trong lần bấm đó.
2. Giữ ≥ ~180ms → bắt đầu STT; thả → kết thúc.
3. Chạm đôi chord trong ~400ms → toggle STT.
4. Có phím khác trong lúc giữ → huỷ đếm double-tap.
5. Single-flight: mỗi lúc chỉ một tác vụ STT/sửa.

## HUD

| Trạng thái | UI |
|---|---|
| idle | Ẩn |
| listening | Chấm đỏ + Đang nghe |
| working | Spinner + Đang chuyển / Đang sửa |
| done | Dấu tick nhanh |
| error | Một dòng lỗi |

## Ghi chú (macOS)

- `NSEvent` global monitor cho phím bổ trợ (`HotKeyMonitor` trong `apps/macos-v2`).
