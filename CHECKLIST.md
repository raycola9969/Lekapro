# Kiểm tra thiết bị

- [ ] Cài bản đã ký lên iPhone iOS 18+ và mở app.
- [ ] Tạo hồ sơ A, B; đăng nhập website thử nghiệm trong A, kiểm tra B không đăng nhập.
- [ ] Mở hai tab trong A, kiểm tra cùng cookie/storage.
- [ ] Tắt app, mở lại: khôi phục đúng tab và cookie của từng hồ sơ.
- [ ] Nhân bản A: hồ sơ mới không mang phiên đăng nhập A.
- [ ] Kiểm tra SOCKS5/HTTP/HTTPS CONNECT bằng proxy do bạn quản lý, có/không xác thực.
- [ ] Bấm kiểm tra IP: IP đúng với proxy; dừng proxy: trang báo lỗi và không tải trực tiếp.
- [ ] Đo lưu lượng DNS/UDP riêng, không suy ra từ IP hiển thị.
- [ ] Nhập cookie JSON và Netscape, xuất lại và so sánh secure/httpOnly/expiration.
- [ ] Xóa A, kiểm tra dữ liệu B còn nguyên.
- [ ] Nhập bản sao lưu: UUID mới, nhập lại mật khẩu proxy; không mất hồ sơ hiện tại.
- [ ] Bật/tắt chặn Canvas/Audio/WebRTC, kiểm tra lỗi API và khả năng tương thích.
- [ ] Thử tải file, popup, back/forward, JavaScript alert/confirm/prompt.
- [ ] Kiểm tra iPad, xoay màn hình, bàn phím, file chia sẻ.

Kết quả kiểm thử CI nằm ở Actions artifact `build-diagnostics`. Checklist này chỉ ghi các việc cần kiểm tra, không khẳng định đã đạt.
