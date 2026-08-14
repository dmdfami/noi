# Cài Nói trên MacBook

Không cần Terminal, không cần cài Node, không cần git. App gói sẵn mọi thứ.

| Yêu cầu | |
|---|---|
| macOS | 13 Ventura trở lên |
| Máy | MacBook **Apple Silicon** (M1/M2/M3/M4) — chưa hỗ trợ Intel |
| Tài khoản | ChatGPT (gói nào cũng được, kể cả free) |
| Dung lượng | ~120 MB |

## 1. Tải & cài

1. Tải **`Noi-1.0.1.dmg`** từ [noi.d92.uk](https://noi.d92.uk) hoặc [tải trực tiếp](https://dl.d92.uk/Noi-1.0.1.dmg).
2. Mở DMG → kéo **Nói** vào thư mục **Applications**.
3. Mở Nói từ Applications.

> **Lần đầu macOS báo "chưa được mở"?** Bản này chưa được Apple notarize. **Chuột phải vào Nói → Mở → Mở** (chỉ lần đầu). Không phải virus — mã nguồn mở, xem được toàn bộ trên GitHub. (Nếu tải bản `.zip`, double-click `Cai-dat.command` để tự gỡ cờ chặn.)

## 2. Cấp 3 quyền hệ thống

Lần đầu mở, Nói hiện cửa sổ **Quyền** với 3 dòng. Bấm nút bên cạnh từng dòng, macOS mở đúng trang System Settings — bật công tắc cho **Nói**:

| Quyền | Để làm gì | Không cấp thì |
|---|---|---|
| **Microphone** | Ghi âm khi bạn giữ ⌃⌥ | Không nói được |
| **Accessibility** | Đọc phần đang chọn, chèn kết quả tại con trỏ | Không dán/không sửa được |
| **Input Monitoring** | Nhận hotkey toàn hệ thống, dán vào Terminal | Hotkey không chạy |

Một số trang System Settings yêu cầu **thoát và mở lại app** sau khi bật.

## 3. Đăng nhập ChatGPT

1. Bấm biểu tượng **Nói** trên menu bar (góc trên phải) → **Cài đặt**.
2. Bấm **Đăng nhập…** → đăng nhập ChatGPT như trên web.
3. Trạng thái đổi thành **Đã đăng nhập** kèm email. Đổi tài khoản: bấm **Đổi tài khoản…**.

Phiên đăng nhập nằm trên máy bạn. App không gửi mật khẩu đi đâu, không có server trung gian.

## 4. Dùng hàng ngày

| Hotkey | Việc |
|---|---|
| Giữ **Control+Option** (hoặc chạm đôi) | Nói → nhả ra → chữ dán tại con trỏ |
| Chạm đôi **Option** | Sửa văn bản đang chọn (cần key AI Studio) |
| **Esc** | Dừng |

Thời gian chờ thường 1–5 giây; app hiện HUD nhỏ khi đang xử lý.

## 5. Tuỳ chọn: bật Sửa văn bản

1. **Cài đặt → Sửa văn bản (tuỳ chọn)**.
2. Lấy key miễn phí tại [Google AI Studio](https://aistudio.google.com/apikey), dán vào ô key → **Lưu**.
3. Bấm **Thử sửa một câu** để kiểm tra. Bật **Xoay vòng model** nếu muốn trải đều giới hạn free tier.

Key chỉ nằm ở `~/.config/chatgpt-audio/v2.env` (quyền 0600).

## Gặp sự cố

| Hiện tượng | Cách xử lý |
|---|---|
| Không thấy app | Nói chạy trên **menu bar**, không có ở Dock. Tìm biểu tượng góc trên phải. |
| Hotkey không phản hồi | Thiếu **Input Monitoring**. Bật lại rồi thoát/mở lại app. |
| Chữ không được dán | Thiếu **Accessibility**. Terminal/iTerm cần thêm **Input Monitoring**. |
| "Cần đăng nhập ChatGPT" | Làm lại bước 3; token hết hạn → **Đổi tài khoản…**. |
| Sửa báo thiếu key | Chưa dán key AI Studio — xem bước 5. |
| Kẹt ở "Cần đăng nhập" / trang trắng | Cổng 8797 bị chiếm (thường do bản dev đang chạy). Thoát bản kia rồi mở lại. |

## Cập nhật / Xoá

- **Cập nhật:** tải DMG mới, kéo đè vào Applications. Cấu hình + đăng nhập giữ nguyên.
- **Xoá:** menu bar → Thoát → xoá `Nói.app` khỏi Applications → xoá `~/.config/chatgpt-audio` → bỏ app khỏi System Settings → Privacy & Security.

---

# English — install Nói

Requirements: macOS 13+, **Apple Silicon only**, a ChatGPT account, ~120 MB.

1. Download `Noi-1.0.1.dmg` from [noi.d92.uk](https://noi.d92.uk) or GitHub Releases; open it and drag **Nói** to Applications. First launch: right-click → Open → Open (not notarized yet).
2. Grant three permissions in the first-run window: **Microphone** (record while holding ⌃⌥), **Accessibility** (read selection, insert result), **Input Monitoring** (global hotkeys, pasting into Terminal). Some panes need an app restart.
3. Menu bar icon → **Settings** → **Sign in…** to ChatGPT. Required for dictation. Use **Switch account…** to change accounts.
4. Hold **⌃⌥** to dictate, double-tap **⌥** to fix the selected text (needs an AI Studio key), **Esc** to stop.
5. Optional text fixing: Settings → paste a free [Google AI Studio](https://aistudio.google.com/apikey) key → Save.

Nói is menu-bar only (no Dock icon). Keys and the ChatGPT session stay in `~/.config/chatgpt-audio/`. Uninstall: quit from the menu bar, delete `Nói.app`, delete `~/.config/chatgpt-audio`, and remove it from the privacy panes in System Settings.
