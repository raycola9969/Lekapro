# Kiểm tra ID trước khi dùng hồ sơ — mã nguồn build 32

Hồ sơ mới có thể bật **Kiểm tra ID trước khi sử dụng**. Sau khi lưu cấu hình proxy/UA, app mở màn hình Fingerprint bằng chính kho và kết nối đó. Chỉ nhận hồ sơ khi ID không trùng lịch sử Lekapro tại thời điểm đo.

1. Đọc IP qua WebView của hồ sơ.
2. Mở `https://fingerprint.com/demo/`, đọc ID hiển thị và các phản hồi agent/server do trang cung cấp.
3. Tải lại từ nguồn; yêu cầu hai event khác nhau, không cache, cùng ID/môi trường/UA/IP; IP phải khớp phép kiểm tra mạng trước đó.
4. Ghi phán quyết và lịch sử ID trong một lần lưu atomic. ID trùng một hồ sơ/kho khác trong lịch sử → không đạt.
5. Chỉ hồ sơ mới chưa từng đạt mới được tự xóa khi trùng. Xóa dữ liệu website qua WebKit và xóa bản ghi hồ sơ; lịch sử ID được giữ. Hồ sơ cũ kiểm tra lại gặp trùng được giữ và chặn sử dụng.

Timeout, hủy, phản hồi thiếu/không khớp, ID đổi khi tải lại, IP đổi, môi trường dịch vụ đổi hoặc lỗi lưu đều không phải kết quả đạt. Lỗi đo không tự xóa hồ sơ. Nếu đã lưu kết quả trùng mà xóa không hoàn tất, hồ sơ vẫn ở trạng thái không đạt.

Đổi UA, proxy, mật khẩu proxy hoặc tùy chọn ảnh hưởng nhận diện sẽ yêu cầu đo lại với những hồ sơ đã tham gia kiểm tra. Đổi tên/nhãn/tab không làm mất kết quả. Sao chép/import tạo kho mới và không mang theo quyền “đã đạt”; export cấu hình không chứa lịch sử ID hoặc kết quả đo. Hồ sơ có trước build 32 không tự được đánh dấu đã kiểm tra, không bị tự xóa và chưa nằm trong lịch sử đối chiếu cho đến khi được đo.

Đây là lịch sử **trên thiết bị này**, cùng môi trường Fingerprint. Không dùng `visitor_found=true` để loại hồ sơ: ID từng xuất hiện bên dịch vụ nhưng chưa có trong lịch sử Lekapro vẫn có thể được nhận. Không coi đây là bảo đảm ID không đổi/gộp trong tương lai hoặc luôn tạo được thêm hồ sơ. Có thể kiểm tra lại từ menu hồ sơ.

Việc đọc phản hồi HTTPS hiển thị trên demo là kiểm tra tính nhất quán của phía client; không phải chứng thực mật mã hay quyền truy cập Server API riêng. Nếu cấu trúc trang demo thay đổi, app giữ trạng thái chưa đạt. Không sửa ID trên trang, agent hoặc phản hồi server; không thêm vòng tự tạo vô hạn.

## Tình trạng kiểm chứng

- Bộ đọc JavaScript mới khớp 36 trang đo thật đã lưu, ba mẫu phản hồi thiếu không được nhận.
- Đã kiểm tra cú pháp 33 file Swift bằng parser trên máy Windows; đây không phải kiểm tra biên dịch/type checking.
- Có 12 XCTest mới cho ledger, lưu qua khởi động lại, xóa riêng kho bị loại, lỗi đo, cấu hình đổi, import/export, phản hồi sai và phiên kiểm tra không khôi phục/ghi đè tab cũ.
- Xcode build, XCTest và phép thử iOS 16.1.1 của bản 32 đang chờ thực hiện. Máy hiện vẫn ở build 31 cho đến khi artifact mới qua kiểm tra và được cài.
