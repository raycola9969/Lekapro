# Lekapro

Trình duyệt iOS nhiều hồ sơ, viết mới bằng SwiftUI và WKWebView. Bản 0.3 hỗ trợ iOS 16.1 trở lên, với nhánh tương thích dành cho thiết bị jailbreak/TrollStore.

## Múi giờ theo IP — build 33

Hồ sơ mới mặc định **Theo IP (tự động)**: lấy IP thoát qua proxy của hồ sơ, áp dụng múi giờ native cho trang/Worker trước khi mở web hoặc kiểm tra ID. Lỗi tra cứu giữ các tab và cho thử lại; không dùng múi giờ máy thay thế. Đã đo trực tiếp/proxy trên iOS 16.1.1 và giữ danh sách hồ sơ sạch. [Kết quả và hướng dẫn](verification/ip-timezone-build33.md).

## Kiểm tra ID trước khi dùng hồ sơ — build 32

Đã cài và đo trên iOS 16.1.1: **4 ứng viên, 1 được nhận, 3 trùng bị tự xóa**, qua hai lần khởi động app. Khi bật kiểm tra, hồ sơ mới chỉ được dùng nếu ID thật không trùng lịch sử Lekapro; lỗi đo giữ trạng thái chưa đạt. Hồ sơ cũ không tự bị xóa và cần được đo để tham gia đối chiếu. Không bảo đảm cấp ID mới vô hạn hoặc ID không đổi về sau. [Cách dùng, bảng đo và giới hạn](verification/profile-id-admission-build32.md).

## Kiểm chứng mới: trạng thái kho và đổi đường mạng

Ba kho native qua ba IP thoát đạt **72/72 kiểm tra cookie/localStorage**, gồm ghi xen kẽ, cookie HTTPS thực nhận và khởi động lại app. Đã chạy thêm phép trực tiếp → hai proxy → trực tiếp trên hai kho đang có ID riêng và đối chứng thứ tự truy cập bằng bốn kho mới, tổng **36 event mới**; không reset hay đổi UA. [Kết quả và phạm vi bảo đảm](verification/ios16-state-isolation-and-identity-build31.md).

## Phân tích lại IPA ExitAnty và kiểm chứng mới

Đã lần lại đường tạo pool/kho theo UUID và mặc định Color Depth 24 trong IPA ExitAnty 2.0.0. Hai phép thử mới trên iOS 16.1.1 có **56 event / 14 kho mới**: pool riêng giữ cùng múi giờ vẫn trùng ID qua proxy; hai kho mới 24 bit cũng trùng ID. Cả 14 kho giữ ID khi mở lại, nhưng chưa có cơ chế bảo đảm mỗi kho nhận một Visitor ID riêng. IPA mẫu yêu cầu iOS 18 và khác bản App Store 2.2.2 từng được đo. [Bằng chứng ARM64, bảng đo và giới hạn](verification/exitanty-ipa-reanalysis-ios16-build31.md).

## Kết quả mới nhất: proxy và UA iOS, build 31

Trên máy thật iOS 16.1.1, **8 hồ sơ mới dùng UA Safari 17.2/18.4 qua 4 proxy, qua hai lượt tạo kho, chỉ nhận một ID chung và trùng ID của đối chứng UA 16.1.1**. Máy chủ nhận đúng UA và IP thoát; mở lại 10 kho đầu đều giữ ID ban đầu. Toàn đợt có 48 event không cache và 14 kho mới. [Bảng đối chiếu và giới hạn kết luận](verification/ios16-proxy-ua-comparison-build31.md).

[Đợt build 31 trước đó](verification/ios16-private-signals-build31.md) từng đạt 20 kho / 20 ID riêng khi không gắn proxy trong app, giữ cả 20 ID khi mở lại. Đối chứng không reset cùng đợt cũng nhận ID mới, nên chưa xác định reset là nguyên nhân. Các kết quả hữu hạn này chưa bảo đảm mỗi hồ sơ tương lai có ID riêng.

## Đo lại 12 OS token với cả ba trình duyệt iOS

Đã đo lại **12 OS token × 3 họ UA = 36 hồ sơ mới**, mỗi hồ sơ có kho độc lập, **không proxy và không hậu tố**, trên iPhone 11 Pro Max **iOS 16.1.1, build 29**. Đây là 12 OS token Safari không trùng trong từng lượt A/B/C được chọn để kiểm chứng thêm. Safari giữ đúng UA đã dùng ở lượt C; Chrome giữ `CriOS/119.0.6045.41`, Firefox giữ `FxiOS/119.0` để chỉ thay OS token. Các mẫu UA là cấu hình thử nghiệm trên engine iOS 16.1.1, không phải cài các hệ điều hành tương ứng.

Kết quả lần này: **11 ID khác nhau / 36 hồ sơ**. Trong từng họ: **Safari 9/12**, **Chrome iOS 1/12**, **Firefox iOS 1/12**. Có 7/36 hồ sơ không trùng ID với UA khác trong lượt này; 29/36 hồ sơ nằm trong nhóm trùng. **36/36 hồ sơ giữ ID khi tải lại**.

| OS token trong UA | Safari | Chrome iOS 119 | Firefox iOS 119 |
| --- | --- | --- | --- |
| 26.4.1 | D1 | D2 | D3 |
| 26.4.2 | D1 | D2 | D3 |
| 26.5 | D1 | D2 | D3 |
| 26.5.1 | D4 | D2 | D3 |
| 26.5.2 | D5 | D2 | D3 |
| 26.6 | D6 | D2 | D3 |
| 26.6.1 | D7 | D2 | D3 |
| 26.6.2 | D8 | D2 | D3 |
| 26.7 | D9 | D2 | D3 |
| 26.7.1 | D10 | D2 | D3 |
| 27.0 | D10 | D2 | D3 |
| 27.0.1 | D11 | D2 | D3 |

[Bảng đầy đủ 36 UA và đối chiếu lần trước (CSV)](verification/ios16-ua-twelve-os-three-build29.csv) · [Báo cáo đầy đủ (JSON)](verification/ios16-ua-twelve-os-three-build29.json). Nhãn D chỉ thể hiện ID bằng nhau/khác nhau trong đợt mới, không chứa ID thật; không so trực tiếp tên D với nhãn G/C/R của đợt khác.

Trong 12 Safari UA trùng chính xác đầu vào với lượt C, **0/12 nhận lại đúng ID của lượt C**. Xét các lượt quét/lặp đã đối chiếu của cùng chuỗi UA, 24/36 hồ sơ nhận một ID từng thấy với chính UA đó. Đây là quan sát đo lại, không bảo đảm hồ sơ tạo tiếp có ID riêng và không chứng minh riêng OS token là nguyên nhân.

Có **72 event mới không dùng cache**, ID/event khớp trang–agent–server, UA khớp trang–Worker–server; máy chủ nhận đúng iPhone/iOS và OS token. Cùng IP và môi trường máy chủ trong đợt đo. Đã loại 0 cặp thiếu số đo Worker, phát sinh 0 hồ sơ thay thế ngoài 36 kết quả đạt; các event bị loại không nằm trong tổng. Toàn bộ 864 cấu hình hồ sơ có trước, gồm 63 hồ sơ lịch sử được bảo vệ, giữ nguyên. Không đổi mã app/engine, không chép/xóa dữ liệu website hoặc sửa ID/phản hồi nhà cung cấp.

## Thử 20 hồ sơ: phiên bản trình duyệt và hậu tố UA

Đã tạo và đo **20 hồ sơ mới, 20 chuỗi UA khác nhau**, **không proxy**, trên iPhone 11 Pro Max **iOS 16.1.1, build 29**. Có 10 cặp với kho độc lập: mỗi mẫu UA có một bản gốc và một bản thêm `Lekapro/1.0 Profile/Pxx` riêng. Bộ thử gồm 8 hồ sơ Safari (16.1, 17.2, 18.4, 26.0), 6 Chrome iOS (119, 120, 121) và 6 Firefox iOS (119, 120, 121). Chrome/Firefox giữ OS token 16.1.1 để so phiên bản trình duyệt; Safari 26.0 dùng OS token 18.6.

Kết quả: **3 ID khác nhau / 20 hồ sơ**; **10/10 cặp UA gốc–hậu tố cùng ID lúc tải đầu**, 0/10 cặp khác ID. Có **20/20 hồ sơ giữ ID khi tải lại**. Đây là kết quả quan sát của lượt này, chưa chứng minh công thức cấp ID riêng cho mọi hồ sơ.

| Mẫu iOS / trình duyệt | UA gốc | UA thêm hậu tố riêng | Cùng ID lúc tải đầu? |
| --- | --- | --- | --- |
| Safari 16.1 / OS 16.1.1 | G1 | G1 | Có |
| Safari 17.2 / OS 17.2 | G1 | G1 | Có |
| Safari 18.4 / OS 18.4 | G1 | G1 | Có |
| Safari 26.0 / OS 18.6 | G1 | G1 | Có |
| Chrome 119.0.6045.41 / OS 16.1.1 | G2 | G2 | Có |
| Chrome 120.0.6099.101 / OS 16.1.1 | G2 | G2 | Có |
| Chrome 121.0.6167.138 / OS 16.1.1 | G2 | G2 | Có |
| Firefox 119.0 / OS 16.1.1 | G3 | G3 | Có |
| Firefox 120.0 / OS 16.1.1 | G3 | G3 | Có |
| Firefox 121.0 / OS 16.1.1 | G3 | G3 | Có |

[Bảng 20 UA và kết quả (CSV)](verification/ios16-ua-versions-suffix20-build29.csv) · [Báo cáo đầy đủ (JSON)](verification/ios16-ua-versions-suffix20-build29.json). Nhãn G chỉ thể hiện ID bằng nhau/khác nhau trong lượt này; không chứa Visitor ID thật.

Có **40 event mới không dùng cache**, ID/event khớp trang–agent–server và UA khớp trang–Worker–server. Máy chủ nhận đúng iPhone/iOS và phiên bản major trình duyệt ở 20/20 hồ sơ. Trường browser-details khớp toàn bộ số phiên bản ở 14/20 hồ sơ; với 6 hồ sơ Chrome, parser bỏ thành phần số thứ tư nhưng UA thô vẫn giữ nguyên đầy đủ. Cùng IP và môi trường máy chủ trong lượt đo. Đã loại 1 cặp thiếu Worker, phát sinh 2 hồ sơ thay thế ngoài 20 kết quả đạt; các event bị loại không nằm trong tổng. Toàn bộ 842 cấu hình hồ sơ có trước, gồm 63 hồ sơ lịch sử được bảo vệ, giữ nguyên. Không đổi mã app/engine, không chép/xóa dữ liệu website, không sửa ID hoặc phản hồi nhà cung cấp. Cặp dùng kho mới khác nhau nên nếu tách ID cũng chưa thể quy riêng nguyên nhân cho hậu tố.

## Đo thêm một lần đúng 18 UA không trùng trước đó

Đã lấy đúng **18 UA** được đánh dấu không trùng trong cả hai lượt A/B, tạo **18 hồ sơ với kho mới** và đo thêm **một lần C** trên iPhone 11 Pro Max **iOS 16.1.1, build 29**. Mỗi hồ sơ tải đầu và tải lại, tổng **36 event mới không dùng cache**.

Kết quả lượt C: **15/18 ID khác nhau**, có **1 nhóm trùng giữa các UA khác nhau**. Kết quả không lặp lại được đầy đủ: một số UA của nhóm 18 đã nhận cùng ID trong lượt C. Đây là kết quả của lượt đo này, chưa bảo đảm ID riêng cho các hồ sơ tạo tiếp.

| UA | ID nhóm C | Trùng UA khác ở C? |
| --- | --- | --- |
| Chrome iOS 17.2 | G2 | Không |
| Firefox iOS 17.2 | G3 | Không |
| Safari 26.0 (OS 18.6) | C1 | Có |
| Safari iOS 26.0.1 | C1 | Có |
| Safari iOS 26.2.1 | C1 | Có |
| Safari iOS 26.3.1 | C1 | Có |
| Safari iOS 26.4.1 | C2 | Không |
| Safari iOS 26.4.2 | C3 | Không |
| Safari iOS 26.5 | C4 | Không |
| Safari iOS 26.5.1 | C5 | Không |
| Safari iOS 26.5.2 | C6 | Không |
| Safari iOS 26.6 | C7 | Không |
| Safari iOS 26.6.1 | C8 | Không |
| Safari iOS 26.6.2 | C9 | Không |
| Safari iOS 26.7 | C10 | Không |
| Safari iOS 26.7.1 | C11 | Không |
| Safari iOS 27.0 | C12 | Không |
| Safari iOS 27.0.1 | C13 | Không |

[Bảng 18 chuỗi UA và đối chiếu A/B/C (CSV)](verification/ios16-ua-third-build29.csv) · [Báo cáo lượt C (JSON)](verification/ios16-ua-third-build29.json). Nhãn G/R/C chỉ thể hiện ID bằng nhau hay khác nhau; không chứa Visitor ID thật.

Trong lượt C, 2 hồ sơ nhận lại ID của cùng UA ở lượt A, 2 hồ sơ nhận lại ID của cùng UA ở lượt B. ID từng hồ sơ giữ qua tải lại, khớp trang/agent/server; UA khớp trang/Worker/server. So với A/B, IP giống, môi trường máy chủ giống. Mọi UUID hồ sơ/kho trong lượt C đều mới; 63 hồ sơ lịch sử được giữ nguyên. 0 cặp thiếu Worker bị loại khỏi tổng đạt. App và engine không đổi.

## Tạo lại hồ sơ với các UA từng cho ID khác nhau

Đã chạy một đợt đo mới theo yêu cầu tạo lại hồ sơ. Tập lịch sử 63 ID có **59 chuỗi UA khác nhau**; bốn chuỗi từng gắn với nhiều ID, nên được gộp theo đúng chuỗi đầu vào. Mỗi UA có một kho mới ở lượt A và một kho mới ở lượt B: **118 hồ sơ mới**, **236 event không dùng cache**, trên cùng iPhone 11 Pro Max **iOS 16.1.1, build 29**. Đo hết 59 UA của lượt A rồi mới đo lại chúng ở lượt B; không dùng lại kho cũ.

Lượt A: **55/59 ID khác nhau**. Lượt B: **21/59 ID khác nhau**. Cả 118 hồ sơ có **74 ID**. Khi so hai hồ sơ mới có cùng UA: **2/59 cặp cùng ID**, **57/59 cặp khác ID**. So với tập 84 ID của đợt quét 94 phiên bản và lượt lặp tiếp theo, có 3 ID được dùng lại và 71 ID ngoài chính tập tham chiếu đó. Các con số này là kết quả của đợt đo, chưa phải bảo đảm cho mọi hồ sơ tạo thêm.

| Safari UA iOS | Lượt A | Lượt B | A và B cùng ID? |
| --- | --- | --- | --- |
| 17.2 | G56 | R53 | Không |
| 18.4 | R52 | R71 | Không |
| 26.0 | R1 | R53 | Không |
| 26.1 | R52 | R71 | Không |
| 26.2 | R52 | R71 | Không |
| 26.3 | R52 | R71 | Không |
| 26.4 | R52 | R71 | Không |

G/N/R là nhãn đối chiếu tính bằng nhau, không chứa Visitor ID thật. [Bảng đủ 59 UA và chuỗi UA chính xác (CSV)](verification/ios16-ua-recreation-build29.csv) · [Báo cáo đầy đủ (JSON)](verification/ios16-ua-recreation-build29.json).

Có **18/59 UA không trùng với UA nào khác trong cả hai lượt đã đo**. Cột `No cross-UA collision in either measured wave` trong CSV đánh dấu các trường hợp đó. Đây là quan sát của hai lượt này, chưa bảo đảm ID riêng ở lượt tạo hồ sơ tiếp theo.

Từng hồ sơ giữ ID khi tải lại. ID và event khớp trang/agent/server; UA khớp trang/Worker/server; máy chủ nhận iPhone/iOS và OS token đã cấu hình. Trong đợt mới, IP và môi trường máy chủ thống nhất; so với đợt lặp trước, IP giống và môi trường máy chủ giống. 2 cặp thiếu số đo Worker bị loại khỏi tổng đạt và thử lại bằng kho mới. Mọi UUID hồ sơ/kho mới đều khác nhau và khác tập trước; 63 hồ sơ lịch sử được giữ nguyên. Mã app và engine iOS không đổi trong phép thử này.

## Quét các phiên bản iOS từ 16.1.1

**Chưa có công thức UA → ID riêng cho mọi hồ sơ.** Đợt lặp đúng UA trong hai kho mới cho 60/63 cặp trùng ID, và 126 hồ sơ chỉ có 24 nhóm trong đợt lặp. Các nhóm của lượt quét dưới đây là số đo theo thời điểm, không phải một ID cố định cho mỗi phiên bản iOS.

Đã thử UA đại diện cho **94 phiên bản iOS ổn định từ 16.1.1**, gồm các bản vá có trong danh sách Apple, với Safari, Chrome iOS và Firefox iOS. Trên build 29 có **288 kho mới**: 282 tổ hợp phiên bản/họ trình duyệt, năm mẫu Safari 26 có OS token đóng băng và một đối chứng lặp lại. Cộng 26 cấu hình tham chiếu đã đo trước đó trên build 28, số liệu đạt gồm **314 kho mới**, **680 event không dùng cache**. Bảng 94 phiên bản chỉ dùng số đo build 29 để tránh trộn bản app. Chrome giữ token 119.0.6045.41 và Firefox giữ token 119.0 để tách ảnh hưởng của phiên bản iOS. Đây là UA thử nghiệm trên **engine thật iOS 16.1.1**; không phải cài các hệ điều hành tương ứng. Ngoài số liệu đạt, 3 cặp đo thiếu Worker đã bị loại và đo lại; chúng không được cộng vào các tổng trên.

Riêng các kho mới trên build 29 cho **60 nhóm Visitor ID**: Safari 58, Chrome iOS 1, Firefox iOS 1. Cả tập tham chiếu hai bản app có **63 nhóm**. Bảng dưới là những OS token bạn yêu cầu trước, chỉ dùng số đo build 29. Nhiều phiên bản có thể dùng chung nhóm. Mọi lần tải đầu/tải lại đều khớp ID và event giữa trang/agent/server, UA giữa trang/Worker/server, cùng IP và môi trường máy chủ. Toàn bộ 26 cấu hình của đợt đầu còn được mở lại app và giữ ID; đợt quét bổ sung đo tải đầu/tải lại.

| OS token trong UA · build 29 | Safari | Chrome iOS | Firefox iOS |
| --- | --- | --- | --- |
| 17.2 | G56 | G2 | G3 |
| 18.4 | G57 | G2 | G3 |
| 26.0 | G58 | G2 | G3 |
| 26.1 | G59 | G2 | G3 |
| 26.2 | G60 | G2 | G3 |
| 26.3 | G61 | G2 | G3 |
| 26.4 | G62 | G2 | G3 |

[Bảng đầy đủ 94 phiên bản (CSV)](verification/ios16-ua-version-sweep-build29.csv) · [Số đo và cấu hình (JSON)](verification/ios16-ua-version-sweep-build29.json).

Lặp đúng UA đại diện của 63 nhóm, mỗi UA trong hai kho mới độc lập: thêm 126 hồ sơ và 252 event đạt. Đợt lặp có 21 ID ngoài tập của đợt quét. Bảng JSON ghi rõ trường hợp dùng lại ID cũ; thay UUID và tạo kho mới không tự bảo đảm ID mới.

Đã giữ lại một lịch sử cho mỗi nhóm của đợt quét chính: **63 hồ sơ iPhone/iOS có 63 ID khác nhau**, đánh số từ **10** đến **72** trên máy thử. Danh sách tên nằm trong JSON; số đo kho mới của đợt lặp được báo cáo riêng. Kiểm tra lại bằng 128 event mới xác nhận ID giữ qua tải lại và mở lại app. Không đổi UA/UUID/kho, không chép hoặc xóa dữ liệu website. Đợt kiểm tra lại loại 7 cặp bị ngắt tải và 0 cặp thiếu số đo Worker; mọi ID quan sát được trước khi thử lại đều phải khớp ID cũ. Các lượt bị loại không nằm trong tổng event đạt. Các hồ sơ này là những lịch sử đã đo được, **chưa bảo đảm mỗi hồ sơ tạo thêm có ID riêng**.

Safari 26 thực tế giữ phiên bản iOS trong UA thay vì luôn ghi 26.x; vì vậy đã thử riêng mẫu OS token 18.6/18.6.2 với Safari26 và mẫu OS token26.x. [WebKit công bố thay đổi UA](https://webkit.org/blog/17333/webkit-features-in-safari-26-0/), [điều chỉnh token 18.6.2](https://bugs.webkit.org/show_bug.cgi?id=298473). Danh sách phiên bản lấy từ [Apple security releases](https://support.apple.com/en-us/100100) và [bản lưu 2022–2023](https://support.apple.com/en-us/121012); không gồm beta hoặc hậu tố RSR (a)/(c). Các mẫu sinh cho phép thử không được khẳng định là chuỗi UA nguyên bản của mọi bản trình duyệt đã phát hành.

Quy trình kiểm tra lịch sử: bốn cặp đầu hoàn tất với tab tự khôi phục như thường lệ. Các cặp còn lại tạm đặt URL tab đã lưu thành `about:blank` trước khi mở app, để tránh tải trang khôi phục chồng với lượt nạp của bộ đo, rồi khôi phục toàn bộ danh sách tab sau mỗi phép thử. UUID tab/hồ sơ/kho và UA không đổi; phép đo vẫn nạp trang thật từ đúng kho cũ. Không sửa app đã cài hoặc dữ liệu website để xử lý lỗi tải này.

## UA iPhone/iOS trong build 29

Menu có thêm Safari iOS **17.4, 17.5, 17.6, 17.7**, cùng các tổ hợp **Chrome/Firefox iOS 17.4, 17.5, 17.6**. Đây là chuỗi UA gửi website; máy và engine thật vẫn là iOS/WebKit 16.1.1. Nhóm thử mới chỉ dùng UA iPhone/iOS, không dùng UA Windows hay Android.

Trên iPhone 11 Pro Max, tám kho mới với UA Safari 17.4–17.7 và Chrome/Firefox iOS 17.4–17.6 tạo **ba ID trong nhóm thử**. Đổi riêng phiên bản Safari 17.4 → 17.5 → 17.6 → 17.7 không tách ID; kết hợp họ Safari/Chrome/Firefox iOS đã cho ba ID khác nhau. Cả 32 event đều khớp giao diện/agent/server, không dùng cache; server đọc đúng iPhone, iOS và phiên bản cấu hình. Ba ID giữ qua tải lại và mở lại app. Trong nhóm này có một ID ngoài bảy ID đã lưu trước đó; không suy ra ID mới cho mỗi UUID.

Đã lưu ba hồ sơ **10 - iPhone Safari iOS 17.4**, **11 - iPhone Chrome iOS 17.4**, **12 - iPhone Firefox iOS 17.4**. Sau cập nhật build 29, thêm tám event kiểm tra lại xác nhận đúng ba ID cũ, đúng UA trong trang/Worker/server, đúng iPhone/iOS 17.4. UUID hồ sơ và kho giữ nguyên. [Kết quả iOS-only](verification/ios16-iphone-ua-build29.json). [CI build 29](https://github.com/raycola9969/Lekapro/actions/runs/39067566316): 30 kiểm thử đạt, 1 bài mạng bỏ qua, không có lỗi.

Báo cáo điều tra cập nhật có **2228 event thiết bị độc lập**: [báo cáo build 29](verification/ios16-retention-investigation-build29.json). Các số đo này chưa bảo đảm ID riêng cho mọi hồ sơ mới.

## Các đối chứng đến build 28 trên iOS 16.1.1

**Bảy hồ sơ đã lưu giữ bảy Visitor ID khác nhau tại fingerprint.com/demo, cùng UA Safari 17.2. Chưa bảo đảm một ID mới cho mọi hồ sơ tạo thêm.** Build 28 đã cài trên iPhone 11 Pro Max iOS 16.1.1; engine thật vẫn là WebKit của iOS 16.1.1. UA trong trang, Worker và phản hồi server khớp cấu hình. Không sửa ID trên giao diện, SDK hoặc phản hồi server.

| Hồ sơ trên máy thử | UA khi đo lần đầu | UA hiện tại |
| --- | --- | --- |
| 03 - Safari 17.2 A | iPhone Chrome 119 | Safari 17.2 |
| 04 - Safari 17.2 B | WebKit mặc định | Safari 17.2 |
| 05 - Safari 17.2 C | Windows Firefox 119 | Safari 17.2 |
| 06 - Safari 17.2 Edge | Windows Edge 119 | Safari 17.2 |
| 07 - Safari 17.2 Opera | Windows Opera 105 | Safari 17.2 |
| 08 - Safari 17.2 Samsung Internet | Android Samsung Internet 23 | Safari 17.2 |
| 09 - Safari 17.2 UC Browser | Android UC Browser 13.4 | Safari 17.2 |

Bảy hồ sơ giữ nguyên UUID hồ sơ và UUID kho dữ liệu. Bốn hồ sơ mới được đo qua hai lần mở tiến trình app, tải đầu và tải lại; ba hồ sơ cũ cũng được kiểm tra lại sau cập nhật. Đợt xác nhận gồm 24 event mới; các đợt kiểm tra lại sau đối chứng dùng 16 event mỗi đợt, vẫn giữ đủ bảy ID. Agent không dùng cache, ID/event trên trang khớp agent và server, cùng IP và môi trường server. Các hồ sơ này đã tách khỏi nhóm QA có quyền xóa dữ liệu.

Tạo sáu kho mới với các họ UA Edge/Opera, Samsung/UC, Vivaldi/Yandex đã cho bốn ID mới ngoài ba ID cũ. Tuy nhiên hai kho mới lặp đúng UA Edge/Opera lại nhận hai ID đã có. Trước đó, sáu kho mới cùng họ Firefox, kể cả hậu tố UUID khác nhau, vẫn nhận một ID; thay seed Canvas/Audio cũng chưa tách được. Vì vậy danh sách trên là bảy lịch sử hồ sơ đã kiểm chứng, không phải công thức tạo ID không giới hạn.

Đợt đối chứng tiếp theo tạo tám kho mới: Edge 119/145, Opera 105/128, Chrome iOS 119/145 và lặp lại cặp Edge bằng hai UUID mới. Server đọc đúng số phiên bản khác nhau; cả tám kho vẫn dùng lại ID đã có, không tạo thêm ID ngoài bảy ID trước. Ba cặp đầu tiếp tục giữ ID khi đổi về cùng Safari 17.2 và mở lại app. Có 40 event mới đã đối chiếu, không dùng cache. Sáu ứng viên đầu đều bị bộ đối chiếu loại khỏi danh sách ID mới vì trùng; đây là kiểm tra nghiệm thu số đo, chưa thay hành vi tạo hồ sơ trong app. Xem [đối chứng phiên bản UA](verification/ios16-version-seeds-build28.json).

Không thể suy ra bảo đảm ID tương lai từ một số lượt đo thành công. [Fingerprint mô tả](https://docs.fingerprint.com/docs/identification-accuracy-and-confidence) đối sánh xác suất có thể cấp cùng ID cho hai trình duyệt khác nhau. [API get](https://docs.fingerprint.com/reference/js-agent-get-function) trả ID do dịch vụ nhận diện; linkedId/tags chỉ gắn dữ liệu vào event. Lekapro không có quyền bắt máy chủ demo cấp ID theo UUID hồ sơ. Mục tiêu mỗi hồ sơ mới một Visitor ID vẫn chưa đạt.


Đã xác nhận trạng thái kho có vai trò: giữ nguyên UUID/cấu hình hồ sơ và gắn kho cũ → mới → cũ làm ID đổi rồi trở lại. Xóa riêng cookie/localStorage hoặc một số nhóm dữ liệu vẫn giữ ID; một số tổ hợp xóa toàn bộ và khởi động lại tiến trình mạng làm mất ID cũ. Các phép thử này chưa tách hết mọi đường phục hồi ID.

Đối chứng Edge/Opera khác với một số cặp Chrome/native trước đó: gọi WebKit xóa cả 11 loại dữ liệu công khai hoặc cả 19 loại native, flush trước khi xóa và xác nhận PID mạng thay đổi, vẫn giữ ID của cả hai hồ sơ. Trước lượt nạp, cookie bằng 0, localStorage trống và record dữ liệu công khai trống. Có 24 event mới khớp trang/agent/server; nhóm thuộc tính thô ở lượt tải lại cuối bằng nhau. Vì vậy thao tác xóa/restart chưa phải công thức cấp ID mới, và chưa thể quy phần giữ ID còn lại cho riêng máy chủ hoặc một loại dữ liệu cụ thể. Xem [đối chứng xóa dữ liệu theo họ UA](verification/ios16-state-reset-families-build28.json).


Đối chứng bổ sung dùng seed Edge/Opera để ID nguồn khác ID đích trong lượt không chuyển token. Hai lượt đối chứng không chuyển token, ở trước và sau lượt chuyển, giữ ID đích ban đầu. Chỉ lượt đặt cookie `_vid_t` có sẵn từ nguồn vào đích đã làm đích nhận ID nguồn; hash cookie khớp trước khi nạp trang, đích không có localStorage và được mở trước nguồn. Cả ba cặp đều giữ ID khi tải lại. Đây là bằng chứng cookie này có thể mang ID trong điều kiện đã đo; không chứng minh nó là đường lưu giữ duy nhất.

Kết quả về thứ tự mở cần giới hạn: build 27 có đối chứng mở đích trước giữ ID đích, nhưng build 28 với seed Chrome/native vẫn nhập ID ngay cả khi không chuyển token và mở đích trước. Quy trình build 28 đo thêm trạng thái ngay trước mỗi lượt mở. Liệt kê DiskCache có thể bao gồm nhiều network session trong [mã nguồn WebKit nhánh 614.2.9](https://github.com/WebKit/WebKit/blob/WebKit-7614.2.9.0.10/Source/WebKit/NetworkProcess/NetworkProcess.cpp#L1343); danh sách record không đủ để quy cache cho một hồ sơ. Ở phép thử tương ứng, tệp cache thực của đích không tăng trước khi mở. Chưa xác định đầy đủ cơ chế giữ ID hoặc cơ chế nội bộ ExitAnty 2.2.2.

Báo cáo điều tra hiện có **744 event thiết bị độc lập** đã kiểm tra từ build 21 trở đi, tách khỏi các đợt cũ và số đo simulator. Xem [báo cáo đã loại dữ liệu định danh](verification/ios16-retention-investigation-build28.json) và [ma trận đối chứng](verification/ios16-retention-matrix-build28.md). [CI build 28](https://github.com/raycola9969/Lekapro/actions/runs/39062532151) đạt 30 kiểm thử, một live network test bỏ qua, không có lỗi. Checksum IPA và commit nguồn nằm trong báo cáo.

## Đã triển khai

- Tạo, sửa, sao chép cấu hình, tìm kiếm và xóa hồ sơ.
- iOS 17+: kho dữ liệu công khai theo UUID. iOS 16.x: cấu hình WebKit SPI với thư mục riêng trong sandbox của Lekapro. Các tab cùng hồ sơ chia sẻ một đối tượng kho dữ liệu.
- Khôi phục tối đa 30 tab/hồ sơ; dấu trang, lịch sử, nhãn và ghi chú.
- Kho proxy SOCKS5 và HTTP CONNECT; HTTPS CONNECT tới proxy được hỗ trợ từ iOS 17. Mật khẩu lưu trong Keychain.
- iOS 17+: `allowFailover = false`. iOS 16 dùng cấu hình proxy riêng của WebKit; phép thử với SOCKS5 tại cổng không có máy chủ đã trả lỗi kết nối, không tải trang trực tiếp. Chưa đo DNS/UDP hoặc mọi tình huống thay đổi mạng.
- Bộ chặn tracker cơ bản; tùy chọn chặn đọc Canvas/Audio và chặn WebRTC.
- Tùy chọn chặn tạo ngữ cảnh WebGL và giảm thông tin phần cứng: tối đa 2 luồng được báo cho trang, kích thước màn hình làm tròn xuống theo bậc 200 px. Mặc định tắt; áp dụng trong trang/frame, chưa bao phủ Worker. Có thể ảnh hưởng đồ họa 3D, bố cục và xử lý song song; không bảo đảm tách Visitor ID.
- Thử nghiệm áp dụng các thiết lập trên cho classic Blob Worker được tạo trong trang qua `URL.createObjectURL`. Mặc định tắt; giữ MIME và kiểm tra CSP, không sửa thông điệp của Worker. Chưa bao phủ module, URL ngoài, Shared/Service Worker hoặc mọi Worker lồng nhau. Địa chỉ Blob Worker thay đổi; CSP có thể chặn việc nạp script bổ sung, khi đó cần tắt tùy chọn này để giữ tương thích.
- User-Agent theo hồ sơ: mặc định WebKit, preset iPhone Safari 17.2/17.4/17.5/17.6/17.7/18.7.9, iPad Safari 16.1, iPhone Chrome/Firefox 119 với iOS 16.1.1 hoặc 17.4–17.6 và chuỗi tùy chỉnh. Đổi UA giữ UUID kho dữ liệu; không đổi iOS/WebKit thật.
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

## Các mốc kiểm thử trước build 20

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
