# Kiểm tra ở trang chủ — build 35

## Thay đổi

Luồng FingerprintReviewController dùng https://fingerprint.com/ thay cho /demo/.
Bộ đọc mở chế độ developer có sẵn của trang, đọc response.json và smartSignals.json
trong các thẻ pre. App không gọi SDK thêm, sửa kết quả hay chặn/thay phản hồi mạng.

ID phải xuất hiện trong lời chào dành cho khách truy cập. Nhãn Visitor ID trong
ví dụ quảng cáo không được chấp nhận. App gom hai phản hồi qua các tab chỉ trong
cùng URL và performance.timeOrigin; chuyển tài liệu sẽ bỏ bộ đệm bằng chứng.

Điều kiện duyệt giữ nguyên: ID trang/agent/server khớp, agent không cache,
event/environment/UA/URL/IP khớp, tải lại có event và timeOrigin mới nhưng cùng
ID/IP, rồi mới ghi vào lịch sử hoặc xác định trùng. URL kiểm tra chỉ nhận đúng
trang chủ HTTPS của fingerprint.com. Không có đường lui sang /demo/ trong luồng duyệt.

Kho ID, mã băm và môi trường cũ không bị reset. Nếu trang chủ trả môi trường khác
môi trường đã ghi nhận, app báo chưa đạt; không giả định ID mới do đổi namespace.
Các công cụ thí nghiệm /demo/ cũ trong DEBUG và live probe tùy chọn không phải
luồng tạo hồ sơ của người dùng và chưa được chuyển đổi trong thay đổi này.

## Có thể tự đo mà không dùng trang Fingerprint không?

Có thể xây bộ thu thập tín hiệu chạy trong WebView của từng hồ sơ, chuẩn hóa dữ
liệu rồi tính hàm băm với phiên bản thuật toán riêng. Đây là dấu vân tay nội bộ,
khác UUID hồ sơ. Những hồ sơ có cùng tín hiệu có thể có cùng dấu vân tay.

Không thể dùng hàm băm nội bộ để suy ra chắc chắn Visitor ID thương mại của
Fingerprint hoặc kết luận một website khác sẽ nhận hai thiết bị khác nhau.
Fingerprint Identification còn dùng xử lý máy chủ và tín hiệu mạng. Muốn giữ
đúng ý nghĩa kiểm tra ID của họ cần kết quả của họ, qua trang hoặc tích hợp SDK/API
của tài khoản được cấp quyền. Tích hợp riêng có thể bỏ phụ thuộc bố cục trang.

Nếu bổ sung bộ tự đo, cần lưu lịch sử riêng theo nhà cung cấp/phiên bản, không
trộn ID nội bộ với lịch sử Fingerprint và không tự chuyển sang bộ nội bộ khi trang lỗi.
Build 35 chỉ sửa nguồn kiểm tra; chưa bổ sung thuật toán tự đo mới.

Nguồn chính thức: https://github.com/fingerprintjs/fingerprintjs#limitations

## Kiểm thử

- Node chạy mã JS thực sự nhúng trong Swift với mô hình DOM thay đổi qua các tab:
  đọc phản hồi, giữ tab developer mở, từ chối ví dụ quảng cáo/ID mơ hồ/loading/JSON hỏng.
- XCTest bổ sung trường hợp chỉ nhận URL trang chủ chính xác, gom phản hồi trong
  cùng tài liệu, reset khi đổi URL/timeOrigin, từ chối event chéo/thiếu ID hiển thị.
- Các ca ledger, trùng ID, hủy kiểm tra, không mất dữ liệu khi xóa ứng viên vẫn giữ nguyên.
- Kiểm tra cú pháp Swift/YAML/tài nguyên không thay thế build Xcode hoặc thử máy thật.

## Kết quả đã đo ngày 2026-10-29

- [CI thành công](https://github.com/raycola9969/Lekapro/actions/runs/40878003052):
  iPhone/simulator build và bộ đọc JS đạt; 65 XCTest qua, 1 live probe tùy chọn
  được bỏ qua, 0 lỗi. Lượt CI đầu bị timeout ở ca reset WebKit cũ. Khởi động lại
  simulator trước mỗi ca reset giúp lượt đầy đủ tiếp theo qua cả hai ca; không
  bỏ assertion hoặc đổi mã chức năng reset.
- Đã cài build 35 trên iPhone 11 Pro Max iOS 16.1.1. Tệp cấu hình được so sánh
  byte trước/sau khi cài, không bị thay đổi trong quá trình cập nhật.
- Có ba lượt QA native: một proxy cũ lỗi xác thực trước khi mở trang; một lượt
  trang chủ không trả đủ bằng chứng nên hồ sơ bị giữ chưa đạt; lượt trang chủ
  tiếp theo đọc được hai event không cache, khác event/timeOrigin và cùng ID/IP.
- Lượt thành công chạy parser/creator/controller thật, một hồ sơ được duyệt với
  ID chưa có trong lịch sử. Kho tăng từ 2 lên 3 ID. Sau QA đã xóa hồ sơ thử, giữ
  cả 3 ID và 23 bản ghi proxy. Danh sách cuối có 0 hồ sơ, không còn yêu cầu QA chờ.

Phép đo này chứng minh đường trang chủ chạy được trên máy đã thử, không chứng
minh dịch vụ luôn trả đủ dữ liệu hoặc mọi hồ sơ sẽ có ID mới. Ca thiếu phản hồi
không được tính là ID trùng. Build 35 chưa có thuật toán tự đo nội bộ mới.

- Mã nguồn CI: `bd5622bd5d7bcd24ac4bbd78daf26a81b5759630`.
- Commit nguồn đóng gói của PR: `ce3074c6681d2202714a17439959562eeebd57ac`.
- IPA SHA-256: `6affb13ae0c2f93f7950ae5f0ec162d55f9492bf7d049595bc178be4c38f12bd`.
- [Số liệu đã bỏ ID/IP và thông tin đăng nhập](homepage-check-build35.json).

Các ảnh chụp cấu hình và phản hồi thật nằm ở bằng chứng riêng trên máy tính,
không đưa vào repo. Repo đã chuyển public theo xác nhận để chạy CI.
