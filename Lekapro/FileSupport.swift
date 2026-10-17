import SwiftUI
import UniformTypeIdentifiers

struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .plainText] }
    var data: Data
    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

enum DocumentReader {
    static func read(_ url: URL) throws -> Data {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 10_000_000 else { throw BrowserError.invalid("File quá lớn, tối đa 10 MB.") }
        return try Data(contentsOf: url)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: ProfileStore
    @State private var importing = false
    @State private var exporting = false
    @State private var document = JSONDocument()
    var body: some View {
        NavigationStack {
            Form {
                Section("Sao lưu cấu hình") {
                    Button("Xuất hồ sơ và cấu hình proxy", systemImage: "square.and.arrow.up") {
                        do { document = JSONDocument(data: try store.exportConfiguration()); exporting = true }
                        catch { store.errorMessage = error.localizedDescription }
                    }
                    Button("Nhập cấu hình từ file JSON", systemImage: "square.and.arrow.down") { importing = true }
                    Text("Bản sao lưu có lịch sử và dấu trang, không chứa mật khẩu proxy hay dữ liệu website. Nhập file tạo hồ sơ mới; proxy cần nhập lại mật khẩu.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Lekapro") {
                    LabeledContent("Phiên bản", value: "0.1.0")
                    LabeledContent("Lưu trữ", value: "Trên thiết bị")
                    Text("Trình duyệt nhiều hồ sơ dùng WebKit. Bộ chặn tracker cơ bản không thay thế danh sách lọc đầy đủ. Các chế độ chặn API chỉ áp dụng trong trang web, chưa bao phủ mọi loại Worker.").font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Cài đặt")
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                do { try store.importConfiguration(DocumentReader.read(try result.get())) }
                catch { store.errorMessage = error.localizedDescription }
            }
            .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "Lekapro-config") { result in
                if case .failure(let error) = result { store.errorMessage = error.localizedDescription }
            }
        }
    }
}
