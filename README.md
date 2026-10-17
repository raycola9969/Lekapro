# Lekapro

Trình duyệt iOS nhiều hồ sơ, viết mới bằng SwiftUI và WKWebView. Bản 0.3 hỗ trợ iOS 16.1 trở lên, với nhánh tương thích dành cho thiết bị jailbreak/TrollStore.

## Kết quả mới trên iOS 16.1.1

Build 21 đã cài trên iPhone 11 Pro Max iOS 16.1.1 và xác nhận **ba hồ sơ cùng UA Safari 17.2 giữ ba Visitor ID khác nhau** sau tải lại và đóng/mở app. Các hồ sơ đã lưu trên máy là `03 - Safari 17.2 A`, `04 - Safari 17.2 B`, `05 - Safari 17.2 C`. A được đo lần đầu bằng UA iPhone Chrome 119, B bằng UA WebKit mặc định, C bằng chuỗi UA Windows Firefox 119; sau đó A/C đổi về Safari 17.2, giữ nguyên kho của từng hồ sơ. Engine thật vẫn là WebKit iOS 16.1.1. UA trong trang, Worker và phản hồi server đều khớp cấu hình cuối.

Đợt build 21 có 72 event mới, không dùng cache, đối chiếu ID/event giữa trang, agent và server trên cùng IP. Ba đối chứng riêng ở hồ sơ thử dùng một lần cho thấy: xóa cookie native (24→0), xóa localStorage, hoặc gọi WebKit xóa tất cả loại dữ liệu website công khai đều chưa làm hai ID đang có nhập lại. Việc xóa cookie được đếm trực tiếp; chưa kiểm kê độc lập mọi trạng thái nội bộ hay trạng thái ở server. Các nhóm thuộc tính thiết bị thô bằng nhau giữa các hồ sơ ở lượt tải lại cuối. UA Android Chrome và Windows Chrome không tạo ID mới ngoài cặp đã có. Xem [báo cáo build 21 đã loại dữ liệu định danh](verification/ios16-site-state-build21.json). [CI build 21](https://github.com/raycola9969/Lekapro/actions/runs/39051220994) đạt 27 bài kiểm thử, một bài đo mạng bỏ qua.

Trên iPhone 11 Pro Max chạy iOS 16.1.1, build 20 đã được cài và kiểm chứng hai Visitor ID khác nhau tại fingerprint.com/demo: hồ sơ A dùng UA iPhone Chrome 119, hồ sơ B dùng UA WebKit mặc định. Cả hai vẫn báo nền tảng iPhone, kết nối trực tiếp cùng IP, tắt chặn tracker, dùng Canvas/Audio và các API nguyên bản. Mười hai event mới không dùng cache xác nhận ID hiển thị khớp phản hồi JavaScript và máy chủ: cặp đã đo giữ ID qua cập nhật 19→20, một cặp mới ổn định khi tải lại và sau khi kết thúc/mở lại app. Không dùng tùy chọn engine chẩn đoán, Frida hoặc sửa kết quả website. Xem [báo cáo đã loại dữ liệu định danh](verification/ios16-browser-family-build20.json). [CI build 20](https://github.com/raycola9969/Lekapro/actions/runs/39045021797) đạt 26 bài kiểm thử, bỏ qua một bài đo mạng chưa bật trong CI.

Đã kiểm chứng thêm 48 event trên build 20: khởi tạo hai ID bằng cặp UA Chrome/mặc định, rồi đổi đúng hai hồ sơ sang cùng UA Safari 17.2 vẫn giữ hai ID qua tải lại và mở lại app. Cặp Safari 17.2/18.7.9 cũng giữ được ID theo cách này. Khi đổi UA, giữ cùng kho dữ liệu. Các thuộc tính thiết bị thô bằng nhau ở lượt tải lại. Hồ sơ mới tạo trực tiếp với cùng UA Safari hoặc cặp Safari 17.2/18.7.9 vẫn cho một ID. Xem [đối chứng chuyển UA và lưu trạng thái](verification/ios16-state-retention-build20.json).

Đây là kết quả nhận diện phụ thuộc lịch sử truy cập đã quan sát; nguyên nhân lưu giữ cụ thể chưa được tách riêng. Chưa chứng minh dấu vân tay phần cứng khác nhau hoặc ID riêng cho mọi UUID hồ sơ. Đối chứng hai hồ sơ mới cùng UA Chrome cũng cho cùng ID. Đổi riêng nền tảng sang iPad không tách được ID; UA iPad tách được trong phép thử riêng. Chưa xác định cơ chế nội bộ ExitAnty 2.2.2.

Để lặp lại hồ sơ C trong đợt thử: tạo kho mới, tắt các tùy chọn bảo vệ để dùng API gốc, đặt UA tùy chỉnh dưới đây, mở demo và đo; sau đó sửa chính hồ sơ đó sang preset Safari 17.2. Việc đổi UA áp dụng khi đóng/mở trình duyệt hồ sơ. Đây là cấu hình đã đo trên máy này; chưa bảo đảm một ID mới cho mỗi hồ sơ C tạo thêm. App chỉ truy cập demo khi người dùng hoặc bộ đo DEBUG yêu cầu.

```text
Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:119.0) Gecko/20100101 Firefox/119.0
```

Build 20 đưa các chuỗi đã thử vào menu User-Agent: iPhone Chrome 119, iPhone Firefox 119 và iPad Safari 16.1. Đây là lựa chọn chuỗi UA; app tiếp tục dùng WebKit của hệ điều hành. Để lặp lại cặp đã xác nhận, chọn Chrome ở A, Tự động theo WebKit ở B và tắt chặn tracker trong cả hai.

## Đã triển khai

- Tạo, sửa, sao chép cấu hình, tìm kiếm và xóa hồ sơ.
- iOS 17+: kho dữ liệu công khai theo UUID. iOS 16.x: cấu hình WebKit SPI với thư mục riêng trong sandbox của Lekapro. Các tab cùng hồ sơ chia sẻ một đối tượng kho dữ liệu.
- Khôi phục tối đa 30 tab/hồ sơ; dấu trang, lịch sử, nhãn và ghi chú.
- Kho proxy SOCKS5 và HTTP CONNECT; HTTPS CONNECT tới proxy được hỗ trợ từ iOS 17. Mật khẩu lưu trong Keychain.
- iOS 17+: `allowFailover = false`. iOS 16 dùng cấu hình proxy riêng của WebKit; phép thử với SOCKS5 tại cổng không có máy chủ đã trả lỗi kết nối, không tải trang trực tiếp. Chưa đo DNS/UDP hoặc mọi tình huống thay đổi mạng.
- Bộ chặn tracker cơ bản; tùy chọn chặn đọc Canvas/Audio và chặn WebRTC.
- Tùy chọn chặn tạo ngữ cảnh WebGL và giảm thông tin phần cứng: tối đa 2 luồng được báo cho trang, kích thước màn hình làm tròn xuống theo bậc 200 px. Mặc định tắt; áp dụng trong trang/frame, chưa bao phủ Worker. Có thể ảnh hưởng đồ họa 3D, bố cục và xử lý song song; không bảo đảm tách Visitor ID.
- Thử nghiệm áp dụng các thiết lập trên cho classic Blob Worker được tạo trong trang qua `URL.createObjectURL`. Mặc định tắt; giữ MIME và kiểm tra CSP, không sửa thông điệp của Worker. Chưa bao phủ module, URL ngoài, Shared/Service Worker hoặc mọi Worker lồng nhau. Địa chỉ Blob Worker thay đổi; CSP có thể chặn việc nạp script bổ sung, khi đó cần tắt tùy chọn này để giữ tương thích.
- User-Agent theo hồ sơ: mặc định WebKit, preset iPhone Safari 17.2/18.7.9, iPad Safari 16.1, iPhone Chrome/Firefox 119 và chuỗi tùy chỉnh. Đổi UA giữ UUID kho dữ liệu; không đổi iOS/WebKit thật.
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

## Kiểm tra trên thiết bị

**Build 17 đã xác nhận hai Visitor ID khác nhau trên iPhone 13 Pro iOS 18.7.8.** Hồ sơ A dùng UA iOS 17.2 Safari, nhiễu Canvas và Audio mức tiêu chuẩn; hồ sơ B dùng UA WebKit thật và API gốc. Cả hai kết nối trực tiếp, cùng IP. Tám event mới trong hai lượt mở tiến trình, mỗi hồ sơ tải đầu và tải lại, đều khớp ID/event giữa giao diện, agent và Server API Response; hai ID giữ nguyên sau khi đóng/mở app. UUID hồ sơ/kho không đổi, agent không dùng cache. Xem [báo cáo thiết bị iOS 18](verification/ios18-stock-build17.json).

Đây là kết quả của một cấu hình kết hợp trên một thiết bị, chưa xác định API nào riêng lẻ là nguyên nhân và không chứng minh cơ chế nội bộ ExitAnty 2.2.2. Trên cùng iPhone iOS 18, phép thử chỉ đổi UA (12 event), hai kho mới khác UA ngay lần đầu (4 event), và hai biến thể Audio rất nhỏ thêm UA (8 event) vẫn cùng ID. Tổng 32 event thiết bị iOS 18 đã đối chiếu, tách khỏi số đo simulator.

Đã thử đúng cấu hình đạt ở trên trên iPhone 11 Pro Max iOS 16.1.1, build 15: thêm 4 event hợp lệ nhưng vẫn một ID, dù server ghi nhận Canvas/Audio thay đổi. Tổng thiết bị iOS 16 là 128 event; chưa đạt hai ID trên máy này. Xem [đối chứng iOS 16](verification/ios16-native-control-build15.json).

[CI build 17](https://github.com/raycola9969/Lekapro/actions/runs/39036041400) đạt: 25 kiểm thử chạy thành công, một live network test bỏ qua vì không bật opt-in. Có kiểm thử thực việc trình bày hai trình duyệt liên tiếp. Bộ đo trên thiết bị chờ cửa sổ sẵn sàng, trình bày browser bằng UIKit và khôi phục trạng thái tự khóa sau khi đo. Công cụ tạo hồ sơ QA bên ngoài cũng đã sửa lỗi đặt `about:blank` nhầm vào trang chủ: trang chủ giữ HTTP/HTTPS hợp lệ, tab ban đầu được phép trống. Những lượt lỗi này không tính vào số đo hợp lệ.

Build 16 cũng qua 25/25 XCTest. Tổ hợp hai quota tổng hợp gần 38 GB, UA và Audio nhỏ đã tạo 4 event độc lập mới, xác nhận quota native áp dụng, nhưng vẫn cùng ID trên simulator (tổng 24 event simulator). Xem [báo cáo build 16](verification/fingerprint-simulator-build16.json). Trên iPhone iOS 16.1.1, build 15 đã cài và đo lại cùng hai kho qua lượt mở app mới: thêm 4 event, tổng 124 lượt thiết bị, ID giữ nguyên và API Storage estimate không có. Xem [báo cáo mở lại](verification/ios16-build15-relaunch.json).

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

Trong phép thử build 6 trên [Fingerprint demo](https://fingerprint.com/demo/), hai hồ sơ trả **cùng Visitor ID**, dù Server API Response của lượt tải lại ghi nhận hai IP khác nhau. Đã đo lần đầu và tải lại một lần trong mỗi hồ sơ: bốn event khác nhau, agent đều báo không dùng cache; Visitor ID ổn định. Cấu hình build 6 chưa tách ID trong phép thử này. Ảnh và phản hồi gốc giữ ở máy phát triển; repo chỉ có [báo cáo đã loại dữ liệu định danh](verification/fingerprint-demo-comparison.json).

[CI build 6](https://github.com/raycola9969/Lekapro/actions/runs/39008359542): build iPhone thành công, 10 XCTest đạt trên simulator iOS 18.5.

## Dữ liệu và giới hạn

Cấu hình nằm trong Application Support với file protection. Mật khẩu proxy nằm trong Keychain `ThisDeviceOnly`. Nhân bản hồ sơ chỉ sao chép cấu hình, tạo UUID kho mới và không sao chép phiên đăng nhập. Nhập cấu hình cũng tạo UUID mới. Bản sao lưu chứa lịch sử/dấu trang và thông tin proxy, không chứa mật khẩu proxy hoặc dữ liệu WebKit. File cookie xuất có thể chứa token đăng nhập.

Xóa hồ sơ đóng các WebView trước khi xóa dữ liệu. Các tùy chọn chặn JavaScript áp dụng trong trang và iframe, chưa bao phủ mọi Worker. Danh sách chặn tracker hiện chỉ có một số domain phổ biến. Proxy cấu hình riêng theo từng kho WebKit; chưa có packet capture để chứng minh không rò DNS/UDP. Popup tạo cửa sổ được mở thành tab mới; luồng phụ thuộc `window.opener` cần kiểm thử thêm. Chưa có tùy chỉnh ngôn ngữ; múi giờ dùng cấu hình WebKit SPI đã mô tả ở trên. Nhiễu đọc Canvas/Audio đang thử nghiệm; cấu hình kết hợp ở trên đã đạt hai ID trên một iPhone iOS 18.7.8 nhưng chưa đạt trên iOS 16.1.1 và không bảo đảm kết quả ở mọi môi trường.

Nguồn API: [WebKit profiles](https://webkit.org/blog/14423/building-profiles-with-new-webkit-api/), [WebKit SPI trước iOS 16.1](https://github.com/WebKit/WebKit/blob/1c25190c9ac675b28f04ff6fc65ef11047fff348/Source/WebKit/UIProcess/API/Cocoa/_WKWebsiteDataStoreConfiguration.h), [ProxyConfiguration](https://developer.apple.com/documentation/network/proxyconfiguration), [WKDownloadDelegate](https://developer.apple.com/documentation/webkit/wkdownloaddelegate).

Xem [CHECKLIST.md](CHECKLIST.md) để kiểm tra trên iPhone.
