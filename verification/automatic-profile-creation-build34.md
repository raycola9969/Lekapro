# Tạo và kiểm tra hồ sơ tự động từ proxy — build 34

## Cách dùng

1. Trong **Hồ sơ**, bấm **+**. Hoặc vào **Kho proxy → Tạo hồ sơ từ proxy**.
2. Chọn SOCKS5 hoặc HTTP CONNECT, dán `host:port:user:pass`; mỗi proxy một dòng. IPv6 dùng `[địa chỉ]:port:user:pass`. Có thể dán tối đa 20 dòng; dòng trùng cả endpoint và mật khẩu được gộp. Mật khẩu có dấu `:` được giữ nguyên.
3. Bấm **Tạo hồ sơ** một lần và giữ app ở màn hình trước. Không cần nhập tên hồ sơ, chọn UA, đặt múi giờ, mở Fingerprint hoặc bấm kiểm tra từng hồ sơ.
4. Kết thúc, bấm **Đóng** để dùng những hồ sơ đã đạt trong danh sách.

App tự lưu proxy vào Keychain, tạo kho website mới, đặt múi giờ theo IP, đo Fingerprint và tải lại để xác nhận. ID chưa nằm trong lịch sử Lekapro → giữ hồ sơ, ghi ID vào ledger và dừng thử cho proxy đó. ID trùng → xóa ứng viên cùng dữ liệu website rồi thử UA iPhone kế tiếp. Tối đa **3 lượt/proxy**, theo thứ tự Safari iOS 17.2, Chrome iOS 17.4 và Firefox iOS 17.5. Đây là UA, WebKit và hệ điều hành thật vẫn theo iPhone.

Nếu cả 3 lượt trùng, báo chưa tạo được và không giữ ứng viên trùng. Lỗi mạng, lỗi tra múi giờ hoặc phản hồi thiếu/không khớp không được coi là trùng: giữ ứng viên ở trạng thái chưa đạt và dừng thử cho proxy đó, tiếp tục proxy kế tiếp. Có thể kiểm tra lại từ menu hồ sơ. **Dừng** ngừng hàng đợi, giữ những hồ sơ đã đạt; ứng viên đang đo dở được giữ ở trạng thái chưa đạt. Không có vòng lặp vô hạn, không thay ID trên trang/agent/server và không bảo đảm luôn tạo thêm được ID mới.

Chỉ chạy một đợt tự động tại một thời điểm; các proxy được xử lý tuần tự. App giữ màn hình sáng trong lúc chạy, nhưng không cam kết chạy tiếp khi iOS đưa app xuống nền hoặc đóng app. Để cấu hình thủ công, dùng nút **Tạo thủ công** cạnh dấu +.

Proxy cũ chỉ được dùng lại khi endpoint, loại, username và mật khẩu đều khớp; mật khẩu khác tạo bản ghi mới, không đổi thông tin đăng nhập của hồ sơ cũ. Những hồ sơ cũ và lịch sử ID không bị tự xóa. Trên iOS 16, ứng viên trùng được xóa cả thư mục website trong phạm vi UUID đã đo, tránh tích lũy cache qua các lượt thử.

## Kiểm chứng iPhone iOS 16.1.1

Đã cài build 34 sau CI thành công, xác minh digest artifact, checksum IPA, commit/build/bundle ID và bảo toàn byte dữ liệu cấu hình khi cập nhật. Phép thử dùng một proxy đã lưu nhưng đi qua chính bộ đọc định dạng proxy, bộ tạo tự động, WebView hiển thị và đường kiểm tra/xóa thật của tính năng. Không mô phỏng bấm nhập trong biểu mẫu. Không dùng phản hồi Fingerprint giả.

| Proxy | Lượt tự chạy | Được nhận | Ứng viên trùng tự xóa | Event không cache | ID khác nhau quan sát được |
|---:|---:|---:|---:|---:|---:|
| 1 | 2 | 1 | 1 | 4 | 2 |

Đối chiếu lịch sử trước phép thử xác nhận: ID của ứng viên bị loại đã có trong data; ID của ứng viên được nhận chưa có trong data, được ghi nhận với đúng hồ sơ/kho mới.

Giữ nguyên hồ sơ/proxy có trước và ledger. Các hồ sơ QA được nhận (nếu có) đã được dọn sau phép đo theo yêu cầu giữ danh sách sạch; ID mới vẫn được giữ trong lịch sử. Danh sách cuối có **0 hồ sơ**; kho tạm được dọn. Không công khai proxy, mật khẩu, IP thoát hoặc Visitor ID.

## Kiểm thử

[CI](https://github.com/raycola9969/Lekapro/actions/runs/39241253846): **61 đạt, 1 bỏ qua có chủ đích, 0 thất bại**. Chín kiểm thử mới kiểm tra định dạng proxy/IPv6/mật khẩu có dấu hai chấm, gộp dòng trùng, thông báo lỗi không chứa mật khẩu, dùng lại proxy mà không đổi mật khẩu cũ, nhận ID đã xác minh, thử lại sau trùng, giới hạn 3 lượt, giữ ứng viên lỗi, chống nhận kết quả chưa duyệt và hủy hàng đợi. Kiểm thử queue dùng runner/proof fixture; WebKit và phản hồi thật được đo riêng trên máy như bảng trên. Các kiểm thử nhận/loại ID và múi giờ hiện có vẫn chạy trong CI.

- Source build: `30f0a518744e1dcda10ccb043c8b7af9bf8bd9b2`.
- SHA-256 IPA: `0ec7c3c3093c8e77019a86fb54948b64dd8fb7b0f98767e55096ad676f6b7a6c`.

[Số liệu đã loại định danh](automatic-profile-creation-build34.json) · [PR #4](https://github.com/raycola9969/Lekapro/pull/4).
