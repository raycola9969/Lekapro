import SwiftUI
import UniformTypeIdentifiers

struct ProfileListView: View {
    @EnvironmentObject private var store: ProfileStore
    @EnvironmentObject private var workspace: BrowserWorkspace
    @State private var search = ""
    @State private var editing: BrowserProfile?
    @State private var activeSession: BrowserSession?
    @State private var deleting: BrowserProfile?
    @State private var reviewing: BrowserProfile?
    @State private var reviewAfterEditor: UUID?
    @State private var busy = false
    @State private var automaticCreation = false
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
                        EmptyStateView(search.isEmpty ? "Tạo hồ sơ đầu tiên" : "Không tìm thấy hồ sơ", systemImage: "square.stack", description: Text("Mỗi hồ sơ có dữ liệu website riêng."))
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
                                    if let check = profile.fingerprintCheck {
                                        Text(check.title).font(.caption2).foregroundStyle(check.allowsBrowsing ? Color.green : Color.orange)
                                    }
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right").foregroundStyle(.secondary)
                            }.padding(.vertical, 6)
                        }
                        .contextMenu {
                            ActionButton("Mở", systemImage: "globe") { launch(profile) }
                            ActionButton("Chỉnh sửa", systemImage: "slider.horizontal.3") { editing = profile }
                            ActionButton("Kiểm tra Visitor ID", systemImage: "checkmark.shield") { reviewing = profile }
                            ActionButton("Sao chép cấu hình", systemImage: "doc.on.doc") {
                                do {
                                    var copy = profile.duplicated(); copy.fingerprintCheck = .newCandidate
                                    try store.save(copy)
                                } catch { store.errorMessage = error.localizedDescription }
                            }
                            ActionButton("Xóa hồ sơ", systemImage: "trash", role: .destructive) { deleting = profile }
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    ActionButton("Tạo hồ sơ tự động", systemImage: "plus") { automaticCreation = true }
                        .disabled(store.isReadOnly || busy)
                    ActionButton("Tạo thủ công", systemImage: "slider.horizontal.3") {
                        var profile = BrowserProfile(); profile.timeZoneMode = .ip
                        editing = profile
                    }.disabled(store.isReadOnly || busy)
                }
            }
            .sheet(item: $editing, onDismiss: {
                if let id = reviewAfterEditor { reviewing = store.profile(id); reviewAfterEditor = nil }
            }) {
                ProfileEditor(profile: $0, onSaved: { profile in
                    if let check = profile.fingerprintCheck, !check.allowsBrowsing { reviewAfterEditor = profile.id }
                })
            }
            .fullScreenCover(item: $activeSession) { BrowserView(session: $0) }
            .fullScreenCover(item: $reviewing) { FingerprintReviewView(profileID: $0.id) }
            .fullScreenCover(isPresented: $automaticCreation) { AutomaticProfileCreationView() }
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
        if let check = store.profile(profile.id)?.fingerprintCheck, !check.allowsBrowsing {
            reviewing = profile; return
        }
        do { activeSession = try workspace.session(for: profile, store: store) }
        catch { store.errorMessage = error.localizedDescription }
    }
}

struct ProfileEditor: View {
    @EnvironmentObject private var store: ProfileStore
    @EnvironmentObject private var workspace: BrowserWorkspace
    @Environment(\.dismiss) private var dismiss
    @State var profile: BrowserProfile
    var onSaved: (BrowserProfile) -> Void = { _ in }
    @State private var checkNewProfile = true
    @StateObject private var cookiePool = CookiePoolStore.shared
    @State private var saving = false
    @State private var seededNewStore = false
    @State private var importingCookies = false
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
                    Picker("Phông chữ website", selection: $profile.fontFamily) {
                        Text("Theo website").tag(ProfileFont?.none)
                        ForEach(ProfileFont.allCases) { font in Text(font.title).tag(Optional(font)) }
                    }
                    if profile.fontFamily != nil {
                        Text("Dùng một họ phông cho nội dung website. Có thể thay bố cục hoặc biểu tượng dùng phông.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Picker("Chữ tối thiểu", selection: $profile.minimumFontSize) {
                        Text("Mặc định").tag(Double?.none)
                        ForEach([16.0, 20.0, 24.0, 32.0], id: \.self) { size in
                            Text("\(Int(size)) điểm").tag(Optional(size))
                        }
                    }
                    Picker("Múi giờ", selection: Binding(get: { profile.effectiveTimeZoneMode }, set: {
                        profile.timeZoneMode = $0
                        profile.timeZoneID = $0 == .custom ? (profile.timeZoneID ?? "UTC") : nil
                    })) {
                        ForEach(ProfileTimeZoneMode.allCases) { Text($0.title).tag($0) }
                    }
                    if profile.effectiveTimeZoneMode == .custom {
                        TextField("Ví dụ: Asia/Ho_Chi_Minh", text: Binding(get: { profile.timeZoneID ?? "UTC" }, set: { profile.timeZoneID = $0 }))
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                    }
                    if profile.effectiveTimeZoneMode == .ip {
                        Text("Tự xác định múi giờ từ IP thoát qua proxy của hồ sơ; kết nối trực tiếp dùng IP mạng hiện tại. Không mở web nếu chưa xác định được. Việc tra cứu gửi IP thoát tới ipwho.is.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else if profile.effectiveTimeZoneMode == .custom {
                        Text("Múi giờ thủ công áp dụng cho riêng hồ sơ này.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section {
                    Picker("User-Agent", selection: Binding(get: {
                        UserAgentPreset.matching(profile.userAgent)
                    }, set: { preset in
                        profile.userAgent = preset == .custom ? "" : preset.value
                    })) {
                        ForEach(UserAgentPreset.allCases) { Text($0.title).tag($0) }
                    }
                    if UserAgentPreset.matching(profile.userAgent) == .custom {
                        TextField("Mozilla/5.0 …", text: Binding(get: { profile.userAgent ?? "" }, set: { profile.userAgent = $0 }), axis: .vertical)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                    }
                } header: { Text("Nhận diện trình duyệt") } footer: {
                    Text("User-Agent thay thông tin trình duyệt gửi website. iOS và WebKit thực vẫn theo phiên bản trên máy.")
                }
                Section("Kết nối") {
                    Picker("Proxy", selection: $profile.proxyID) {
                        Text("Kết nối trực tiếp").tag(UUID?.none)
                        ForEach(store.proxies) { Text($0.name).tag(Optional($0.id)) }
                    }
                    if profile.proxyID != nil { Text("Proxy áp dụng cho hồ sơ này. Kiểm tra IP sau khi mở và kiểm tra kết nối khi proxy bị ngắt.").font(.caption).foregroundStyle(.secondary) }
                }
                if store.profile(profile.id) == nil {
                    CookiePoolSection(pool: cookiePool) { importingCookies = true }
                    Section {
                        Toggle("Kiểm tra ID trước khi sử dụng", isOn: $checkNewProfile)
                    } footer: {
                        Text("Mở Fingerprint bằng kết nối của hồ sơ. Nếu ID trùng lịch sử Lekapro, tự xóa hồ sơ mới; nếu đo lỗi, giữ trạng thái chưa đạt. Hồ sơ cũ chưa được đo không nằm trong lịch sử so sánh.")
                    }
                } else if let seeded = profile.cookieSeed {
                    Section("Cookie ban đầu") {
                        Text("Đã nạp \(seeded.cookieCount) cookie từ \(seeded.domains.count) nhóm domain khi tạo.")
                        Text(seeded.domains.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section {
                    Toggle("Chặn tracker cơ bản", isOn: $profile.privacy.blockTrackers)
                    Toggle("Chặn đọc Canvas", isOn: $profile.privacy.blockCanvasReadback)
                    Toggle("Chặn đọc Audio", isOn: $profile.privacy.blockAudioReadback)
                    Toggle("Chặn WebRTC", isOn: $profile.privacy.blockWebRTC)
                    Toggle("Chặn WebGL", isOn: Binding(get: { profile.privacy.blockWebGL == true }, set: { profile.privacy.blockWebGL = $0 }))
                    Toggle("Giảm thông tin CPU/màn hình", isOn: Binding(get: { profile.privacy.reduceHardwareInfo == true }, set: { profile.privacy.reduceHardwareInfo = $0 }))
                    Toggle("Áp dụng cho Blob Worker · thử nghiệm", isOn: Binding(get: { profile.privacy.protectBlobWorkers == true }, set: { profile.privacy.protectBlobWorkers = $0 }))
                        .disabled(profile.privacy.reduceHardwareInfo != true && profile.privacy.blockWebGL != true)
                } header: { Text("Riêng tư") } footer: {
                    Text("Có thể ảnh hưởng website, đồ họa và xử lý song song. Tùy chọn Worker chỉ áp dụng cho classic Blob Worker tạo trong trang; chưa bao phủ module, URL bên ngoài, Shared/Service Worker. Địa chỉ Blob Worker có thể đổi. App không thay kết quả kiểm tra của website.")
                }
                Section {
                    Toggle("Nhiễu Canvas theo hồ sơ", isOn: Binding(get: { profile.privacy.canvasNoise == true }, set: { profile.privacy.canvasNoise = $0 }))
                        .disabled(profile.privacy.blockCanvasReadback)
                    Toggle("Nhiễu Audio theo hồ sơ", isOn: Binding(get: { profile.privacy.audioNoise == true }, set: { profile.privacy.audioNoise = $0 }))
                        .disabled(profile.privacy.blockAudioReadback)
                    if profile.privacy.audioNoise == true && !profile.privacy.blockAudioReadback {
                        Picker("Mức nhiễu Audio", selection: Binding(get: { profile.privacy.audioNoiseScale ?? .standard }, set: { profile.privacy.audioNoiseScale = $0 })) {
                            ForEach(AudioNoiseScale.allCases) { scale in Text(scale.title).tag(scale) }
                        }
                    }
                } header: { Text("Bảo vệ đọc dữ liệu · thử nghiệm") } footer: {
                    Text("Thay đổi nhẹ kết quả đọc ảnh hoặc âm thanh, ổn định theo hồ sơ và website. Có thể ảnh hưởng xuất ảnh và xử lý âm thanh. Không bảo đảm website không liên kết các hồ sơ.")
                }
            }
            .disabled(saving)
            .navigationTitle("Cấu hình hồ sơ").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Hủy") { dismiss() }.disabled(saving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        saving = true
                        Task {
                        defer { saving = false }
                        do {
                            profile.name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
                            try AddressInput.validateHome(profile.homeURL)
                            workspace.close(profile.id)
                            if let latest = store.profile(profile.id) {
                                profile.tabs = latest.tabs; profile.selectedTabID = latest.selectedTabID
                                profile.history = latest.history; profile.bookmarks = latest.bookmarks
                            } else {
                                profile.fingerprintCheck = checkNewProfile ? .newCandidate : nil
                                var proposed = store.database
                                proposed.profiles.append(profile)
                                try ProfileStore.validate(proposed)
                                if let configuration = cookiePool.configuration {
                                    seededNewStore = true
                                    profile.cookieSeed = try await configuration.apply(to: profile, proxy: store.proxy(profile.proxyID))
                                }
                            }
                            try store.save(profile)
                            if let saved = store.profile(profile.id) { onSaved(saved) }
                            dismiss()
                        } catch { errorMessage = error.localizedDescription }
                        }
                    }
                    .disabled(saving || (store.profile(profile.id) == nil && cookiePool.loadError != nil))
                }
            }
            .alert("Chưa lưu được", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("Đóng") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
        .interactiveDismissDisabled(saving)
        .onDisappear {
            if seededNewStore && store.profile(profile.id) == nil {
                DataStoreFactory.release(id: profile.dataStoreID)
                try? DataStoreFactory.removeRejectedLegacyDirectory(id: profile.dataStoreID)
            }
        }
        .fileImporter(isPresented: $importingCookies, allowedContentTypes: [.json, .plainText]) { result in
            do { try cookiePool.replace(with: DocumentReader.read(try result.get())) }
            catch { errorMessage = error.localizedDescription }
        }
    }
}
