# Lekapro

Trình duyệt iOS nhiều hồ sơ, viết mới bằng SwiftUI và WKWebView. Bản 0.2 hỗ trợ iOS 16.1 trở lên, với nhánh tương thích dành cho thiết bị jailbreak/TrollStore.

## Đã triển khai

- Tạo, sửa, sao chép cấu hình, tìm kiếm và xóa hồ sơ.
- iOS 17+: kho dữ liệu công khai theo UUID. iOS 16.x: cấu hình WebKit SPI với thư mục riêng trong sandbox của Lekapro. Các tab cùng hồ sơ chia sẻ một đối tượng kho dữ liệu.
- Khôi phục tối đa 30 tab/hồ sơ; dấu trang, lịch sử, nhãn và ghi chú.
- Kho proxy SOCKS5 và HTTP CONNECT; HTTPS CONNECT tới proxy được hỗ trợ từ iOS 17. Mật khẩu lưu trong Keychain.
- iOS 17+: `allowFailover = false`. iOS 16 dùng cấu hình proxy riêng của WebKit; phép thử với SOCKS5 tại cổng không có máy chủ đã trả lỗi kết nối, không tải trang trực tiếp. Chưa đo DNS/UDP hoặc mọi tình huống thay đổi mạng.
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

Chọn Team cá nhân và Bundle Identifier phù hợp, rồi chạy trên iPhone. Trên iOS 16.1.1 jailbreak có thể cài IPA bằng TrollStore. Nhánh iOS 16 dùng API WebKit private, không dành cho phân phối App Store. Không cần thay đổi proxy toàn hệ thống hoặc cài tweak vào Safari.

## Kiểm tra iOS 16 trên thiết bị

Build Debug tự chạy kiểm tra trong hai kho dữ liệu chẩn đoán riêng của Lekapro, sử dụng HTML cục bộ. Báo cáo được ghi tại Documents/Lekapro-device-check.json. Báo cáo kiểm tra cookie, localStorage, IndexedDB, cách ly hai kho và lưu dữ liệu qua lần mở app tiếp theo. Cờ `PersistedFromPreviousLaunch` có thể false ở lần chạy đầu; cần đóng/mở app thêm lần nữa.

Thông tin SSH và mật khẩu thiết bị không được đưa vào repository hoặc workflow.

Bản 0.2.0 (build 6, nguồn `72d36b3`) đã cài và mở bằng TrollStore trên iPhone 11 Pro Max chạy iOS 16.1.1. Kiểm tra bằng hai kho chẩn đoán và HTML cục bộ xác nhận cookie, localStorage và IndexedDB được cách ly; cả ba còn nguyên sau khi kết thúc tiến trình rồi mở app lại. Xem [báo cáo lưu trữ](verification/ios-16.1.1-storage.json).

Đã tạo hai hồ sơ thật trong app: một kết nối trực tiếp và một dùng SOCKS5 có xác thực. WebKit tải dịch vụ kiểm tra IP và trả hai IP khác nhau; kiểm tra lại hồ sơ trực tiếp sau khi mở hồ sơ proxy cho cùng IP ban đầu. Cookie và localStorage giữa hai hồ sơ được cách ly. Kho thử riêng với SOCKS5 tại cổng không hoạt động trả lỗi kết nối. Báo cáo mạng, endpoint và thông tin xác thực của phép thử được giữ ngoài repository; mật khẩu proxy lưu trong Keychain. Các kết quả này chưa thay thế kiểm thử đăng nhập website, proxy HTTP/HTTPS hoặc packet capture DNS/UDP.

Trên [Fingerprint demo](https://fingerprint.com/demo/), hai hồ sơ thật hiện trả **cùng Visitor ID**, dù Server API Response của lượt tải lại ghi nhận hai IP khác nhau. Đã đo lần đầu và tải lại một lần trong mỗi hồ sơ: bốn event khác nhau, agent đều báo không dùng cache; Visitor ID ổn định. Bản hiện tại chưa cách ly fingerprint theo phép thử này. Ảnh và phản hồi gốc giữ ở máy phát triển; repo chỉ có [báo cáo đã loại dữ liệu định danh](verification/fingerprint-demo-comparison.json).

[CI build 6](https://github.com/raycola9969/Lekapro/actions/runs/39008359542): build iPhone thành công, 10 XCTest đạt trên simulator iOS 18.5.

## Dữ liệu và giới hạn

Cấu hình nằm trong Application Support với file protection. Mật khẩu proxy nằm trong Keychain `ThisDeviceOnly`. Nhân bản hồ sơ chỉ sao chép cấu hình, tạo UUID kho mới và không sao chép phiên đăng nhập. Nhập cấu hình cũng tạo UUID mới. Bản sao lưu chứa lịch sử/dấu trang và thông tin proxy, không chứa mật khẩu proxy hoặc dữ liệu WebKit. File cookie xuất có thể chứa token đăng nhập.

Xóa hồ sơ đóng các WebView trước khi xóa dữ liệu. Các tùy chọn chặn JavaScript áp dụng trong trang và iframe, chưa bao phủ mọi Worker. Danh sách chặn tracker hiện chỉ có một số domain phổ biến. Proxy cấu hình riêng theo từng kho WebKit; chưa có packet capture để chứng minh không rò DNS/UDP. Popup tạo cửa sổ được mở thành tab mới; luồng phụ thuộc `window.opener` cần kiểm thử thêm. Chưa có language/timezone spoof hoặc giả Canvas/Audio fingerprint.

Nguồn API: [WebKit profiles](https://webkit.org/blog/14423/building-profiles-with-new-webkit-api/), [WebKit SPI trước iOS 16.1](https://github.com/WebKit/WebKit/blob/1c25190c9ac675b28f04ff6fc65ef11047fff348/Source/WebKit/UIProcess/API/Cocoa/_WKWebsiteDataStoreConfiguration.h), [ProxyConfiguration](https://developer.apple.com/documentation/network/proxyconfiguration), [WKDownloadDelegate](https://developer.apple.com/documentation/webkit/wkdownloaddelegate).

Xem [CHECKLIST.md](CHECKLIST.md) để kiểm tra trên iPhone.
