# Bảo mật — Nói

## Báo lỗi bảo mật

Tìm thấy lỗ hổng? Vui lòng **không** mở Issue công khai. Báo riêng qua:

- GitHub Security Advisory: tab **Security → Report a vulnerability** của repo, hoặc
- Email: `security@d92.uk`

Nêu rõ: mô tả, cách tái hiện, và tác động. Chúng tôi phản hồi sớm nhất có thể.

## Mô hình bảo mật

- **Bind loopback:** core cục bộ chỉ nghe `127.0.0.1:8797`. Máy khác trong LAN không truy cập được.
- **Không CORS:** API không phát `access-control-allow-origin`, nên trang web ở origin khác không đọc được secret/không kích hoạt được STT/sửa.
- **Secret trên máy:** token ChatGPT + key AI Studio lưu ở `~/.config/chatgpt-audio/v2.env` (mode 0600). Không đẩy lên đâu.
- **Giới hạn đã biết:** mọi tiến trình chạy dưới cùng user trên máy đều có thể gọi API cục bộ (mô hình "một người dùng, máy tin cậy"). Không dùng trên máy chia sẻ với người bạn không tin.
- **Không log** audio, transcript, hay token.

## Phạm vi

Nói dùng phiên ChatGPT web (không chính thức) cho STT và key Google AI Studio của bạn cho phần sửa. Vấn đề của các dịch vụ bên thứ ba đó không thuộc phạm vi repo này.
