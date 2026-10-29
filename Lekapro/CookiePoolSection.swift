import SwiftUI
import UniformTypeIdentifiers

struct CookiePoolSection: View {
    @ObservedObject var pool: CookiePoolStore
    @State private var importing = false
    @State private var error: String?
    var body: some View {
        Section {
            Button("Nhập / thay kho cookie JSON hoặc TXT") { importing = true }
                .disabled(pool.loadError != nil)
            Text("\(pool.records.count) cookie · \(pool.domains.count) nhóm domain còn hạn")
                .font(.caption).foregroundStyle(.secondary)
            Toggle("Chia cookie ngẫu nhiên cho hồ sơ mới", isOn: Binding(get: { pool.enabled }, set: {
                do { try pool.setEnabled($0) } catch { self.error = error.localizedDescription }
            })).disabled((pool.domains.isEmpty && !pool.enabled) || pool.loadError != nil)
            if pool.enabled {
                Stepper("Tối đa \(pool.domainCount) nhóm domain / hồ sơ", value: Binding(get: { pool.domainCount }, set: {
                    do { try pool.setDomainCount($0) } catch { self.error = error.localizedDescription }
                }), in: 1...20)
            }
            if let loadError = pool.loadError { Text(loadError).foregroundStyle(.red) }
            if !pool.records.isEmpty || pool.loadError != nil {
                Button("Xóa kho cookie tổng", role: .destructive) {
                    do { try pool.clear() } catch { self.error = error.localizedDescription }
                }
            }
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
        } header: { Text("Kho cookie tổng") } footer: {
            Text("Mỗi hồ sơ nhận toàn bộ cookie còn hạn của các domain được chọn ngẫu nhiên. Kho gốc được dùng lại; các hồ sơ có thể nhận trùng nhóm và chia sẻ phiên đăng nhập. Cookie được nạp trước khi mở website; không tạo lịch sử truy cập hay bảo đảm ID mới.")
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .plainText]) { result in
            do { try pool.replace(with: DocumentReader.read(try result.get())); error = nil }
            catch { self.error = error.localizedDescription }
        }
    }
}
