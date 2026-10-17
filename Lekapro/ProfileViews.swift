import SwiftUI

struct ProfileListView: View {
    @EnvironmentObject private var store: ProfileStore
    @EnvironmentObject private var workspace: BrowserWorkspace
    @State private var search = ""
    @State private var editing: BrowserProfile?
    @State private var activeSession: BrowserSession?
    @State private var deleting: BrowserProfile?
    @State private var busy = false
    private var filtered: [BrowserProfile] {
        store.profiles.filter { search.isEmpty || ($0.name + " " + $0.tags).localizedCaseInsensitiveContains(search) }
            .sorted { ($0.lastUsed ?? $0.createdAt) > ($1.lastUsed ?? $1.createdAt) }
    }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "square.stack.3d.up.fill").font(.largeTitle).foregroundStyle(.mint)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Không gian của bạn").font(.title3.bold())
                            Text("\(store.profiles.count) hồ sơ · dữ liệu lưu trên thiết bị").font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 12)
                }
                Section("Hồ sơ trình duyệt") {
                    if filtered.isEmpty {
                        ContentUnavailableView(search.isEmpty ? "Tạo hồ sơ đầu tiên" : "Không tìm thấy hồ sơ", systemImage: "square.stack", description: Text("Mỗi hồ sơ có dữ liệu website riêng."))
                            .listRowBackground(Color.clear)
                    }
                    ForEach(filtered) { profile in
                        Button { launch(profile) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "person.crop.square.fill").font(.title).foregroundStyle(profile.tint)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(profile.name).font(.headline).foregroundStyle(.primary)
                                    Text(store.proxy(profile.proxyID)?.name ?? "Kết nối trực tiếp").font(.caption).foregroundStyle(.secondary)
                                    if !profile.tags.isEmpty { Text(profile.tags).font(.caption2).foregroundStyle(profile.tint) }
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right").foregroundStyle(.secondary)
                            }.padding(.vertical, 6)
                        }
                        .contextMenu {
                            Button("Mở", systemImage: "globe") { launch(profile) }
                            Button("Chỉnh sửa", systemImage: "slider.horizontal.3") { editing = profile }
                            Button("Sao chép cấu hình", systemImage: "doc.on.doc") {
                                do { try store.save(profile.duplicated()) } catch { store.errorMessage = error.localizedDescription }
                            }
                            Button("Xóa hồ sơ", systemImage: "trash", role: .destructive) { deleting = profile }
                        }
                        .swipeActions {
                            Button("Xóa", role: .destructive) { deleting = profile }
                            Button("Sửa") { editing = profile }.tint(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Lekapro")
            .searchable(text: $search, prompt: "Tên hồ sơ hoặc nhãn")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Tạo hồ sơ", systemImage: "plus") { editing = BrowserProfile() }.disabled(store.isReadOnly || busy)
                }
            }
            .sheet(item: $editing) { ProfileEditor(profile: $0) }
            .fullScreenCover(item: $activeSession) { BrowserView(session: $0) }
            .confirmationDialog("Xóa hồ sơ và dữ liệu website?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button("Xóa hồ sơ", role: .destructive) {
                    guard let profile = deleting else { return }
                    deleting = nil; busy = true
                    Task {
                        do { try await workspace.delete(profile, store: store) }
                        catch { store.errorMessage = error.localizedDescription }
                        busy = false
                    }
                }
            } message: { Text("Cookie, dữ liệu website, tab và lịch sử của hồ sơ này sẽ được xóa.") }
            .overlay { if busy { ProgressView("Đang xóa dữ liệu…").padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)) } }
        }
    }
    private func launch(_ profile: BrowserProfile) {
        do { activeSession = try workspace.session(for: profile, store: store) }
        catch { store.errorMessage = error.localizedDescription }
    }
}

struct ProfileEditor: View {
    @EnvironmentObject private var store: ProfileStore
    @EnvironmentObject private var workspace: BrowserWorkspace
    @Environment(\.dismiss) private var dismiss
    @State var profile: BrowserProfile
    @State private var errorMessage: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Thông tin") {
                    TextField("Tên hồ sơ", text: $profile.name)
                    TextField("Nhãn, phân cách bằng dấu phẩy", text: $profile.tags)
                    TextField("Ghi chú", text: $profile.notes, axis: .vertical).lineLimit(3...6)
                    Picker("Màu", selection: $profile.color) {
                        Text("Mint").tag("mint"); Text("Xanh").tag("blue"); Text("Tím").tag("purple")
                        Text("Cam").tag("orange"); Text("Hồng").tag("pink")
                    }
                }
                Section("Trình duyệt") {
                    TextField("https://example.com", text: $profile.homeURL).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Toggle("Yêu cầu giao diện máy tính", isOn: $profile.desktopMode)
                }
                Section("Kết nối") {
                    Picker("Proxy", selection: $profile.proxyID) {
                        Text("Kết nối trực tiếp").tag(UUID?.none)
                        ForEach(store.proxies) { Text($0.name).tag(Optional($0.id)) }
                    }
                    if profile.proxyID != nil { Text("Khi proxy lỗi, app không cho phép WebKit chuyển sang kết nối trực tiếp.").font(.caption).foregroundStyle(.secondary) }
                }
                Section {
                    Toggle("Chặn tracker cơ bản", isOn: $profile.privacy.blockTrackers)
                    Toggle("Chặn đọc Canvas", isOn: $profile.privacy.blockCanvasReadback)
                    Toggle("Chặn đọc Audio", isOn: $profile.privacy.blockAudioReadback)
                    Toggle("Chặn WebRTC", isOn: $profile.privacy.blockWebRTC)
                } header: { Text("Riêng tư") } footer: {
                    Text("Các tùy chọn chặn có thể ảnh hưởng website, gọi video hoặc nội dung tương tác. App không thay kết quả kiểm tra của website.")
                }
            }
            .navigationTitle("Cấu hình hồ sơ").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Hủy") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        do {
                            profile.name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
                            try AddressInput.validateHome(profile.homeURL)
                            workspace.close(profile.id)
                            if let latest = store.profile(profile.id) {
                                profile.tabs = latest.tabs; profile.selectedTabID = latest.selectedTabID
                                profile.history = latest.history; profile.bookmarks = latest.bookmarks
                            }
                            try store.save(profile); dismiss()
                        } catch { errorMessage = error.localizedDescription }
                    }
                }
            }
            .alert("Chưa lưu được", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("Đóng") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }
}
