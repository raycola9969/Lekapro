# Kiểm chứng proxy trên iOS 16.1.1 — build 29

**Chưa tìm được cách bảo đảm mỗi hồ sơ mới có một Visitor ID riêng.** Đây là kết quả thật tại fingerprint.com/demo; không sửa ID, agent hay phản hồi máy chủ.

Nhãn P01–P20 theo đúng thứ tự 20 dòng proxy được cung cấp; không chứa tài khoản hoặc mật khẩu.

Trong 20 proxy SOCKS5 được cung cấp, 17 hoàn tất kiểm tra IP qua HTTPS trên Windows với 17 IP thoát khác nhau. P04/P19/P20 bị ngắt TLS qua hai địa chỉ kiểm tra IP, kể cả lượt TLS 1.2. Khi đo bằng WebKit trên iPhone, các tuyến P14, P16 không trả được ID quan sát được trong thời gian chờ sau nhiều lượt thử và đối chứng; không tính các lượt đó là kết quả ID, cũng không kết luận proxy ngừng hoạt động toàn bộ.

Lượt tạo mới đầu phủ **15 IP thoát thực tế**; lượt tạo kho mới lần nữa phủ **14 IP**. Mỗi lượt có 16 hồ sơ, gồm hồ sơ đối chứng dùng lại proxy được ghi tên rõ trong CSV. P03 đạt ở lượt đầu nhưng lỗi TLS ba lần ở lượt tạo lại; vị trí đó dùng đối chứng P01 và không tính là đã đo lại P03. Tất cả giữ đúng cùng UA iPhone Safari iOS 17.2; kho và UUID mới ở mỗi lượt. Máy chủ nhận đúng IP đã kiểm tra của từng proxy. Các IP thuộc 11 mạng tự trị (ASN) và 5 múi giờ trong 1 quốc gia.

| Phép thử | Hồ sơ đo được | IP thoát thực tế | ID khác nhau | Giữ ID khi tải lại |
| --- | ---: | ---: | ---: | ---: |
| Tạo mới lượt 1 | 16 | 15 | 1 | 16 |
| Mở lại mẫu hồ sơ lượt 1 | 4 | 4 | 1 | 4 |
| Tạo kho mới lần nữa | 16 | 14 | 1 | 16 |

Lượt tạo lại có **16/16** hồ sơ nhận lại ID của lượt đầu tương ứng. Có 1 ID của đợt này đã xuất hiện trong phép thử proxy trước đó. Số liệu gồm **72 event không dùng cache**, đủ đối chiếu trang–agent–server và UA trang–Worker–server. Có 11 lượt cặp lỗi/thiếu dữ liệu bị loại; hồ sơ phát sinh từ các lượt lỗi không tính trong số hồ sơ đạt. Ở thời điểm kết thúc riêng đợt proxy này, cấu hình mọi hồ sơ và proxy có trước giữ nguyên; phép mở lại cặp QA cũ ở nhóm kế tiếp được ghi riêng.

Máy chủ trả `visitor_found: true` trong **32/32** lần đo đầu của các hồ sơ mới ở hai lượt. Đây là nhận dạng khách từng thấy, không phải bằng chứng phát sinh một ID mới cho từng UUID kho.

## Các tổ hợp kiểm tra thêm

Các tổ hợp dùng proxy riêng và múi giờ theo IP; một số cặp kết hợp nhiễu Canvas/Audio, giảm thông tin phần cứng và chặn WebGL. Một cặp thử thêm cấu hình WebKit native có sẵn. Các cặp khác đổi UA Safari 17.2/18.4, Chrome/Firefox iOS, Chrome 119/120 hoặc hậu tố UA riêng theo mẫu GPM đã thảo luận. Cặp phiên bản/hậu tố không bật nhiễu. Nhóm này kiểm tra tổ hợp; không tách được tác động riêng của mọi tín hiệu.

| Tổ hợp | Đã áp dụng và đo được | ID của hai hồ sơ |
| --- | --- | --- |
| Nhiễu/giảm phần cứng + proxy + múi giờ | Có | Trùng |
| Thêm cấu hình WebKit native | Có | Trùng |
| Safari 17.2 / 18.4 + proxy | Có | Trùng |
| Chrome / Firefox iOS + proxy | Có | Khác |
| Mở lại cặp kho cũ | Có | Khác |
| Hậu tố UA riêng + proxy | Có | Trùng |
| Chrome 119 / 120 iOS + proxy | Có | Trùng |

Hai ID của cặp Chrome/Firefox đều đã xuất hiện trong phép thử proxy trước đó; khác nhau giữa hai họ trình duyệt không đồng nghĩa mỗi hồ sơ mới có ID mới.

Mục `original-native-stores-revisited` mở lại cặp kho cũ từng có hai ID; đây là kiểm tra giữ ID của kho cũ, không phải hai hồ sơ mới. Cả hai kho cũ giữ đúng ID đã thấy trước đó. Kết quả và các nhóm thuộc tính máy chủ khác nhau nằm trong JSON.

## Quota và giới hạn kết luận

Trên chính iOS 16.1.1, bật/tắt cờ native Storage API đều không mở được `navigator.storage.estimate`, dù trang HTTPS là secure context. Bốn event được đối chiếu nhưng **chưa đo được quota và chưa kiểm chứng tác động quota lên ID**. Build 30 thêm điều khiển quota đã qua CI ở commit `3c77579ef39563eac05f4cb59836405f2171aa21`; các phép đo thiết bị trong báo cáo này vẫn dùng build 29.

Báo cáo gộp ở đây có **152 event mới đã đối chiếu** gồm nhóm proxy hiện có, nhóm proxy được cung cấp, các tổ hợp và phép kiểm tra Storage API. Báo cáo 2228 event một IP trước đó giữ nguyên phạm vi; không đổi số liệu cũ thành báo cáo nhiều IP.

UA/IP khác nhau và kho riêng không đủ bảo đảm ID mới trong những phép đo này. Một nhóm hồ sơ có ID riêng trong một lần thử cũng không chứng minh mọi hồ sơ tạo thêm đều có ID riêng. Cơ chế giữ ID đã có một số đối chứng trạng thái/cookie trước đây, nhưng chưa xác định đầy đủ thuật toán tương quan phía máy chủ.

[JSON đã loại dữ liệu định danh](ios16-proxy-investigation-build29.json) · [CSV các lượt proxy](ios16-proxy-profiles-build29.csv) · [CI build 30](https://github.com/raycola9969/Lekapro/actions/runs/39133628001)
