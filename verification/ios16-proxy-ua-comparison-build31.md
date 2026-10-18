# Proxy và UA Safari iOS khác 16.1.1 — build 31

**Có trùng ID với đối chứng UA iOS 16.1.1: 8/8 hồ sơ proxy dùng UA khác.** Các hồ sơ proxy dùng UA 17.2/18.4 có tổng cộng **1 ID ban đầu / 8 kho mới** qua hai lượt tạo kho. Đây là kết quả hữu hạn; không phải bảo đảm mỗi hồ sơ tương lai có ID riêng.

Thiết bị thật vẫn là iPhone iOS **16.1.1**, Lekapro **build 31** đã cài từ CI được kiểm chứng trong [báo cáo trước](ios16-private-signals-build31.md). 17.2/18.4 chỉ là chuỗi User-Agent Safari. Không thay engine/CPU/màu, không bật nhiễu Canvas/Audio, không reset hay sao chép dữ liệu và không sửa kết quả Fingerprint. Không cần build/cài lại app cho phép thử này.

## Thiết kế và kiểm chứng

Bốn proxy SOCKS5 có IP thoát khác nhau được kiểm tra lại trước khi chạy. Mỗi proxy có hai kho mới: UA 16.1.1 làm đối chứng và UA 17.2 hoặc 18.4. Thêm một cặp trực tiếp 16.1.1/17.2. Sau đó mở lại cả mười kho; cuối cùng tạo lại bốn kho UA khác trên đúng proxy/UA trước đó, giữ nguyên các kho cũ. Bốn kho tạo lại được kiểm tra lần mở đầu và tải lại, chưa có lượt mở lại app riêng.

Đã đối chiếu **48 event không cache, 14 kho mới, 5 IP thực tế**. Trang/agent/server khớp Visitor ID và event; UA trang/Worker/server khớp chuỗi cấu hình. Máy chủ cũng phân tích đúng iOS 16.1.1/17.2/18.4 theo UA; không phải thay UA bị bỏ qua. IP server ở mọi lượt dùng proxy khớp IP kiểm tra trước đó. CPU native trang/Worker/server đều là 4; không có engine override. Chỉ các cặp đủ bốn event hợp lệ mới được tính. Có 0 lượt thử không tính vào bằng chứng.

## Cùng proxy, UA 16.1.1 so với UA khác

| Tuyến | UA đối chiếu | ID UA 16.1.1 | ID UA khác | Hai ID trùng nhau |
|---|---|---|---|---|
| direct-17.2 | 17.2 | V1 | V2 | Không |
| P01 | 17.2 | V3 | V3 | Có |
| P02 | 17.2 | V3 | V3 | Có |
| P05 | 18.4 | V3 | V3 | Có |
| P06 | 18.4 | V3 | V3 | Có |

Các nhãn `V1`, `V2`… thay cho ID thật, chỉ có ý nghĩa trong báo cáo này. Cùng nhãn là cùng Visitor ID thật, khác nhãn là khác ID trong tập đo này. Không so nhãn với báo cáo trước.

## Tạo lại kho mới trên cùng proxy/UA

| Proxy | UA | ID lượt đầu | ID kho tạo lại | Kho mới giữ ID lượt đầu | Trùng bất kỳ đối chứng UA 16.1.1 nào |
|---|---|---|---|---|---|
| P01 | 17.2 | V3 | V3 | Có | Có |
| P02 | 17.2 | V3 | V3 | Có | Có |
| P05 | 18.4 | V3 | V3 | Có | Có |
| P06 | 18.4 | V3 | V3 | Có | Có |

## Tổng theo UA khác, chỉ các hồ sơ gắn proxy

| UA iOS | Kho mới qua hai lượt | ID ban đầu khác nhau | Hồ sơ trùng ID đối chứng 16.1.1 | Giữ ID khi tải lại |
|---|---:|---:|---:|---:|
| 17.2 | 4 | 1 | 4 | 4 |
| 18.4 | 4 | 1 | 4 | 4 |

Đối chứng UA 16.1.1 hiện tại có 2 ID ở lần mở đầu của năm kho, 2 ID nếu tính mọi lượt mở/tải lại. Tất cả lần thăm của các UA khác có 1 ID trùng tập đối chứng 16.1.1 hiện tại. Việc đối chiếu này xét cả proxy lẫn trực tiếp, không chỉ đúng proxy trong một cặp.

Ngoài ra, tập báo cáo cũ đủ điều kiện có 5 ID dùng chính xác UA Safari 16.1.1. Các UA khác ở lượt đầu trùng 0 ID trong tập cũ; lượt tạo lại trùng 0. Tập lưu trữ này không phải toàn bộ lịch sử dịch vụ.

## Tính ổn định và giới hạn kết luận

Mở lại 10 kho đầu: **10/10 kho giữ đúng ID đầu tiên qua cả mở lại và tải lại**. Cả kho lưu bền và UUID được đối chiếu. Toàn bộ 1076 cấu hình hồ sơ có trước và bản ghi proxy giữ nguyên sau kiểm tra cuối.

Hai kho mới khác UA còn khác UUID/kho lưu trữ. Vì vậy một cặp khác ID chưa chứng minh UA là nguyên nhân duy nhất, cũng không chứng minh đổi proxy luôn tạo ID mới. Ngược lại, cặp UA khác mà cùng ID là phản ví dụ trực tiếp cho bảo đảm “UA khác + proxy = ID luôn khác 16.1.1”. Đây là các ID thực dịch vụ trả về, không phải ID tự tạo trong app.

[JSON đã loại định danh](ios16-proxy-ua-comparison-build31.json) · [Kịch bản 20 hồ sơ trước đó](ios16-private-signals-build31.md)
