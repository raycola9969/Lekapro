# Điều tra ID trên iOS 16.1.1

Thiết bị thật: iPhone 11 Pro Max. Kết quả chỉ được ghi khi ID/event của trang, agent và server khớp; agent báo không dùng cache. Không sửa kết quả nhận diện.

| Bản | Thao tác lên A trong cặp dùng một lần | ID A giữ nguyên | ID B giữ nguyên | Hai ID nhập lại | Event |
| --- | --- | --- | --- | --- | --- |
| 22 | reset: cookiesAndLocalStorage | Có | Có | Không | 12 |
| 22 | copy: localStorage:_vid_t | Có | Có | Không | 12 |
| 22 | reset: allSiteData | Có | Có | Không | 12 |
| 22 | copy: cookies:_vid_t | Có | Có | Không | 12 |
| 22 | copy: cookies:_iidt | Có | Có | Không | 12 |
| 23 | reset: allNativeData | Có | Có | Không | 12 |
| 23 | reset: allNativeDataAndNetwork | Không | Có | Có | 12 |
| 23 | reset: allNativeDataAndNetwork | Không | Có | Có | 12 |
| 24 | reset: networkOnly | Có | Có | Không | 12 |
| 24 | reset: allSiteDataAndNetwork | Không | Có | Có | 12 |
| 24 | reset: cookies + flushed network restart | Có | Có | Không | 12 |
| 24 | reset: localStorage + flushed network restart | Có | Có | Không | 12 |
| 24 | reset: cookiesAndLocalStorage + flushed network restart | Có | Có | Không | 12 |
| 24 | reset: caches + flushed network restart | Có | Có | Không | 12 |
| 24 | reset: allSiteDataAndNetwork | Không | Có | Có | 12 |
| 26 | reset: customTypes + flushed network restart [Cookies, DiskCache, LocalStorage, MemoryCache] | Có | Có | Không | 12 |
| 26 | reset: customTypes + flushed network restart [DiskCache, FetchCache, FileSystem, IndexedDBDatabases, LocalStorage, MemoryCache, OfflineWebApplicationCache, ServiceWorkerRegistrations, SessionStorage, WebSQLDatabases] | Có | Có | Không | 12 |
| 26 | reset: customTypes + flushed network restart [Cookies, DiskCache, FetchCache, FileSystem, IndexedDBDatabases, MemoryCache, OfflineWebApplicationCache, ServiceWorkerRegistrations, SessionStorage, WebSQLDatabases] | Có | Có | Không | 12 |
| 26 | reset: customTypes + flushed network restart [Cookies, FetchCache, FileSystem, IndexedDBDatabases, LocalStorage, OfflineWebApplicationCache, ServiceWorkerRegistrations, SessionStorage, WebSQLDatabases] | Có | Có | Không | 12 |
| 26 | reset: customTypes + flushed network restart [Cookies, DiskCache, IndexedDBDatabases, LocalStorage, MemoryCache] | Không | Có | Có | 12 |
| 26 | reset: customTypes + flushed network restart [Cookies, DiskCache, FetchCache, FileSystem, LocalStorage, MemoryCache, OfflineWebApplicationCache, ServiceWorkerRegistrations, SessionStorage, WebSQLDatabases] | Không | Có | Có | 12 |
| 26 | copy: cookies:_vid_t (cold target) | Có | Không | Có | 12 |
| 26 | copy: cookies:_iidt (cold target) | Có | Không | Có | 12 |
| 26 | copy: cookies:_vid_t+_iidt (cold target) | Có | Không | Có | 12 |
| 27 | copy: cookies:_vid_t (cold target) (no-token control) source-first | Có | Không | Có | 12 |
| 27 | copy: cookies:_vid_t (cold target) source-first | Có | Không | Có | 12 |
| 27 | copy: cookies:_iidt (cold target) source-first | Có | Không | Có | 12 |
| 27 | copy: localStorage:_vid_t (cold target) source-first | Có | Không | Có | 12 |
| 27 | copy: cookies:_vid_t (cold target) (no-token control) source-first | Có | Không | Có | 12 |
| 27 | copy: cookies:_vid_t (cold target) (no-token control) target-first | Có | Có | Không | 12 |
| 27 | copy: cookies:_vid_t (cold target) target-first | Có | Không | Có | 12 |
| 27 | copy: cookies:_iidt (cold target) target-first | Có | Không | Có | 12 |
| 27 | copy: localStorage:_vid_t (cold target) target-first | Có | Không | Có | 12 |
| 27 | copy: cookies:_vid_t (cold target) (no-token control) target-first | Có | Có | Không | 12 |
| 27 | reset: cookiesAndLocalStorage + flushed network restart source-first | Có | Có | Không | 12 |
| 27 | reset: customTypes + flushed network restart source-first [Cookies, DiskCache, LocalStorage, MemoryCache] | Có | Có | Không | 12 |
| 27 | reset: customTypes + flushed network restart source-first [Cookies, DiskCache, IndexedDBDatabases, LocalStorage, MemoryCache] | Có | Có | Không | 12 |
| 27 | reset: allSiteDataAndNetwork source-first | Không | Có | Có | 12 |
| 28 | copy: cookies:_vid_t (cold target) (no-token control) source-first | Có | Không | Có | 12 |
| 28 | copy: cookies:_vid_t (cold target) (no-token control) target-first | Có | Không | Có | 12 |
| 28 | copy: cookies:_vid_t (cold target) target-first | Có | Không | Có | 12 |
| 28 | copy: cookies:_vid_t (cold target) (no-token control) target-first | Có | Có | Không | 12 |
| 28 | copy: cookies:_vid_t (cold target) target-first | Có | Không | Có | 12 |
| 28 | copy: cookies:_vid_t (cold target) (no-token control) target-first | Có | Có | Không | 12 |
| 28 | reset: allSiteDataAndNetwork source-first | Có | Có | Không | 12 |
| 28 | reset: allNativeDataAndNetwork source-first | Có | Có | Không | 12 |

Build 23 dùng dừng tiến trình mạng đột ngột; kết quả không tách được tác dụng mất dữ liệu mới chưa flush. Build 24 trở đi kiểm tra flush và PID thay đổi.

Các kết quả chuyển token vào kho đã có trạng thái không đủ để kết luận token vô tác dụng. Các phép xóa riêng lẻ cũng không loại trừ kênh phục hồi từ dữ liệu còn lại.

Build 26 có record cache native xuất hiện lại sau restart; không nhận các lượt đó là bằng chứng nhân quả sạch. Rà mã nguồn nhánh WebKit 614.2.9 cho thấy liệt kê DiskCache duyệt nhiều network session: record này không đủ để kết luận cache nằm trong kho đích. Build 28 kiểm kê riêng tệp cache thực tế và theo dõi trạng thái trước mỗi lượt mở.

Build 27: khi mở đích trước, hai đối chứng không token giữ ID đích; ba loại chuyển token thực (_vid_t cookie, _iidt cookie, _vid_t localStorage) làm đích nhận ID nguồn. Mở nguồn trước thì cả đối chứng không token cũng nhập ID: thứ tự mở là điều kiện quan trọng, chưa xác định hết trạng thái liên quan.

Build 28 với seed Chrome/native: đối chứng không token nhập ID kể cả khi mở đích trước. Vì vậy kết quả về thứ tự của build 27 chưa lặp lại với quy trình đo mới; không kết luận thứ tự hay token là nguyên nhân duy nhất.

Chưa xác lập ID riêng cho mọi hồ sơ mới. Chưa xác định đầy đủ cơ chế lưu giữ ID.

Đối chứng build 28 seed Edge/Opera: hai cặp không token ở trước/sau không nhận ID nguồn. Chuyển đúng cookie _vid_t vào kho đích đã làm đích nhận ID nguồn, khi cả hai dùng Safari 17.2 và đích được mở trước. Cookie hash và trạng thái trước lượt nạp đã kiểm tra; 36 event mới. Đây là đường mang ID đã chứng minh trong điều kiện thử, chưa phải toàn bộ cơ chế giữ ID.
