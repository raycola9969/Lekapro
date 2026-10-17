import SwiftUI

struct ProxyListView: View {
    @EnvironmentObject private var store: ProfileStore
    @EnvironmentObject private var workspace: BrowserWorkspace
    @State private var editing: ProxyRecord?
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Lưu proxy để sử dụng lại trong nhiều hồ sơ. Mật khẩu được giữ trong Keychain của thiết bị.").font(.subheadline).foregroundStyle(.secondary)
                }
                if store.proxies.isEmpty { EmptyStateView("Chưa có proxy", systemImage: "network", description: Text("Thêm SOCKS5, HTTP hoặc HTTPS CONNECT.")) }
                ForEach(store.proxies) { proxy in
                    Button { editing = proxy } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(proxy.name).font(.headline).foregroundStyle(.primary)
                            Text(proxy.endpoint).font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 4)
                    }
                    .swipeActions {
                        Button("Xóa", role: .destructive) {
                            do { workspace.closeAll(); try store.removeProxy(proxy.id) }
                            catch { store.errorMessage = error.localizedDescription }
                        }
                    }
                }
            }
            .navigationTitle("Kho proxy")
            .toolbar { ActionButton("Thêm proxy", systemImage: "plus") { editing = ProxyRecord() } }
            .sheet(item: $editing) { ProxyEditor(proxy: $0) }
        }
    }
}

struct ProxyEditor: View {
    @EnvironmentObject private var store: ProfileStore
    @EnvironmentObject private var workspace: BrowserWorkspace
    @Environment(\.dismiss) private var dismiss
    @State var proxy: ProxyRecord
    @State private var password = ""
    @State private var portText = ""
    @State private var errorMessage: String?
    @State private var credentialLoadFailed = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Proxy") {
                    TextField("Tên", text: $proxy.name)
                    Picker("Loại", selection: $proxy.kind) { ForEach(ProxyKind.allCases) { Text($0.title).tag($0) } }
                    TextField("Hostname hoặc IP", text: $proxy.host).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Cổng", text: $portText).keyboardType(.numberPad)
                }
                Section("Xác thực (nếu có)") {
                    TextField("Username", text: $proxy.username).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Password", text: $password)
                }
                Section { Text("Sau khi đổi proxy, các phiên đang mở sẽ được đóng. Tab được khôi phục khi bạn mở lại hồ sơ.").font(.caption).foregroundStyle(.secondary) }
            }
            .navigationTitle("Cấu hình proxy").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Hủy") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        do {
                            guard let port = Int(portText) else { throw BrowserError.invalid("Cổng phải là số.") }
                            proxy.port = port; proxy.host = proxy.host.trimmingCharacters(in: .whitespacesAndNewlines)
                            try store.saveProxy(proxy, password: password); workspace.closeAll(); dismiss()
                        } catch { errorMessage = error.localizedDescription }
                    }.disabled(credentialLoadFailed)
                }
            }
            .onAppear {
                portText = String(proxy.port)
                do { password = try SecretStore.password(for: proxy.id) ?? "" }
                catch { errorMessage = error.localizedDescription; credentialLoadFailed = true }
            }
            .alert("Thông báo", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("Đóng") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }
}
