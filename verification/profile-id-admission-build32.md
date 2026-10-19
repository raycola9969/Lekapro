# Kiểm tra ID trước khi dùng hồ sơ — build 32

Đã cài và kiểm chứng trên iPhone iOS **16.1.1**. Hồ sơ mới có thể bật **Kiểm tra ID trước khi sử dụng**. Sau khi lưu proxy/UA, app mở Fingerprint bằng chính kho và kết nối đó; chỉ nhận hồ sơ khi ID không trùng lịch sử Lekapro tại thời điểm đo.

## Cách dùng

1. Bấm **+**, nhập tên và chọn proxy/UA.
2. Giữ bật **Kiểm tra ID trước khi sử dụng**, bấm **Lưu** và giữ app ở màn hình trước.
3. App kiểm tra IP, đọc phản hồi Fingerprint rồi tải lại để xác nhận.
4. ID chưa có trong lịch sử → hồ sơ đạt và được sử dụng. ID trùng → tự xóa hồ sơ mới và xóa dữ liệu website qua WebKit. Lỗi/thiếu phản hồi → giữ hồ sơ ở trạng thái chưa đạt, không tự xóa.

Hồ sơ cũ không tự được ghi nhận là đã kiểm tra và không tự bị xóa. Có thể chọn **Kiểm tra Visitor ID** từ menu hồ sơ để đăng ký hoặc đo lại; nếu một hồ sơ cũ bị trùng, app giữ nó và đánh dấu không đạt. ID đã ghi nhận vẫn được giữ trong lịch sử sau khi xóa hồ sơ để đối chiếu các hồ sơ tạo tiếp.

## Kiểm chứng máy thật

Qua hai lần khởi động app, **4 ứng viên mới / 8 event Fingerprint không cache / 2 IP thoát**. Cùng UA Safari iOS 17.2; lượt thứ hai bật bộ chặn tracker cơ bản như cấu hình mặc định.

| Lượt | Ứng viên mới | Được nhận | Trùng, tự xóa | ID lưu trước / sau |
|---|---:|---:|---:|---:|
| 1 | 2 | 1 | 1 | 0 / 1 |
| 2 | 2 | 0 | 2 | 1 / 1 |

Tổng **1 hồ sơ được nhận, 3 hồ sơ trùng bị tự xóa**. Lịch sử ID giữ nguyên qua lần khởi động tiếp theo; mọi cấu hình hồ sơ/bản ghi proxy có trước mỗi lượt được đối chiếu giữ nguyên. Khi cập nhật IPA, toàn bộ byte cấu hình của **1108 hồ sơ** được giữ nguyên trước khi chạy các ứng viên QA mới.

Phép thử gọi đúng màn hình/bộ đọc/ledger/đường xóa của tính năng sử dụng bình thường qua yêu cầu QA một lần, không thay agent hoặc phản hồi dịch vụ. Các ứng viên dùng kho/UUID mới; report gốc giữ riêng trên máy tính. Không mô phỏng thao tác nhập trong biểu mẫu bằng UI automation. Kết quả ID/IP/event lấy từ phản hồi mà trang demo HTTPS hiển thị và được bộ đọc trong app đối chiếu; không phải một lần truy vấn Server API độc lập.

## Điều kiện nhận và phạm vi bảo đảm

App đọc IP qua WebView, rồi yêu cầu ID hiển thị khớp agent/server, `cache_hit=false`, hai event khác nhau, hai lần điều hướng khác nhau, cùng ID/môi trường/UA/IP; IP phải khớp phép kiểm tra mạng trước. Ghi phán quyết và lịch sử trong một lần lưu atomic để hai ứng viên không đồng thời nhận cùng ID. Xóa trùng chỉ dành cho ứng viên mới chưa từng đạt; sau khi đã đạt, quyền tự xóa này bị bỏ.

Timeout, hủy, phản hồi thiếu/không khớp, ID/IP đổi, môi trường dịch vụ đổi, cấu hình đổi giữa phép đo hoặc lỗi lưu đều không được nhận. Nếu đã ghi kết quả trùng mà xóa thất bại, hồ sơ vẫn ở trạng thái không đạt. Khóa theo hồ sơ được giữ đến khi lần kiểm tra cũ dọn xong, kể cả khi đóng màn hình rồi thử lại.

Đổi UA, proxy, mật khẩu proxy hoặc tùy chọn ảnh hưởng nhận diện yêu cầu đo lại cho những hồ sơ đã tham gia kiểm tra. Đổi tên/nhãn/tab không làm mất kết quả. Sao chép/import tạo kho mới và không mang theo quyền đã đạt; export cấu hình không chứa ledger hoặc kết quả đo. Các hồ sơ cũ chưa đăng ký không nằm trong tập đối chiếu.

Quy tắc là **ID trùng lịch sử trên thiết bị này**, cùng môi trường Fingerprint. Không dùng `visitor_found=true` làm lý do loại: ID từng thấy bên dịch vụ nhưng chưa có trong ledger vẫn có thể được nhận. Không bảo đảm ID không đổi/gộp về sau, không tạo thêm entropy hay bảo đảm luôn tạo được thêm hồ sơ. Nếu mọi ứng viên mới đều nhận ID đã lưu, chúng sẽ bị loại; không có vòng tự tạo vô hạn. Có thể đo lại từ menu hồ sơ.

Đọc phản hồi hiển thị trên demo là kiểm tra tính nhất quán phía client, không phải chứng thực mật mã. Nếu cấu trúc trang thay đổi, app không coi là đạt. Không sửa ID trên trang, agent hoặc phản hồi server.

## Build và kiểm thử

[CI đầy đủ](https://github.com/raycola9969/Lekapro/actions/runs/39187378755): **46 đạt, 1 bỏ qua có chủ đích, 0 thất bại**, gồm **14 XCTest mới** về nhận/loại ID, ledger qua khởi động lại/xóa hồ sơ, lỗi ghi file, lỗi đo, cấu hình/mật khẩu đổi, import/export, phản hồi sai, hủy/thử lại, bảo toàn tab cũ và chỉ xóa cookie/kho của ứng viên bị loại. Kiểm thử mật khẩu dùng kho nhớ trong simulator unsigned; ứng dụng và phép đo máy thật dùng Keychain mặc định.

Bộ đọc mới cũng khớp 36 trang đo thật đã lưu và không nhận ba mẫu thiếu phản hồi. Artifact được đối chiếu digest của GitHub, SHA-256 nội bộ IPA, commit/build/bundle ID trước khi cập nhật.

- Source commit thực được build: `a558fd0e182893171565c72dfa3c61a0bbaf3df1`.
- IPA SHA-256: `3b3eccece562800373a6513a4a2d01f65ce0f7cc0ff6ac1f77baafd579435db8`.

[Số liệu đã loại định danh](profile-id-admission-build32.json) · [PR #2](https://github.com/raycola9969/Lekapro/pull/2).
