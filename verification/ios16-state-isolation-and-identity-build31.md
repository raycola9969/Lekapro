# Cách ly trạng thái và đối chiếu quyết định cấp ID — iOS 16.1.1

Chưa có công thức bảo đảm mọi hồ sơ mới được Fingerprint cấp một Visitor ID riêng. Đợt này không lặp quét UA/noise: kiểm tra rò cookie/storage qua các kho dùng proxy, đọc lại ý nghĩa “khách mới/khách cũ” của phản hồi đã lưu, và đổi đường mạng trên đúng hai kho đang có hai ID riêng.

## Cookie và localStorage: ba kho, ba đường mạng

Build 31, máy thật iOS 16.1.1. Tạo ba kho native QA riêng qua chính `LegacyWebKitBridge` đang có: một trực tiếp, hai SOCKS5. Phép HTTPS `/ip` xác minh **ba IP thoát khác nhau**. Ba kho này không phải hồ sơ thông thường mới thêm vào cơ sở dữ liệu.

Tại nguồn thử cục bộ HTTPS giả lập không tải tài nguyên, ghi marker riêng vào cookie và localStorage. Tại nguồn HTTPS kiểm tra mạng, máy chủ `/cookies` trả cookie thực nhận từ WebKit. Ghi xen kẽ ba kho, đổi riêng marker kho giữa rồi đọc lại cả ba; khởi động lại app và lặp lại cùng ba đường dẫn.

| Kiểm tra | Kết quả |
|---|---|
| Cookie/localStorage mới chưa có marker | Đạt ở cả ba kho |
| Ghi xen kẽ vẫn đọc đúng marker từng kho | Đạt |
| Chỉ sửa kho giữa, hai kho còn lại giữ nguyên | Đạt |
| Máy chủ HTTPS nhận đúng cookie từng kho | Đạt |
| Mở lại app, cả ba kho giữ đúng marker đã ghi | Đạt |
| Đối chiếu marker | **72/72 assertion đạt** |
| Cấu hình hồ sơ/bản ghi proxy có trước | Giữ nguyên |

Không dùng interceptor hoặc sửa nội dung phản hồi. Hash đường dẫn trong bằng chứng chỉ xác nhận đường dẫn được yêu cầu; runtime không có getter cấu hình phù hợp để đọc lại. Không coi hash là getter native. Kết quả chứng minh cách ly/persistence trong hai nguồn được đo, không chứng minh mọi cache, salt, TLS, iframe hoặc nguồn bên thứ ba đều độc lập. Phép marker không truy cập Fingerprint và tạo **0 event Fingerprint**. [HTTPBingo: các endpoint kiểm tra](https://httpbingo.org/).

## Phân biệt ID chưa thấy và ID máy chủ mới cấp

Đọc lại raw reports đã có, không gọi dịch vụ thêm cho phần này. Cùng schema máy chủ và kiểm tra trang–agent–server của báo cáo gốc.

| Nhóm hồ sơ QA mới trong báo cáo đã lưu | Khách mới theo server | Khách đã biết theo server | ID khác nhau |
|---|---:|---:|---:|
| 20 kho CPU 4, UA Safari 17.2, trực tiếp | 20 | 0 | 20 |
| 12 kho proxy của đợt UA đối chứng, gồm baseline và tạo lại | 0 | 12 | 1 |

Ở 20 kho trực tiếp, `visitor_found=false` và `first_seen_at` bằng timestamp event đầu. Ở 12 kho proxy, `visitor_found=true`, cùng một ID đã xuất hiện khoảng sáu ngày trước; confidence nằm trong khoảng 0.92–0.99. Đây là nhận dạng về danh tính cũ, không phải 12 kho vô tình dùng chung UUID nội bộ. Cả hai nhóm là phép đo lịch sử; không cộng chúng thành số event mới của lần chạy này.

Hai JSON ExitAnty 2.2.2 người dùng cung cấp cũng có hai ID khác nhau nhưng **cả hai `visitor_found=true`**, thời điểm xuất hiện đầu trước lượt chụp khoảng 4.79 và 4.39 giờ. Đó là bằng chứng hai danh tính đã biết khác nhau, chưa phải bằng chứng mỗi lần tạo hồ sơ đều cấp danh tính mới. JSON này do người dùng cung cấp, không phải tôi tự lấy qua API máy chủ.

[Tài liệu Fingerprint](https://docs.fingerprint.com/docs/identification-accuracy-and-confidence) mô tả nhận diện bằng thuộc tính xác định hoặc đối sánh xác suất; có thể gán cùng ID cho hai trình duyệt khác nhau. Confidence không phải chứng nhận ID duy nhất và không chứng minh toàn bộ nguyên nhân giữ ID. Vì vậy các giá trị confidence quan sát được chỉ được diễn giải trong giới hạn đó.

## Đổi mạng trên đúng hai kho có ID riêng

Hai kho QA lưu bền từng có hai ID riêng trong lượt pool được giữ nguyên UUID, UA Safari 17.2, múi giờ, cookie và dữ liệu trang. Thứ tự: đo trực tiếp lại → gắn hai proxy có IP thoát khác nhau → tháo proxy và đo trực tiếp lại. Không reset, không sao chép cookie, không dùng getter CPU/màu QA, không can thiệp agent hoặc kết quả. Mỗi giai đoạn có bốn event không cache; mọi ID/event và UA đối chiếu trang–agent–server, IP proxy khớp đường mạng đã kiểm tra.

| Giai đoạn | ID khác nhau trong cặp | Kho giữ ID baseline | Kho giữ ID khi tải lại |
|---|---:|---:|---:|
| direct-baseline | 2/2 | 2/2 | 2/2 |
| proxy | 2/2 | 2/2 | 2/2 |
| direct-return | 2/2 | 2/2 | 2/2 |

Hai kho giữ đúng hai ID riêng sau khi gắn hai proxy. Kết quả cho thấy ID đã có có thể được giữ qua đổi mạng trong cặp này; không chứng minh khởi tạo qua mạng trực tiếp luôn cấp ID mới cho mọi kho.

Phép đổi mạng tạo **12 event mới, 0 hồ sơ mới**, dùng hai kho QA đã có. Mọi cấu hình hồ sơ và bản ghi proxy được trả về đúng giá trị trước phép thử; không di chuyển hay xóa kho website. Kết quả của hai kho hữu hạn không bảo đảm mọi hồ sơ tương lai hoặc thuật toán máy chủ không đổi.

## Thứ tự truy cập đầu tiên trên bốn kho mới

Cùng UA Safari iOS 17.2, CPU native 4, không nhiễu, không reset. Nhóm trực tiếp trước và nhóm proxy trước được đo xen kẽ. Mỗi nhóm có hai kho lưu bền mới; các lượt sau giữ nguyên UUID và dữ liệu, chỉ đổi gán proxy.

| Nhóm | Giai đoạn | Nhóm ID | ID khác nhau | Kho giữ ID truy cập đầu |
|---|---|---|---:|---:|
| direct-first | initial-direct | V1 / V1 | 1/2 | 2/2 |
| proxy-first | initial-proxy | V1 / V1 | 1/2 | 2/2 |
| direct-first | switch-to-proxy | V1 / V1 | 1/2 | 2/2 |
| proxy-first | switch-to-direct | V1 / V1 | 1/2 | 2/2 |
| direct-first | reopen-proxy | V1 / V1 | 1/2 | 2/2 |
| proxy-first | return-to-proxy | V1 / V1 | 1/2 | 2/2 |

Nhóm truy cập trực tiếp trước không đạt đủ hai ID riêng bền qua mọi giai đoạn. Kết quả này là phản ví dụ cho việc coi thứ tự truy cập là công thức bảo đảm.

Phần kiểm chứng thứ tự có **24 event mới / 4 hồ sơ QA mới**. Tổng hai phép đổi mạng trong báo cáo có **36 event mới**, khác với các event lịch sử được đọc lại ở trên. Cấu hình bốn hồ sơ QA được trả về cấu hình lúc tạo; hồ sơ có trước và bản ghi proxy được đối chiếu giữ nguyên. Không triển khai kết quả hữu hạn này thành mặc định cho người dùng.

Một kho trực tiếp đã có ID và một kho trực tiếp mới trong đợt này có cùng IP, UA, SDK, môi trường và toàn bộ `raw_device_attributes`, nhưng ID khác nhau. Lịch sử dữ liệu kho khác nhau nên không coi đây là hai đầu vào đầy đủ giống hệt nhau. Kết quả cho thấy danh sách raw đang hiển thị không đủ để tính hoặc giải thích duy nhất Visitor ID.

## Giới hạn kết luận và bước có thể bảo đảm

Đã kiểm chứng rò cookie/localStorage trong phạm vi nêu trên; chưa thấy rò. Điều này loại một lời giải thích hẹp cho việc trùng ID, chưa xác định đầy đủ mọi nguồn liên kết. Những phản ví dụ UA/proxy, pool và Color Depth 24 vẫn còn hiệu lực. [Phân tích IPA và các phản ví dụ](exitanty-ipa-reanalysis-ios16-build31.md).

IPA có sẵn là ExitAnty **2.0.0**, minimum OS 18; app người dùng đo là **2.2.2**. Không có binary 2.2.2 nên không thể tuyên bố đã xác định toàn bộ implementation của bản đang được đo. Không có bằng chứng trong mẫu đã phân tích về API cho phép client tùy chọn Visitor ID của Fingerprint.

Có thể kiểm soát quy tắc nghiệm thu: chỉ ghi nhận hồ sơ đạt khi ID thật vừa đo khác tất cả ID đã lưu trong cùng môi trường; nếu trùng thì ghi “không đạt”, nếu lỗi thì “chưa đo”, và kiểm tra lại khi mở. Quy tắc này chỉ bảo đảm **tập hồ sơ được chấp nhận không trùng tại các lần quan sát**, không bảo đảm luôn tạo được thêm hồ sơ, thời gian tạo hữu hạn hay ID không đổi về sau. Đây là phạm vi có thể kiểm tra, chưa được triển khai thành tính năng tạo hồ sơ và không thay thế mục tiêu ID ngoại vi mới cho mọi hồ sơ.

[JSON số liệu đã loại định danh](ios16-state-isolation-and-identity-build31.json). Không đưa raw ID, UUID kho, IP thoát hay thông tin đăng nhập proxy vào repo.
