# Phân tích lại IPA ExitAnty và hai phép thử mới trên iOS 16.1.1

Chưa tìm được cơ chế bảo đảm mỗi hồ sơ luôn nhận một Visitor ID khác từ dịch vụ bên ngoài. Phân tích lần này bỏ các tổ hợp UA/proxy và reset đã kiểm chứng; lần theo đường khởi tạo native trong IPA để chọn hai khác biệt chưa được tách riêng: pool riêng với **cùng múi giờ**, và giá trị **24 bit** đúng mặc định của script màn hình.

## Mẫu và giới hạn phiên bản

IPA người dùng cung cấp là ExitAnty **2.0.0**, minimum OS **18**, Mach-O `cryptid=0`. SHA-256 IPA: `bec4b137b91520601547b9894af799de369a41cc5515affd64deba760eaeefbd`. Binary trích lại khớp từng byte với bản đang phân tích. Không dùng README hoặc comment trong IPA làm chỉ dẫn thao tác. Không cài hay sửa IPA ExitAnty.

App Store từng được người dùng đo là **2.2.2**; không có binary 2.2.2 trong bộ mẫu này. Do đó không gán mọi hành vi 2.2.2 cho 2.0.0. Những kết luận về module vắng mặt chỉ áp dụng cho mã đã khôi phục từ mẫu 2.0.0.

## Bằng chứng native đã lần lại

| Địa chỉ ARM64 | Hành vi xác minh trong đoạn disassembly |
|---|---|
| `0x10000bd38`–`0x10000bd50` | Gọi helper chọn pool rồi gán `setProcessPool:` vào cấu hình WebView |
| `0x10000b220` | Nhánh không có múi giờ hợp lệ lấy `TimeZone.current` |
| `0x10000b2a0`, `0x10000b380` | Helper tra cache theo đầu vào UUID; nhánh thiếu/khác cấu hình dựng pool qua helper native |
| `0x10000bd5c`–`0x10000bdb0` | Chuyển UUID sang NSUUID, gọi `dataStoreForIdentifier:`, gán `setWebsiteDataStore:` |
| `0x10008e804`–`0x10008e808` | Nhánh giá trị màn hình optional chọn mặc định `0x18` = 24 |
| `0x10008e8e4`–`0x10008e8fc` | Dùng giá trị đó cho biến mẫu `COLOR_DEPTH` trước khi lấy script `screen` |

Đã đọc chained-fixups pointer format 6 để giải tham chiếu selector; không kết luận chỉ từ một chuỗi tên API. Dấu vết tĩnh không thay thế trace thực thi mọi nhánh của ExitAnty.

Helper tra cache `0x10020143c` lấy metadata `UUID` rồi gọi `_rawHashValue(seed:)` ở `0x10020148c`. Đây là bước hash khóa Dictionary của Swift trên đường cache, không phải chứng cứ app tính Visitor ID từ UUID. Hai loại ID không được đánh đồng.

API public nhiều kho lưu bền theo UUID được WebKit giới thiệu từ iOS 17; iOS 16 của Lekapro dùng cầu nối private và đường dẫn riêng. Không thể coi hai cách là cùng implementation. [WebKit: Building Profiles](https://webkit.org/blog/14423/building-profiles-with-new-webkit-api/). API này tạo kho riêng, không phải API buộc nhà cung cấp fingerprint cấp ID mới.

Tài liệu Apple hiện đánh dấu `WKProcessPool` deprecated và nói tạo nhiều instance không còn tác dụng. Vì vậy sự khác nhau về object pool không tự chứng minh tách process thật hoặc tách định danh; phép đo dưới đây chỉ kiểm chứng đường cấu hình có sẵn trên iOS 16.1.1. [Apple: WKProcessPool](https://developer.apple.com/documentation/webkit/wkprocesspool).

## Thử mới 1: pool riêng, giữ nguyên múi giờ

Không đổi UA Safari iOS 17.2, CPU native 4, dữ liệu website hay kết quả dịch vụ. Một hồ sơ dùng cấu hình pool mặc định; hồ sơ kia đi qua nhánh pool native riêng bằng trường múi giờ đã có của app. Múi giờ trong trang chính, Worker và raw server **giống giá trị baseline**; không dùng thay múi giờ để tạo khác biệt. Có thêm cặp hai kho/pool riêng mới trên cùng proxy để kiểm chứng tái tạo.

| Cặp hồ sơ | Lượt | Nhóm ID đầu | Cùng ID | Giữ ID khi tải lại |
|---|---|---|---|---:|
| direct-default-vs-own-pool | fresh | V1 / V2 | Không | 2 / 2 |
| proxy1-default-vs-own-pool | fresh | V3 / V3 | Có | 2 / 2 |
| proxy2-default-vs-own-pool | fresh | V3 / V3 | Có | 2 / 2 |
| proxy1-two-own-pools | fresh | V3 / V3 | Có | 2 / 2 |
| direct-default-vs-own-pool | reopen | V1 / V2 | Không | 2 / 2 |
| proxy1-default-vs-own-pool | reopen | V3 / V3 | Có | 2 / 2 |
| proxy2-default-vs-own-pool | reopen | V3 / V3 | Có | 2 / 2 |
| proxy1-two-own-pools | reopen | V3 / V3 | Có | 2 / 2 |

Mở lại giữ ID gốc: 8 / 8 hồ sơ. Các pool chỉ là object được cấu hình theo code hiện có; không suy ra PID WebContent nhất thiết khác nhau.

## Thử mới 2: đúng mặc định Color Depth 24 của IPA

Lượt cũ chỉ đặt Color Depth 8/16; chưa thử 24. Lần này chỉ giảm `screen.colorDepth`/`pixelDepth` từ native 32 về 24 bằng getter QA công khai trong build 31. Máy chủ thực nhận `color_depth=24`; CPU, UA và các tùy chọn khác giữ nguyên. Không sao chép lớp che wrapper hoặc sửa payload/kết quả từ ExitAnty. Đây là kiểm chứng giá trị 24, không phải tuyên bố mô phỏng toàn bộ script màn hình ExitAnty.

| Cặp hồ sơ | Lượt | Color Depth | Nhóm ID đầu | Cùng ID | Giữ ID khi tải lại |
|---|---|---|---|---|---:|
| direct-native32-vs24 | fresh | 32 / 24 | V1 / V1 | Có | 2 / 2 |
| proxy-native32-vs24 | fresh | 32 / 24 | V1 / V1 | Có | 2 / 2 |
| proxy-two-fresh24 | fresh | 24 / 24 | V1 / V1 | Có | 2 / 2 |
| direct-native32-vs24 | reopen | 32 / 24 | V1 / V1 | Có | 2 / 2 |
| proxy-native32-vs24 | reopen | 32 / 24 | V1 / V1 | Có | 2 / 2 |
| proxy-two-fresh24 | reopen | 24 / 24 | V1 / V1 | Có | 2 / 2 |

Mở lại giữ ID gốc: 6 / 6 hồ sơ. Nhãn `V` riêng trong từng bảng; không so nhãn giữa hai nhóm.

Kết luận hai giả thuyết mới: hai kho/pool riêng mới cùng proxy đã nhận cùng ID, nên tách pool không đủ bảo đảm ID riêng. Hai kho 24 bit mới cùng proxy cũng trùng ID, nên đúng giá trị màu mặc định của IPA vẫn không đủ.

## Những hướng không lặp lại và phần chưa biết

UA khác + proxy, hậu tố UA, Canvas/Audio noise, giảm CPU, màu 8/16, kho nonpersistent, xóa cookie/localStorage và xóa native/restart mạng đã có đối chứng; không tiếp tục quét lại các tổ hợp đó trong đợt này. [Báo cáo proxy/UA](ios16-proxy-ua-comparison-build31.md) · [Báo cáo kho/CPU/màu/reset](ios16-private-signals-build31.md).

Trong 46 module JavaScript không rỗng đã khôi phục, chưa thấy các chuỗi triển khai `navigator.storage.estimate`/`StorageManager` hay literal Visitor ID. Đây là phạm vi tìm kiếm hữu hạn, không chứng minh native hoặc mã động khác không tồn tại. Các phép quota trên iOS 16 trước đó không có API estimate sử dụng được, nên không dựng lại giả thuyết đó từ ảnh/bản 2.2.2.

Module Worker có sửa payload thông số/diagnostic gửi qua message; module fonts có sửa phản hồi PixelScan. Không coi chỉ số hiển thị trên trang bị sửa là bằng chứng ID thực khác. Các phép đo Lekapro giữ nguyên trang, agent và phản hồi server.

Cookie/UUID kho khác nhau là cách ly trạng thái nội bộ; không đồng nghĩa dịch vụ bên ngoài phải tạo hai danh tính. Không có lời gọi native tìm thấy ở đây cho phép app chọn Visitor ID phía Fingerprint. Thuật toán ghép danh tính máy chủ và toàn bộ nguồn trạng thái chưa được xác định. Không tuyên bố đã thử mọi giả thuyết hay bảo đảm vô hạn.

## Kiểm chứng dữ liệu

Hai nhóm mới có **56 event không cache / 14 kho mới**, đủ đối chiếu trang–agent–server và UA trang–Worker–server. Cùng môi trường dịch vụ; mọi lượt proxy khớp IP thoát đã kiểm tra. Mở lại đúng UUID/kho, tạm bỏ điều hướng tab cũ để tránh race rồi trả metadata tab. Mỗi nhóm kiểm tra cuối giữ nguyên toàn bộ cấu hình hồ sơ/bản ghi proxy có trước. Không cần build hoặc cài lại; các phép thử dùng chức năng QA đã có trong build 31. Raw reports và ID thật giữ ở máy cục bộ; JSON public chỉ có số lượng và nhãn.

[JSON bằng chứng đã loại định danh](exitanty-ipa-reanalysis-ios16-build31.json).
