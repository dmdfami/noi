# Quyền riêng tư — Nói

Bản mô tả đúng theo mã nguồn trong repo này. Cập nhật khi luồng dữ liệu thay đổi.

## Tóm tắt

Nói chạy trên máy bạn và nói chuyện trực tiếp với dịch vụ bạn dùng. Không có server của chúng tôi ở giữa, không analytics, không crash reporting, không có tài khoản riêng của app.

## Dữ liệu đi đâu

| Bạn làm gì | Dữ liệu gửi đi | Gửi tới |
|---|---|---|
| Giữ ⌃⌥ để nói | Đoạn ghi âm | ChatGPT web, bằng phiên đăng nhập của bạn |
| Chạm đôi ⌥ để sửa (tuỳ chọn) | Văn bản đang chọn | Google AI Studio, bằng API key của bạn |
| Mở Cài đặt | Không có gì ra ngoài | Trang web chạy tại `127.0.0.1:8797` trên máy bạn |

Không dùng hotkey thì không có dữ liệu nào rời khỏi máy.

## Lưu gì trên máy

| Đường dẫn | Nội dung | Quyền |
|---|---|---|
| `~/.config/chatgpt-audio/v2.env` | Token phiên ChatGPT, API key AI Studio, token cục bộ | `0600` |
| `~/.config/chatgpt-audio/v2.json` | Lựa chọn model, ngôn ngữ, tuỳ chọn | `0600` |

Không có lịch sử transcript, không database, không log nội dung.

## Không thu thập

- Không analytics, telemetry, hay định danh thiết bị.
- Không log audio, transcript, văn bản đã sửa, hay token.
- Không tự động gửi báo cáo lỗi.
- App không có tài khoản riêng — chỉ dùng phiên ChatGPT + key AI Studio của bạn.

## Quyền hệ thống

| Quyền | Dùng để |
|---|---|
| Microphone | Ghi âm **chỉ khi** bạn giữ/kích hoạt hotkey nói |
| Accessibility | Đọc phần văn bản đang chọn và chèn kết quả tại con trỏ |
| Input Monitoring | Nhận hotkey toàn hệ thống và dán vào ứng dụng terminal |

Không ghi âm nền, không keylogger: bộ theo dõi hotkey chỉ nhìn phím bổ trợ (Control/Option) để bật/tắt chức năng.

## Server cục bộ

Nói mở một HTTP server bind **chỉ `127.0.0.1`** (cổng 8797) cho giao diện Cài đặt. Máy khác trong LAN không truy cập được; trang web ở origin khác cũng không đọc được (server không phát `access-control-allow-origin`). Lưu ý: mọi chương trình chạy dưới cùng tài khoản trên máy bạn đều có thể gọi API cục bộ này — mô hình "một người dùng, máy tin cậy".

## Bên thứ ba

Dữ liệu bạn gửi đi chịu chính sách của: OpenAI (ChatGPT — dùng qua phiên web **không chính thức**) và Google (AI Studio). Bạn tự quyết định đăng nhập/nhập key.

## Xoá dữ liệu

Xoá thư mục `~/.config/chatgpt-audio` là hết token, key và cấu hình. Muốn thu hồi quyền truy cập ChatGPT: đăng xuất phiên trong tài khoản ChatGPT của bạn.
