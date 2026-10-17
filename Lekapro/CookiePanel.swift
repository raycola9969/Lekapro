import SwiftUI
import WebKit
import UniformTypeIdentifiers

struct CookiePanel: View {
    @ObservedObject var session: BrowserSession
    @Environment(\.dismiss) private var dismiss
    @State private var cookies: [HTTPCookie] = []
    @State private var importing = false
    @State private var exporting = false
    @State private var document = JSONDocument()
    @State private var pendingData: Data?
    @State private var pendingCount = 0
    @State private var errorMessage: String?
    @State private var busy = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Nhập cookie JSON / Netscape TXT", systemImage: "square.and.arrow.down") { importing = true }
                    Button("Xuất cookie JSON", systemImage: "square.and.arrow.up") {
                        Task {
                            do { document = JSONDocument(data: try await CookieService.export(from: session.dataStore)); exporting = true }
                            catch { errorMessage = error.localizedDescription }
                        }
                    }
                    Text("File xuất có thể chứa phiên đăng nhập. Cookie nhập chỉ áp dụng cho hồ sơ này.").font(.caption).foregroundStyle(.secondary)
                }
                Section("\(cookies.count) cookie") {
                    ForEach(Array(cookies.enumerated()), id: \.offset) { _, cookie in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(cookie.name).font(.subheadline.bold()).lineLimit(1)
                            Text(cookie.domain + cookie.path).font(.caption).foregroundStyle(.secondary)
                        }
                        .swipeActions {
                            Button("Xóa", role: .destructive) {
                                session.dataStore.httpCookieStore.delete(cookie) { Task { @MainActor in await refresh() } }
                            }
                        }
                    }
                }
            }
            .disabled(busy)
            .navigationTitle("Cookie").navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Xong") { dismiss() } }
            .task { await refresh() }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .plainText]) { result in
                do {
                    let data = try DocumentReader.read(result.get())
                    pendingCount = try CookieService.parse(data).count
                    pendingData = data
                } catch { errorMessage = error.localizedDescription }
            }
            .confirmationDialog("Nhập \(pendingCount) cookie vào hồ sơ này?", isPresented: Binding(get: { pendingData != nil }, set: { if !$0 { pendingData = nil } }), titleVisibility: .visible) {
                Button("Nhập cookie") {
                    guard let data = pendingData else { return }; pendingData = nil; busy = true
                    Task {
                        do { _ = try await CookieService.importData(data, into: session.dataStore); await refresh() }
                        catch { errorMessage = error.localizedDescription }
                        busy = false
                    }
                }
                Button("Hủy", role: .cancel) { pendingData = nil }
            }
            .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "Lekapro-cookies") { result in
                if case .failure(let error) = result { errorMessage = error.localizedDescription }
            }
            .alert("Thông báo", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("Đóng") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }
    private func refresh() async { cookies = await CookieService.all(in: session.dataStore).sorted { $0.domain < $1.domain } }
}
