# Múi giờ tự động theo IP — build 33

Hồ sơ mới tạo từ dấu **+** mặc định dùng **Múi giờ → Theo IP (tự động)**. App xác định IP thoát qua chính WebKit/proxy của hồ sơ, tra múi giờ IANA của IP đó rồi tạo process pool với múi giờ này trước khi mở trang chủ, tab đã lưu hoặc Fingerprint. Kết nối trực tiếp dùng IP mạng hiện tại. Múi giờ áp dụng bằng cấu hình WebKit cho cả trang và Worker; không ghi đè JavaScript `Date`/`Intl`.

Mỗi lần mở lại hồ sơ tự động từ danh sách, app tạo phiên mới và tra lại IP. Không tra được IP/múi giờ hoặc hệ điều hành không áp dụng được thì không mở website; màn hình có nút **Thử lại**, các tab đã lưu được giữ nguyên. Khi kiểm tra Visitor ID, IP phải còn khớp IP dùng để xác định múi giờ. Không tự đổi múi giờ giữa một phiên đang mở; nếu proxy xoay IP giữa phiên, cần đóng/mở hồ sơ và kiểm tra lại ID. Kết quả ID cũ không bảo đảm ổn định khi IP thay đổi.

Có thể xem múi giờ đã xác định trong menu **…** của trình duyệt. Hồ sơ cũ vẫn giữ tùy chọn thiết bị/thủ công trước đó; để dùng chế độ mới, chọn **Chỉnh sửa → Múi giờ → Theo IP (tự động)**. Đổi chế độ đưa trạng thái kiểm tra ID về chờ đo lại nếu hồ sơ tham gia kiểm tra ID; lịch sử ID vẫn được giữ.

IP thoát được kiểm tra qua ipify; tra cứu IP/múi giờ dùng HTTPS ipwho.is qua cùng kết nối hồ sơ, gửi chính IP thoát đã đo, không dùng địa chỉ host của proxy. Dịch vụ xác định múi giờ theo cơ sở dữ liệu IP, không phải vị trí GPS. Tra cứu phụ thuộc khả dụng và giới hạn của nhà cung cấp; lỗi hoặc hết lượt không được ngầm chuyển về múi giờ máy. [Tài liệu dịch vụ và trường timezone.id](https://ipwhois.io/documentation).

## Máy thật iOS 16.1.1

IPA build 33 được đối chiếu digest GitHub, SHA-256 IPA, commit/build/bundle ID và kiểm thử trên máy thật. CI đầy đủ đã thành công trước khi công bố kết quả này. Dữ liệu cấu hình có trước cập nhật giữ nguyên byte.

| Kết nối | Múi giờ tra từ IP | Múi giờ trang | Múi giờ Worker | Offset tháng 1 (phút) |
|---|---|---|---|---:|
| Trực tiếp | Asia/Bangkok | Asia/Bangkok | Asia/Bangkok | -420 |
| Proxy SOCKS5 | America/Chicago | America/Chicago | America/Chicago | 360 |

Hai kết nối có IP thoát khác nhau, mỗi lượt khởi động app riêng. Kiểm tra dùng đường mở phiên/tra cứu thật của ứng dụng; hai hồ sơ tạm chỉ nằm trong bộ nhớ, không thêm vào danh sách. Kho website tạm đã được dọn sau phép đo. Giữ nguyên **0 hồ sơ đã lưu**, proxy và lịch sử ID; không khôi phục các hồ sơ kiểm thử đã xóa. Tên IANA tương đương như Asia/Ho_Chi_Minh và Asia/Saigon được đối chiếu qua cách chuẩn hóa của Intl, đồng thời kiểm tra offset thực.

## Kiểm thử

[CI](https://github.com/raycola9969/Lekapro/actions/runs/39193147977): **52 đạt, 1 bỏ qua có chủ đích, 0 thất bại**. Sáu kiểm thử mới kiểm tra phản hồi sai/khác IP, dữ liệu cũ, chặn mở trang trước khi tra xong, lỗi/thử lại, đóng trong lúc tra, múi giờ native của trang/Worker và alias IANA. Các kiểm thử định vị IP trong simulator dùng resolver giả; phần xác minh hai IP/proxy thực chạy trên iPhone và không giả phản hồi dịch vụ. 14 kiểm thử cơ chế nhận/loại ID của build 32 vẫn đạt.

- Source commit build: `2643b5950068f62e056a718ac4238551196f5c8a`.
- SHA-256 IPA: `6226b281910acf3da147c95936b22b126884ccbbd80053c231c62020608401e5`.

[Số liệu đã loại IP/định danh](ip-timezone-build33.json) · [PR #3](https://github.com/raycola9969/Lekapro/pull/3).
