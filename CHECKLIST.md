# Kiểm tra thiết bị

- [x] Cài bản 0.2.0 (build 5) lên iPhone 11 Pro Max iOS 16.1.1 bằng TrollStore và mở app.
- [x] Đọc Documents/Lekapro-device-check.json; kết thúc tiến trình rồi mở lại, xác nhận cookie, localStorage và IndexedDB đều cách ly và persisted. Báo cáo: verification/ios-16.1.1-storage.json.
- [ ] Tạo hồ sơ A, B; đăng nhập website thử nghiệm trong A, kiểm tra B không đăng nhập.
- [ ] Mở hai tab trong A, kiểm tra cùng cookie/storage.
- [ ] Tắt app, mở lại: khôi phục đúng tab và cookie của từng hồ sơ.
- [ ] Nhân bản A: hồ sơ mới không mang phiên đăng nhập A.
- [ ] Kiểm tra SOCKS5/HTTP/HTTPS CONNECT bằng proxy do bạn quản lý, có/không xác thực.
- [x] Hai hồ sơ thật: SOCKS5 có xác thực trả IP khác hồ sơ trực tiếp; mở hồ sơ proxy không đổi IP của hồ sơ trực tiếp. Cookie và localStorage riêng.
- [x] SOCKS5 tại cổng thử không có máy chủ: WebKit báo lỗi, không tải dịch vụ kiểm tra IP trực tiếp trong phép thử này.
- [ ] Bấm kiểm tra IP: IP đúng với proxy; dừng proxy: trang báo lỗi và không tải trực tiếp.
- [ ] Đo lưu lượng DNS/UDP riêng, không suy ra từ IP hiển thị.
- [ ] Nhập cookie JSON và Netscape, xuất lại và so sánh secure/httpOnly/expiration.
- [ ] Xóa A, kiểm tra dữ liệu B còn nguyên.
- [ ] Nhập bản sao lưu: UUID mới, nhập lại mật khẩu proxy; không mất hồ sơ hiện tại.
- [ ] Bật/tắt chặn Canvas/Audio/WebRTC, kiểm tra lỗi API và khả năng tương thích.
- [ ] Thử tải file, popup, back/forward, JavaScript alert/confirm/prompt.
- [ ] Kiểm tra iPad, xoay màn hình, bàn phím, file chia sẻ.

Kết quả kiểm thử CI nằm ở Actions artifact `build-diagnostics`. Chỉ các mục có dấu [x] đã được kiểm tra; các mục còn lại cần kiểm thử tiếp.
