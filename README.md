# Lekapro

Trình duyệt iOS nhiều hồ sơ, viết mới bằng SwiftUI và WKWebView. iOS 18 trở lên; dữ liệu lưu trên thiết bị.

## Đã triển khai

- Tạo, sửa, sao chép cấu hình, tìm kiếm và xóa hồ sơ.
- Mỗi hồ sơ dùng `WKWebsiteDataStore(forIdentifier:)` với UUID riêng; các tab cùng hồ sơ chia sẻ dữ liệu.
- Khôi phục tối đa 30 tab/hồ sơ; dấu trang, lịch sử, nhãn và ghi chú.
- Kho proxy SOCKS5, HTTP CONNECT, HTTPS CONNECT; xác thực bằng mật khẩu Keychain.
- `allowFailover = false` khi cấu hình proxy: không cho WebKit chuyển sang kết nối trực tiếp.
- Bộ chặn tracker cơ bản; tùy chọn chặn đọc Canvas/Audio và chặn WebRTC.
- Nhập/xuất cookie JSON hoặc Netscape TXT; sao lưu/nhập cấu hình.
- Tải file qua WebKit, chia sẻ và mở liên kết ngoài app.
- GitHub Actions build IPA chưa ký và chạy XCTest bằng SDK iOS thật.

Đây là bản triển khai mới, **chưa phải bản sao giống 100% ExitAnty**. Không dùng mã/tài nguyên trích từ IPA. Không có backend, camera ảo, WebDriver, giả kết quả kiểm tra website hoặc lớp che dấu các hàm JavaScript đã sửa. Chế độ Canvas/Audio chặn API bằng lỗi rõ ràng, không mô phỏng thiết bị khác. Chưa xác nhận tương thích với Persona hay dịch vụ xác minh cụ thể.

## Build trên GitHub

Push lên `main` chạy workflow **iOS build**. Mở Actions → lần chạy → Artifacts:

- `Lekapro-unsigned`: IPA chưa ký, SHA-256 và commit nguồn.
- `build-diagnostics`: log biên dịch và kết quả XCTest.

IPA chưa ký cần được ký bằng công cụ sideload phù hợp trước khi cài lên iPhone. Đăng nhập GitHub không cung cấp chứng chỉ Apple. Workflow không nhận Apple ID hay chứng chỉ ký. Bản build thành công chỉ xác nhận biên dịch và các kiểm thử đã chạy; proxy thật, DNS/UDP, camera của website và tương thích website vẫn cần kiểm thử thiết bị.

## Mở bằng Xcode

```sh
brew install xcodegen
xcodegen generate
open Lekapro.xcodeproj
```

Chọn Team cá nhân và Bundle Identifier phù hợp, rồi chạy trên iPhone iOS 18+. Không cần App Groups hoặc entitlement VPN.

## Dữ liệu và giới hạn

Cấu hình nằm trong Application Support với file protection. Mật khẩu proxy nằm trong Keychain `ThisDeviceOnly`. Nhân bản hồ sơ chỉ sao chép cấu hình, tạo UUID kho mới và không sao chép phiên đăng nhập. Nhập cấu hình cũng tạo UUID mới. Bản sao lưu chứa lịch sử/dấu trang và thông tin proxy, không chứa mật khẩu proxy hoặc dữ liệu WebKit. File cookie xuất có thể chứa token đăng nhập.

Xóa hồ sơ đóng các WebView trước khi xóa dữ liệu. Các tùy chọn chặn JavaScript áp dụng trong trang và iframe, chưa bao phủ mọi Worker. Danh sách chặn tracker hiện chỉ có một số domain phổ biến. Proxy dùng API WebKit công khai; chưa có packet capture để chứng minh không rò DNS/UDP. Popup tạo cửa sổ được mở thành tab mới; luồng phụ thuộc `window.opener` cần kiểm thử thêm. Chưa có language/timezone spoof hoặc giả Canvas/Audio fingerprint.

Nguồn API: [WebKit profiles](https://webkit.org/blog/14423/building-profiles-with-new-webkit-api/), [ProxyConfiguration](https://developer.apple.com/documentation/network/proxyconfiguration), [WKDownloadDelegate](https://developer.apple.com/documentation/webkit/wkdownloaddelegate).

Xem [CHECKLIST.md](CHECKLIST.md) để kiểm tra trên iPhone.
