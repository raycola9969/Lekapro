import SwiftUI

struct AutomaticProfileCreationView: View {
    @EnvironmentObject private var store: ProfileStore
    @EnvironmentObject private var workspace: BrowserWorkspace
    @Environment(\.dismiss) private var dismiss
    @StateObject private var creator: AutomaticProfileCreator
    @State private var proxyText = ""
    @State private var kind = ProxyKind.socks5
    @State private var error: String?
    @Environment(\.scenePhase) private var phase

    init() { _creator = StateObject(wrappedValue: AutomaticProfileCreator()) }
    init(creator: AutomaticProfileCreator) { _creator = StateObject(wrappedValue: creator) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if creator.results.isEmpty {
                    Form {
                        Section("Dán proxy") {
                            Picker("Loại", selection: $kind) {
                                Text("SOCKS5").tag(ProxyKind.socks5)
                                Text("HTTP CONNECT").tag(ProxyKind.http)
                            }
                            Text("host:port:user:pass · mỗi proxy một dòng")
                                .font(.caption).foregroundStyle(.secondary)
                            TextEditor(text: $proxyText).font(.system(.body, design: .monospaced))
                                .frame(minHeight: 150).textInputAutocapitalization(.never).autocorrectionDisabled()
                            Text("Thông tin đăng nhập được lưu trong Keychain. Dòng trùng được gộp; tối đa 20 proxy mỗi đợt.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Section {
                            Button("Tạo hồ sơ") {
                                do {
                                    let inputs = try ProxyPaste.parse(proxyText, kind: kind)
                                    proxyText = ""; error = nil
                                    creator.start(inputs: inputs, store: store, workspace: workspace)
                                } catch { self.error = error.localizedDescription }
                            }.disabled(store.isReadOnly || creator.busy)
                            if let error { Text(error).foregroundStyle(.red) }
                            if !creator.status.isEmpty { Text(creator.status).font(.caption).foregroundStyle(.secondary) }
                        } footer: {
                            Text("App tự gắn proxy, đặt múi giờ theo IP và kiểm tra ID. Nếu trùng, tự xóa hồ sơ mới rồi thử cấu hình iOS khác, tối đa 3 lượt/proxy. Không bảo đảm luôn tạo được ID mới. Giữ app ở màn hình trước trong lúc chạy.")
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { if creator.busy { ProgressView() }; Text(creator.status).font(.headline) }
                        Text("\(creator.approvedCount) hồ sơ đạt · \(creator.duplicateCount) ứng viên trùng đã xóa")
                            .font(.caption).foregroundStyle(.secondary)
                        if phase != .active && creator.busy { Text("Mở lại app để tiếp tục đo.").font(.caption) }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding()
                    List(creator.results) { row in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Image(systemName: row.state == .approved ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(row.state == .approved ? Color.green : Color.secondary)
                                Text("Proxy \(row.position)").font(.subheadline.bold())
                            }
                            Text(row.message).font(.caption)
                        }
                    }.frame(maxHeight: 180)
                    if let review = creator.review { AutomaticReviewPage(controller: review) }
                    else { Spacer() }
                }
            }
            .navigationTitle("Tạo hồ sơ tự động").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(creator.busy ? "Dừng" : "Đóng") {
                        if creator.busy { creator.cancel() } else { dismiss() }
                    }
                }
            }
        }
        .interactiveDismissDisabled(creator.busy)
        .onDisappear { if creator.busy { creator.cancel() } }
    }
}

private struct AutomaticReviewPage: View {
    @ObservedObject var controller: FingerprintReviewController
    var body: some View {
        VStack(spacing: 6) {
            Text(controller.message).font(.caption).padding(.horizontal)
            if let tab = controller.session?.selectedTab { WebViewContainer(webView: tab.webView).id(tab.id) }
            else { Spacer(); ProgressView(); Spacer() }
        }
    }
}
