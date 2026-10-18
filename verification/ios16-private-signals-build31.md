# Kho riêng tư và tín hiệu phần cứng trên iOS 16.1.1 — build 31

**Đo được 20 hồ sơ mới / 20 ID riêng, giữ đủ 20 ID khi mở lại trên iOS 16.1.1.** Kịch bản QA dùng CPU báo cáo 4, Safari iOS 17.2, yêu cầu xóa 19 loại dữ liệu native và flush/restart mạng trước lần truy cập đầu; không gắn proxy trong app. Nhưng đối chứng cùng thời điểm cũng nhận ID mới khi không reset, nên chưa chứng minh reset là nguyên nhân hay điều kiện cần. Kết quả hữu hạn này chưa tự động áp dụng cho hồ sơ thông thường và không bảo đảm mọi hồ sơ tương lai hay vô hạn.

Đo thật tại `fingerprint.com/demo` trên iPhone iOS **16.1.1**, build **31**: 16 kho mới, 32 event không dùng cache, 1 IP trực tiếp và 4 ID quan sát được trong nhóm này. Tất cả dùng cùng UA iPhone Safari iOS 17.2 và cùng thiết bị. Có 3 ID chưa xuất hiện trong tập báo cáo `native-engine` lưu trước build 31; đây không phải toàn bộ lịch sử phía máy chủ.

| Phép thử | ID khác nhau ở lần mở đầu | Hồ sơ giữ ID khi tải lại |
|---|---:|---:|
| Kho lưu bền / kho riêng tư | 1 / 2 | 2 / 2 |
| Hai kho riêng tư mới | 1 / 2 | 2 / 2 |
| CPU 1 / 4, kho lưu bền | 2 / 2 | 2 / 2 |
| Độ sâu màu 8 / 16, kho lưu bền | 2 / 2 | 2 / 2 |
| CPU + màu, kho lưu bền | 2 / 2 | 2 / 2 |
| CPU + màu, kho riêng tư | 2 / 2 | 2 / 2 |
| CPU 1 / 4, kho riêng tư | 2 / 2 | 2 / 2 |
| Độ sâu màu 8 / 16, kho riêng tư | 2 / 2 | 2 / 2 |

Mỗi cặp có kho/UUID mới. ID và event trên trang, agent và phản hồi máy chủ đều khớp; mỗi event khác nhau và `cache_hit` tắt. CPU được kiểm tra ở trang chính, Blob Worker và máy chủ. Color Depth/Pixel Depth được kiểm tra ở trang; máy chủ được đối chiếu Color Depth. Kiểm thử simulator xác nhận iframe và giá trị mặc định của hồ sơ thường. Các getter giảm CPU/màu là JavaScript có thể quan sát được, chỉ bật cho hồ sơ QA DEBUG; không giả dạng hàm native và không sửa kết quả Fingerprint.

Canvas geometry native cũng biến động giữa một số lần đo dù không bật nhiễu của app; không coi một cặp khác ID là bằng chứng CPU hoặc màu là nguyên nhân duy nhất. Lượt tạo lại và phép đổi CPU trên cùng kho được ghi riêng dưới đây.

“Trực tiếp/không proxy” trong các nhóm build 31 nghĩa là không gắn proxy cho hồ sơ trong Lekapro; không đồng nghĩa dịch vụ đánh giá IP đó là không có proxy/VPN. Không suy ra mức tin cậy hay việc được một dịch vụ khác chấp nhận chỉ từ ID khác nhau.

Kho riêng tư dùng `WKWebsiteDataStore.nonPersistent()`; báo cáo kiểm tra trực tiếp `isPersistent`. Kho này không lưu trạng thái qua lần khởi động app, nên riêng kết quả của nó chưa phải giải pháp hồ sơ lưu bền. Hồ sơ QA chỉ nhận các tùy chọn trong yêu cầu đo một lần, chưa phải tính năng mặc định trong giao diện. 1002 cấu hình hồ sơ có trước được kiểm tra giữ nguyên sau đợt đo.

## Đối chứng tiến trình mạng và proxy, build 29

Hai lượt, mỗi lượt hai kho mới dùng hai IP proxy khác nhau. Tiến trình mạng đổi PID cho từng hồ sơ, flush trạng thái mạng hoàn tất, cookie và localStorage đều trống trước lần truy cập mạng đầu. Lượt gốc cho **1 ID / 2 hồ sơ**. Lượt thêm nhiễu Canvas/Audio, giảm CPU qua cả Worker và chặn WebGL cho **1 ID / 2 hồ sơ**; máy chủ thấy Canvas/Audio khác nhau. Cả bốn hồ sơ giữ ID khi tải lại và đều nhận ID đã thấy trong đợt nhiều proxy trước. Hai lượt có tám event không dùng cache. Tổ hợp này không bảo đảm ID mới. Phép thử không chứng minh đã loại bỏ mọi cơ chế liên kết phía máy chủ.

## Build và giới hạn

Source được build: `8165b6bfd4f99b1d2e57d6d449a8eb8c9077e3a5`. Artifact SHA-256: `f936616d3b9f3e93b589a7a39ce7021be9c5b42787232c12a155f1b433e45b59`. IPA SHA-256: `182612787df66542438cdc75919a5fd05fc4e59c7d4716189b8ad6811707d64c`. [CI đầy đủ](https://github.com/raycola9969/Lekapro/actions/runs/39165536023) đạt trên simulator iOS 18.5; các event ID nêu trên đo trên máy thật iOS 16.1.1. Bài kiểm thử cold reset cũ từng timeout; fixture được sửa để giải phóng WebView trước restart và mở lại nguồn cho các assertion tiếp theo, giữ nguyên kiểm tra cookie, storage, PID và native records. Thao tác sao chép cookie native không còn tạo WebView dư; hai bài restart chạy trong các test host riêng.

Không thay ID trên DOM, agent hay phản hồi máy chủ. Tách được một nhóm ID trong một lần đo không chứng minh mọi hồ sơ tạo thêm đều có ID riêng. Thuật toán đối sánh phía máy chủ vẫn nằm ngoài quyền điều khiển của Lekapro.

CI có **32 bài đạt, 1 bài live-network bỏ qua có chủ đích, 0 bài thất bại**. Các phép đo máy thật nêu trong báo cáo được kiểm chứng riêng; không lấy bài simulator thay cho kết quả Visitor ID trên iOS 16.1.1.

[JSON đã loại định danh](ios16-private-signals-build31.json) · [Đợt proxy trước](ios16-proxy-investigation-build29.md)

## Tạo lại kho mới với cấu hình từng tách ID

Đã tạo lại 12 cấu hình, 24 hồ sơ mới và 48 event không dùng cache. Có 4 ID trong lượt này, 0 ID chưa thấy trong vòng đầu. Đây là phép tạo kho mới; không dùng lại cookie hoặc kho của vòng đầu. Bảng chi tiết nằm trong JSON.

| Cấu hình | ID trong hai kho mới | Nhận ID từng thấy ở vòng đầu |
|---|---:|---:|
| `{"hardwareThreadLimit":1}` | 1 / 2 | 2 / 2 |
| `{"hardwareThreadLimit":4}` | 1 / 2 | 2 / 2 |
| `{"colorDepthLimit":8}` | 1 / 2 | 2 / 2 |
| `{"colorDepthLimit":16}` | 1 / 2 | 2 / 2 |
| `{"colorDepthLimit":8,"hardwareThreadLimit":1}` | 1 / 2 | 2 / 2 |
| `{"colorDepthLimit":16,"hardwareThreadLimit":4}` | 1 / 2 | 2 / 2 |
| `{"colorDepthLimit":8,"ephemeralStore":true,"hardwareThreadLimit":1}` | 1 / 2 | 2 / 2 |
| `{"colorDepthLimit":16,"ephemeralStore":true,"hardwareThreadLimit":4}` | 1 / 2 | 2 / 2 |
| `{"ephemeralStore":true,"hardwareThreadLimit":1}` | 1 / 2 | 2 / 2 |
| `{"ephemeralStore":true,"hardwareThreadLimit":4}` | 1 / 2 | 2 / 2 |
| `{"colorDepthLimit":8,"ephemeralStore":true}` | 1 / 2 | 2 / 2 |
| `{"colorDepthLimit":16,"ephemeralStore":true}` | 1 / 2 | 2 / 2 |

## Đổi CPU trên chính kho đã có ID

Hai kho lưu bền từng nhận hai ID khác nhau được giữ nguyên UUID. Đổi CPU báo cáo, sau đó giữ cùng CPU nhưng xóa cookie/localStorage của riêng hai hồ sơ QA, rồi đổi CPU về ban đầu. Mọi lượt đối chiếu CPU trang–Worker–server; không sao chép token hoặc sửa ID.

| Giai đoạn | Giữ ID ban đầu của kho | ID khớp cấu hình CPU ban đầu |
|---|---|---|
| swap-preserving-state | 2 / 2 | 0 / 2 |
| same-swapped-cpu-clear-cookies-and-localStorage | 2 / 2 | 0 / 2 |
| restore-original-cpu-preserving-current-state | 2 / 2 | 2 / 2 |

Phép thử này phân biệt liên hệ với thuộc tính và trạng thái trong điều kiện đã đo; chưa xác định đầy đủ hay duy nhất thuật toán lưu giữ ID phía máy chủ.

Một lượt sơ bộ bị ngắt khi tab cũ tự khôi phục URL, không tính vào các event đối chứng. Lượt kiểm soát tạm đặt tab khôi phục thành `about:blank` để có một điều hướng được đo, rồi trả lại metadata tab; kho dữ liệu giữ nguyên qua các lần đổi CPU, ngoại trừ bước xóa cookie/localStorage được ghi rõ.

## Xóa dữ liệu native và khởi động lại mạng

Giữ hai UUID kho, đảo CPU về 4/1 và yêu cầu xóa các loại dữ liệu native của WebKit (số loại theo từng kho: [19, 19]), flush trạng thái mạng rồi khởi động lại tiến trình mạng. PID đổi ở cả hai; cookie/localStorage được kiểm tra trống trước truy cập. Kết quả liệt kê native records trống theo từng kho: [True, True]; `false` không được coi là bằng chứng xóa sạch toàn bộ. Có 0 / 2 hồ sơ giữ ID baseline; 1 / 2 ID khớp nhóm CPU hiện tại. Bốn event không dùng cache được đối chiếu riêng. Đây vẫn chưa phải bằng chứng đã loại bỏ mọi nguồn trạng thái hệ điều hành hay biết toàn bộ thuật toán máy chủ.

Cả hai ID đổi so với baseline trong khi `raw_device_attributes` không đổi so với lần đo cùng CPU sau bước xóa cookie/localStorage. Một ID khớp nhóm đã thấy, một ID chưa thấy trong vòng đầu. Can thiệp này gộp nhiều loại dữ liệu native và restart mạng; chưa tách được loại dữ liệu nào hay thành phần mạng nào gây thay đổi, cũng chưa loại trừ ảnh hưởng thời gian/phía máy chủ. Không kết luận riêng CPU là nguyên nhân giữ hoặc đổi ID.

## Xóa native trước lần truy cập đầu tiên của kho mới

Giữ nguyên Safari iOS 17.2, cùng máy và IP trực tiếp. Với từng kho mới, xóa đủ 19 loại dữ liệu native, kiểm tra liệt kê record hoàn tất và trống, cookie/localStorage trống, flush và đổi PID mạng trước lần truy cập Fingerprint đầu tiên.

| CPU báo cáo | Hồ sơ mới | ID khác nhau | Giữ ID khi tải lại |
|---|---:|---:|---:|
| 4 | 2 | 2 | 2 / 2 |
| 1 | 2 | 1 | 2 / 2 |

Bốn hồ sơ chỉ có **3 ID**. CPU 4 cho hai ID khác nhau ở lượt này, nhưng CPU 1 cho hai kho nhận cùng một ID đã thấy. Không thể dùng tổ hợp xóa native + restart mạng làm bảo đảm mỗi kho mới nhận ID riêng.

### Tạo lại riêng cấu hình CPU 4

Tiếp tục dùng các kho mới, cùng UA/CPU/IP và cùng thao tác xóa native trước lần truy cập đầu. So sánh với tất cả ID của các phép thử build 31 trước đó, dừng sớm nếu quan sát thấy ID tái sử dụng.

| Lượt | Hồ sơ mới | ID khác nhau trong cặp | Hồ sơ nhận ID từng thấy trước | Giữ ID khi tải lại |
|---|---:|---:|---:|---:|
| 1 | 2 | 2 | 0 / 2 | 2 / 2 |
| 2 | 2 | 2 | 0 / 2 | 2 / 2 |
| 3 | 2 | 2 | 0 / 2 | 2 / 2 |
| 4 | 2 | 2 | 0 / 2 | 2 / 2 |
| 5 | 2 | 2 | 0 / 2 | 2 / 2 |
| 6 | 2 | 2 | 0 / 2 | 2 / 2 |
| 7 | 2 | 2 | 0 / 2 | 2 / 2 |
| 8 | 2 | 2 | 0 / 2 | 2 / 2 |
| 9 | 2 | 2 | 0 / 2 | 2 / 2 |
| 10 | 2 | 2 | 0 / 2 | 2 / 2 |

Lượt bổ sung có 40 event, 20 ID; 20 ID chưa thấy trong tập build 31 trước lượt này. Lý do dừng: `bounded_replication_complete`. Một ID mới trong tập hữu hạn không có nghĩa là mới trên toàn bộ lịch sử dịch vụ.

Sau khi các kho mới đã được đo và tiến trình mạng đã nhiều lần khởi động lại, mở lại đủ **20 hồ sơ** mà không xóa dữ liệu trang: **20 hồ sơ giữ đúng ID ban đầu** qua mở lại và tải lại, 20 ID trong lượt mở lại; có thêm 40 event không dùng cache. UUID/kho được giữ nguyên. Đây là kiểm chứng hữu hạn của công thức QA, chưa phải cam kết cho mọi hồ sơ mới hay tính năng mặc định khi bấm tạo hồ sơ.

20 hồ sơ của lượt CPU 4 có 2 bộ `raw_device_attributes`. Nhóm thuộc tính biến động: `{"canvas": 2}`. Có cùng bộ thuộc tính hiển thị nhưng ID khác nhau: `True`. Không thể giải thích toàn bộ việc cấp ID chỉ từ danh sách thuộc tính hiển thị này.

## Tách xóa native khỏi restart mạng

Cùng CPU 4, Safari iOS 17.2, cùng máy/IP; mỗi điều kiện hai kho mới.

| Thao tác trước lần truy cập đầu | ID trong cặp | Hồ sơ nhận ID từng thấy | Giữ ID khi tải lại |
|---|---:|---:|---:|
| `networkOnly` | 2 / 2 | 0 / 2 | 2 / 2 |
| `allNativeData` | 2 / 2 | 0 / 2 | 2 / 2 |

`networkOnly`: không yêu cầu xóa loại dữ liệu native nào, flush và PID mạng đổi được kiểm tra. `allNativeData`: xóa 19 loại dữ liệu, liệt kê record hoàn tất và trống, không yêu cầu restart mạng. Cookie/localStorage trống và CPU trang–Worker–server được đối chiếu ở cả hai điều kiện. Mỗi điều kiện mới có hai hồ sơ, chưa xác lập đầy đủ nhân quả hay thành phần duy nhất.

Cả hai thao tác tách riêng đều cho hai ID chưa thấy trong tập trước. Vì vậy không coi việc dùng đồng thời cả hai là điều kiện cần; tiếp tục đặt đối chứng cùng thời điểm, không reset dưới đây để tránh gán hiệu ứng theo thời gian hoặc trạng thái chung cho công thức.

Phạm vi kiểm tra dữ liệu: thao tác xóa yêu cầu 19 loại native được API runtime liệt kê và callback hoàn tất; phép liệt kê record sau đó dùng `WKWebsiteDataStore.allWebsiteDataTypes()` công khai. Record trống không chứng minh mọi loại dữ liệu private hoặc mọi trạng thái WebKit/hệ điều hành đều đã trống. Các cột xác nhận reset cần được hiểu trong phạm vi này.

## Đối chứng cùng thời điểm, không reset

Cùng UA/IP/máy, kho mới, không yêu cầu xóa dữ liệu hay restart mạng. `native` là CPU WebKit mặc định, `CPU 4` dùng getter QA dù giá trị vẫn là 4.

| Cặp cấu hình | ID trong cặp | Nhận ID đã quan sát, theo thứ tự hồ sơ | Giữ ID khi tải lại |
|---|---:|---|---:|
| `cpu4-and-native` | 2 / 2 | [False, False] | 2 / 2 |
| `cpu1-and-cpu4` | 2 / 2 | [True, False] | 2 / 2 |

Các đối chứng giới hạn diễn giải nhân quả của kết quả dương tính: không suy ra chỉ một thao tác đã tạo ID riêng hoặc biết toàn bộ lý do dịch vụ lưu giữ ID.

Kết quả cụ thể: cả CPU 4 qua getter QA và CPU 4 native không reset đều nhận ID chưa thấy; cặp không reset tiếp theo có CPU 1 nhận ID cũ và CPU 4 nhận ID mới. CPU 4 trước đó từng lặp về cùng ID qua nhiều kho. Vì vậy tính mới của ID không chỉ phụ thuộc vào chuỗi UA hay giá trị CPU hiển thị; nguyên nhân thay đổi theo đợt chưa được cô lập. Không kết luận đã sửa xong cơ chế bảo đảm ID riêng trong app từ phép đo 20/20.

## Kết luận về nguyên nhân và phần chưa biết

Đã bác bỏ trong điều kiện đo: UA/phần cứng báo cáo khác nhau tự bảo đảm ID riêng; kho riêng tư tự bảo đảm ID riêng; proxy riêng hoặc restart mạng tự bảo đảm ID riêng; và xóa cookie/localStorage đủ làm mất ID cũ. CPU/màu có liên hệ với các nhóm ID ban đầu, nhưng 24 kho tạo lại chỉ trở về bốn nhóm đã quan sát. Full native reset kèm restart mạng có thể đổi ID ở cùng kho, song chưa xác định riêng thành phần gây đổi và vẫn có kho mới trùng ID. Do đó chưa tìm ra công thức bảo đảm một hồ sơ = một ID, chưa biết đầy đủ thuật toán lưu giữ/đối sánh máy chủ, và không cam kết vô hạn. Các kết quả trên là Visitor ID thực trả về từ dịch vụ, không phải UUID nội bộ của hồ sơ.

Toàn bộ các nhóm mới trong báo cáo: **212 event đã đối chiếu**, **78 hồ sơ/kho mới**, **3 IP thực tế**. Số này giữ riêng với báo cáo lịch sử 2228 event và đợt proxy 152 event trước đó. Nhãn nhóm ID chỉ có ý nghĩa trong từng phần; không suy ra hai nhãn khác chữ ở hai bảng là hai ID khác nhau.
