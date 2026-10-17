# Lekapro

Trình duyệt iOS nhiều hồ sơ, viết mới bằng SwiftUI và WKWebView. Bản 0.3 hỗ trợ iOS 16.1 trở lên, với nhánh tương thích dành cho thiết bị jailbreak/TrollStore.

## Đã triển khai

- Tạo, sửa, sao chép cấu hình, tìm kiếm và xóa hồ sơ.
- iOS 17+: kho dữ liệu công khai theo UUID. iOS 16.x: cấu hình WebKit SPI với thư mục riêng trong sandbox của Lekapro. Các tab cùng hồ sơ chia sẻ một đối tượng kho dữ liệu.
- Khôi phục tối đa 30 tab/hồ sơ; dấu trang, lịch sử, nhãn và ghi chú.
- Kho proxy SOCKS5 và HTTP CONNECT; HTTPS CONNECT tới proxy được hỗ trợ từ iOS 17. Mật khẩu lưu trong Keychain.
- iOS 17+: `allowFailover = false`. iOS 16 dùng cấu hình proxy riêng của WebKit; phép thử với SOCKS5 tại cổng không có máy chủ đã trả lỗi kết nối, không tải trang trực tiếp. Chưa đo DNS/UDP hoặc mọi tình huống thay đổi mạng.
- Bộ chặn tracker cơ bản; tùy chọn chặn đọc Canvas/Audio và chặn WebRTC.
- Tùy chọn chặn tạo ngữ cảnh WebGL và giảm thông tin phần cứng: tối đa 2 luồng được báo cho trang, kích thước màn hình làm tròn xuống theo bậc 200 px. Mặc định tắt; áp dụng trong trang/frame, chưa bao phủ Worker. Có thể ảnh hưởng đồ họa 3D, bố cục và xử lý song song; không bảo đảm tách Visitor ID.
- Thử nghiệm áp dụng các thiết lập trên cho classic Blob Worker được tạo trong trang qua `URL.createObjectURL`. Mặc định tắt; giữ MIME và kiểm tra CSP, không sửa thông điệp của Worker. Chưa bao phủ module, URL ngoài, Shared/Service Worker hoặc mọi Worker lồng nhau. Địa chỉ Blob Worker thay đổi; CSP có thể chặn việc nạp script bổ sung, khi đó cần tắt tùy chọn này để giữ tương thích.
- User-Agent theo hồ sơ: mặc định WebKit, preset iPhone Safari 17.2/18.7.9 và chuỗi tùy chỉnh. Đổi UA giữ UUID kho dữ liệu; không đổi iOS/WebKit thật.
- Chữ tối thiểu theo hồ sơ qua `WKPreferences.minimumFontSize`; múi giờ riêng qua cấu hình process pool WebKit SPI, hỗ trợ từ iOS 16 và kiểm tra khả năng ở runtime. Không thay múi giờ toàn hệ thống hoặc bọc các hàm `Date`/`Intl`. Nếu SPI không hỗ trợ, app báo lỗi thay vì âm thầm dùng múi giờ thiết bị.
- Tùy chọn dùng một họ phông cho website qua user stylesheet WebKit, mặc định theo website. Thay bố cục chữ thực trong trang/frame, có thể ảnh hưởng phông biểu tượng; không thay các hàm đo chữ JavaScript. Dùng SPI và báo lỗi nếu không hỗ trợ.
- Thử nghiệm nhiễu Canvas/Audio theo hồ sơ và website, mặc định tắt. Thay đổi dữ liệu đọc từ API, không thay phản hồi của dịch vụ kiểm tra; chưa bảo đảm tách Visitor ID. Chỉ áp dụng trong trang/frame, chưa bao phủ Worker hoặc mọi API đồ họa/âm thanh.
- Audio có mức rất nhỏ (`1e-7`) và tiêu chuẩn (`1e-5`) cho biên độ đọc mẫu. Mức là biên độ thuật toán, không phải chênh lệch được cam kết của giá trị tổng hợp mà website đo. Kiểm thử đối chiếu lặp lại, bản sao đọc dữ liệu và độ lệch từng mẫu.
- Nhập/xuất cookie JSON hoặc Netscape TXT; sao lưu/nhập cấu hình.
- Tải file qua WebKit, chia sẻ và mở liên kết ngoài app.
- GitHub Actions build IPA chưa ký và chạy XCTest bằng SDK iOS thật.

Đây là bản triển khai mới, **chưa phải bản sao giống 100% ExitAnty**. Không dùng mã/tài nguyên trích từ IPA. Không có backend, camera ảo, WebDriver, giả kết quả kiểm tra website hoặc lớp che dấu các hàm JavaScript đã sửa. Chế độ Canvas/Audio chặn API bằng lỗi rõ ràng, không mô phỏng thiết bị khác. Chưa xác nhận tương thích với Persona hay dịch vụ xác minh cụ thể.

## Build trên GitHub

Push lên `main` chạy workflow **iOS build**. Mở Actions → lần chạy → Artifacts:

- `Lekapro-unsigned`: IPA chưa ký, SHA-256 và commit nguồn.
- `build-diagnostics`: log biên dịch và kết quả XCTest.

Commit có nhãn `[live-probe]` còn chạy các phép đo thật trên Fingerprint demo bằng simulator hiện có: UA 17.2/18.7.9 với API nguyên bản, cùng cặp UA thêm Audio rất nhỏ, và hai kho thử có hạn mức lưu trữ native 1/2 GiB với cùng UA thật. Đối chiếu giao diện/agent/server, event độc lập và tải lại; chỉ xuất số lượng, tính bằng nhau và tên nhóm thuộc tính, không xuất ID/event/IP hay ảnh trang. Kết quả simulator không thay thế phép thử trên iPhone thật. Nhãn `[quota-joint]` chọn riêng phép so sánh quota gần 38 GB cùng UA 18.4/18.7.9 và Audio nhỏ, để không lặp lại các phép đo đã xong. Các lần CI thông thường bỏ qua phép đo mạng này.

IPA chưa ký cần được ký bằng công cụ sideload phù hợp trước khi cài lên iPhone. Đăng nhập GitHub không cung cấp chứng chỉ Apple. Workflow không nhận Apple ID hay chứng chỉ ký. Bản build thành công chỉ xác nhận biên dịch và các kiểm thử đã chạy; proxy thật, DNS/UDP, camera của website và tương thích website vẫn cần kiểm thử thiết bị.

## Mở bằng Xcode

```sh
brew install xcodegen
xcodegen generate
open Lekapro.xcodeproj
```

Chọn Team cá nhân và Bundle Identifier phù hợp, rồi chạy trên iPhone. Trên iOS 16.1.1 jailbreak có thể cài IPA bằng TrollStore. Nhánh iOS 16 dùng API WebKit private, không dành cho phân phối App Store. Không cần thay đổi proxy toàn hệ thống hoặc cài tweak vào Safari.

## Kiểm tra iOS 16 trên thiết bị

Build 15 đã qua 25/25 XCTest, gồm giới hạn quota native có hiệu lực trong trang/Worker và kiểm tra lưu tab sau khi đóng. Trên simulator iOS 18.5, 12 event độc lập bổ sung (tổng 20 event simulator) vẫn cùng ID giữa hai hồ sơ trong từng phép so sánh; riêng quota 1/2 GiB được xác nhận áp dụng trong mỗi lượt truy cập HTTPS. Không gộp số đo simulator với 120 lượt thiết bị iOS 16.1.1. Xem [báo cáo build 15](verification/fingerprint-simulator-build15.json).

Simulator iOS 18.5, build 14 đã hoàn tất hai phép so sánh UA và Audio nhỏ: 8 event độc lập, khớp giao diện/agent/server, vẫn cùng ID giữa hai hồ sơ. Live test đạt; CI tổng còn một lỗi CancellationError ở tác vụ lưu trì hoãn. Bản sau đổi cách gộp lưu sang hàng đợi chính có số phiên bản để bỏ lần lưu cũ, giữ nguyên các kiểm tra về dữ liệu. Xem [báo cáo simulator build 14](verification/fingerprint-simulator-build14.json).

Phép thử quota chỉ dùng kho QA mới: đặt giới hạn native thực sự trong cấu hình WebKit, kiểm tra trang và Worker đọc đúng giới hạn, rồi mới so sánh Fingerprint. Không thay API JavaScript hoặc bổ sung StorageManager giả trên iOS 16; chưa có tùy chọn quota trong giao diện sản phẩm.

Build 12 đã hoàn tất sáu phép so sánh trên iOS 16.1.1: hai hồ sơ cùng dùng Audio rất nhỏ, thêm UA, thêm proxy, bảo vệ CPU trong Blob Worker, tổ hợp các tùy chọn, và đối chứng UA thật/API nguyên bản của iOS 16.1.1. Cả 24 lượt tải trong sáu phép so sánh đều khớp giao diện/agent/server, vẫn cùng Visitor ID (tổng 120 lượt hoàn chỉnh qua các bản). Lượt proxy đầu bị ngắt tải sau hai quan sát được lưu riêng; chạy lại cùng hồ sơ/kho đã hoàn tất. CI bản 12 có 21/22 XCTest đạt, một lỗi CancellationError giữa lúc WebKit khởi động chậm; bản sau tách tự chẩn đoán lúc mở app khỏi XCTest và chạy lại toàn bộ. Xem [báo cáo build 12](verification/fingerprint-experiments-build12.json).

Build 11 thêm 16 lượt đo (tổng 96), vẫn cùng Visitor ID trên cấu hình đã thử. Giảm CPU/màn hình và chặn WebGL thay các thuộc tính mà server đo được; CPU trong Worker còn nguyên, nên phần bảo vệ Worker được bổ sung riêng ở bản sau. Build và XCTest simulator đều qua. Xem [báo cáo build 11](verification/fingerprint-experiments-build11.json).

Build 10 thêm 12 lượt đo về họ phông và các tổ hợp (tổng 80), vẫn cùng Visitor ID trên cấu hình đã thử. WebKit thực sự thay các chỉ số font mà server đo được. Build và XCTest simulator đều qua. Xem [báo cáo build 10](verification/fingerprint-experiments-build10.json).

Build 9 thêm 16 lượt tải đã đối chiếu agent/server, nâng tổng lên 68. Múi giờ riêng có hiệu lực trong cả trang và Worker; cỡ chữ tối thiểu làm đổi chỉ số chữ/emoji thực. Các cấu hình này và tổ hợp thêm UA/proxy/nhiễu vẫn chưa tách Visitor ID. Build và XCTest simulator của bản 9 đều qua. Xem [báo cáo build 9](verification/fingerprint-experiments-build9.json).

Build 7–8 đã hoàn tất 11 phép so sánh trên iPhone 11 Pro Max iOS 16.1.1, tổng cộng 52 lượt tải Fingerprint demo. UA, proxy/IP, chặn hoặc nhiễu Canvas/Audio và chế độ desktop đều chưa tạo được hai Visitor ID khác nhau. Mỗi lượt được đối chiếu ID/event giữa giao diện, agent và server; không dùng giá trị cache làm bằng chứng. Xem [báo cáo đã loại dữ liệu riêng tư](verification/fingerprint-experiments-build7-8.json). Đây là kết quả trên cấu hình và thời điểm đã đo, không phải kết luận về mọi phiên bản ExitAnty hoặc mọi thiết bị.

Build Debug tự chạy kiểm tra trong hai kho dữ liệu chẩn đoán riêng của Lekapro, sử dụng HTML cục bộ. Báo cáo được ghi tại Documents/Lekapro-device-check.json. Báo cáo kiểm tra cookie, localStorage, IndexedDB, cách ly hai kho và lưu dữ liệu qua lần mở app tiếp theo. Cờ `PersistedFromPreviousLaunch` có thể false ở lần chạy đầu; cần đóng/mở app thêm lần nữa.

Thông tin SSH và mật khẩu thiết bị không được đưa vào repository hoặc workflow.

Bản 0.3 bổ sung lựa chọn User-Agent theo hồ sơ. Để QA trên thiết bị, build Debug đọc yêu cầu một lần từ Documents/Lekapro-ua-request.json chứa hai UUID hồ sơ thử riêng. Phép thử dùng giao diện trình duyệt bình thường, cùng kết nối trực tiếp và các API Canvas/Audio nguyên bản: hai UA 18.7.9 → A đổi sang 17.2 → A trở lại 18.7.9, mỗi điều kiện tải đầu và tải lại. UUID kho dữ liệu giữ nguyên. Chỉ ghi nhận khi Visitor ID và event của agent khớp phản hồi server. Kết quả thô nằm trong sandbox và không được đưa vào repo public. Các kết quả build 6 dưới đây là dữ liệu lịch sử trước khi thêm UA.

Bản 0.2.0 (build 6, nguồn `72d36b3`) đã cài và mở bằng TrollStore trên iPhone 11 Pro Max chạy iOS 16.1.1. Kiểm tra bằng hai kho chẩn đoán và HTML cục bộ xác nhận cookie, localStorage và IndexedDB được cách ly; cả ba còn nguyên sau khi kết thúc tiến trình rồi mở app lại. Xem [báo cáo lưu trữ](verification/ios-16.1.1-storage.json).

Đã tạo hai hồ sơ thật trong app: một kết nối trực tiếp và một dùng SOCKS5 có xác thực. WebKit tải dịch vụ kiểm tra IP và trả hai IP khác nhau; kiểm tra lại hồ sơ trực tiếp sau khi mở hồ sơ proxy cho cùng IP ban đầu. Cookie và localStorage giữa hai hồ sơ được cách ly. Kho thử riêng với SOCKS5 tại cổng không hoạt động trả lỗi kết nối. Báo cáo mạng, endpoint và thông tin xác thực của phép thử được giữ ngoài repository; mật khẩu proxy lưu trong Keychain. Các kết quả này chưa thay thế kiểm thử đăng nhập website, proxy HTTP/HTTPS hoặc packet capture DNS/UDP.

Trên [Fingerprint demo](https://fingerprint.com/demo/), hai hồ sơ thật hiện trả **cùng Visitor ID**, dù Server API Response của lượt tải lại ghi nhận hai IP khác nhau. Đã đo lần đầu và tải lại một lần trong mỗi hồ sơ: bốn event khác nhau, agent đều báo không dùng cache; Visitor ID ổn định. Bản hiện tại chưa cách ly fingerprint theo phép thử này. Ảnh và phản hồi gốc giữ ở máy phát triển; repo chỉ có [báo cáo đã loại dữ liệu định danh](verification/fingerprint-demo-comparison.json).

[CI build 6](https://github.com/raycola9969/Lekapro/actions/runs/39008359542): build iPhone thành công, 10 XCTest đạt trên simulator iOS 18.5.

## Dữ liệu và giới hạn

Cấu hình nằm trong Application Support với file protection. Mật khẩu proxy nằm trong Keychain `ThisDeviceOnly`. Nhân bản hồ sơ chỉ sao chép cấu hình, tạo UUID kho mới và không sao chép phiên đăng nhập. Nhập cấu hình cũng tạo UUID mới. Bản sao lưu chứa lịch sử/dấu trang và thông tin proxy, không chứa mật khẩu proxy hoặc dữ liệu WebKit. File cookie xuất có thể chứa token đăng nhập.

Xóa hồ sơ đóng các WebView trước khi xóa dữ liệu. Các tùy chọn chặn JavaScript áp dụng trong trang và iframe, chưa bao phủ mọi Worker. Danh sách chặn tracker hiện chỉ có một số domain phổ biến. Proxy cấu hình riêng theo từng kho WebKit; chưa có packet capture để chứng minh không rò DNS/UDP. Popup tạo cửa sổ được mở thành tab mới; luồng phụ thuộc `window.opener` cần kiểm thử thêm. Chưa có tùy chỉnh ngôn ngữ; múi giờ dùng cấu hình WebKit SPI đã mô tả ở trên. Nhiễu đọc Canvas/Audio đang thử nghiệm và chưa xác minh được khả năng tách Visitor ID.

Nguồn API: [WebKit profiles](https://webkit.org/blog/14423/building-profiles-with-new-webkit-api/), [WebKit SPI trước iOS 16.1](https://github.com/WebKit/WebKit/blob/1c25190c9ac675b28f04ff6fc65ef11047fff348/Source/WebKit/UIProcess/API/Cocoa/_WKWebsiteDataStoreConfiguration.h), [ProxyConfiguration](https://developer.apple.com/documentation/network/proxyconfiguration), [WKDownloadDelegate](https://developer.apple.com/documentation/webkit/wkdownloaddelegate).

Xem [CHECKLIST.md](CHECKLIST.md) để kiểm tra trên iPhone.
