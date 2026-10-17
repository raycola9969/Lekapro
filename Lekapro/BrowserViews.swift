import SwiftUI
import WebKit

enum BrowserPanel: String, Identifiable {
    case tabs, library, cookies, downloads
    var id: String { rawValue }
}

struct BrowserView: View {
    @ObservedObject var session: BrowserSession
    @Environment(\.dismiss) private var dismiss
    @State private var panel: BrowserPanel?
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { session.persist(); dismiss() } label: { Image(systemName: "chevron.down").padding(8) }.accessibilityLabel("Đóng trình duyệt")
                Image(systemName: "person.crop.square.fill").foregroundStyle(session.profile.tint)
                Text(session.profile.name).font(.subheadline.bold()).lineLimit(1)
                Spacer()
                Button { panel = .tabs } label: { Text("\(session.tabs.count)").font(.caption.bold()).padding(7).overlay(RoundedRectangle(cornerRadius: 6).stroke()) }.accessibilityLabel("Danh sách tab")
                Menu {
                    Button("Tab mới", systemImage: "plus") { session.addTab() }
                    Button("Thêm dấu trang", systemImage: "bookmark") { session.bookmarkCurrentPage() }
                    Button("Dấu trang và lịch sử", systemImage: "books.vertical") { panel = .library }
                    Button("Cookie của hồ sơ", systemImage: "externaldrive") { panel = .cookies }
                    Button("File đã tải", systemImage: "arrow.down.circle") { panel = .downloads }
                    Button("Kiểm tra IP hiện tại", systemImage: "network") { session.selectedTab?.navigate(URL(string: "https://api.ipify.org?format=json")!) }
                    if let url = session.selectedTab?.url, ["https", "http"].contains(url.scheme ?? "") {
                        ShareLink(item: url) { Label("Chia sẻ liên kết", systemImage: "square.and.arrow.up") }
                        Button("Mở ngoài app", systemImage: "safari") { UIApplication.shared.open(url) }
                    }
                } label: { Image(systemName: "ellipsis.circle").font(.title3).padding(8) }
            }.padding(.horizontal, 8).padding(.top, 5).background(.bar)
            if let tab = session.selectedTab { BrowserPage(tab: tab).id(tab.id) }
            else { Spacer(); ProgressView("Đang mở hồ sơ…"); Spacer() }
        }
        .task { await session.start() }
        .onDisappear { session.persist() }
        .sheet(item: $panel) { item in
            switch item {
            case .tabs: TabPickerView(session: session)
            case .library: LibraryView(session: session)
            case .cookies: CookiePanel(session: session)
            case .downloads: DownloadListView()
            }
        }
        .alert("Thông báo", isPresented: Binding(get: { session.message != nil }, set: { if !$0 { session.message = nil } })) {
            Button("Đóng") { session.message = nil }
        } message: { Text(session.message ?? "") }
    }
}

struct BrowserPage: View {
    @ObservedObject var tab: BrowserTab
    @State private var address = ""
    @State private var promptText = ""
    @FocusState private var addressFocused: Bool
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: tab.url?.scheme == "https" ? "lock.fill" : "globe").font(.caption).foregroundStyle(.secondary)
                TextField("Địa chỉ hoặc tìm kiếm", text: $address)
                    .font(.subheadline).keyboardType(.webSearch).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .submitLabel(.go).focused($addressFocused).onSubmit(navigate)
                Button {
                    if tab.loading { tab.webView.stopLoading() } else { tab.webView.reload() }
                } label: { Image(systemName: tab.loading ? "xmark" : "arrow.clockwise") }.accessibilityLabel(tab.loading ? "Dừng tải" : "Tải lại")
            }.padding(12).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 12).padding(.vertical, 8)
            if tab.loading { ProgressView(value: tab.progress).tint(.mint).frame(height: 2) }
            if let error = tab.errorMessage {
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.triangle")
                    Text(error).font(.caption)
                    Spacer()
                    Button("Đóng") { tab.errorMessage = nil }.font(.caption)
                }.foregroundStyle(.orange).padding(12).background(Color.orange.opacity(0.1))
            }
            WebViewContainer(webView: tab.webView).ignoresSafeArea(edges: .bottom)
            HStack {
                Button { tab.webView.goBack() } label: { Image(systemName: "chevron.left").frame(width: 44, height: 40) }.disabled(!tab.canGoBack)
                Button { tab.webView.goForward() } label: { Image(systemName: "chevron.right").frame(width: 44, height: 40) }.disabled(!tab.canGoForward)
                Spacer()
                Text(tab.url?.host ?? "Tab mới").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                if let url = tab.url { ShareLink(item: url) { Image(systemName: "square.and.arrow.up").frame(width: 44, height: 40) } }
            }.padding(.horizontal, 8).background(.bar)
        }
        .onAppear { address = tab.url?.absoluteString ?? "" }
        .onChange(of: tab.url) { _, url in if !addressFocused { address = url?.absoluteString ?? "" } }
        .alert("Trang web", isPresented: Binding(get: { tab.dialogMessage != nil }, set: { if !$0 { tab.resolveDialog(accepted: false) } })) {
            if tab.dialogKind == "prompt" { TextField("Nội dung", text: $promptText) }
            Button("Đồng ý") { tab.resolveDialog(accepted: true, text: promptText); promptText = "" }
            if tab.dialogKind != "alert" { Button("Hủy", role: .cancel) { tab.resolveDialog(accepted: false); promptText = "" } }
        } message: { Text(tab.dialogMessage ?? "") }
    }
    private func navigate() {
        do { tab.navigate(try AddressInput.resolve(address)); addressFocused = false }
        catch { tab.errorMessage = error.localizedDescription }
    }
}

struct TabPickerView: View {
    @ObservedObject var session: BrowserSession
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                ForEach(session.tabs) { tab in
                    Button { session.selectedTabID = tab.id; session.persist(); dismiss() } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tab.title).font(.headline).foregroundStyle(.primary).lineLimit(1)
                                Text(tab.webView.url?.host ?? "Tab mới").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if session.selectedTabID == tab.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(.mint) }
                        }
                    }
                    .swipeActions { Button("Đóng", role: .destructive) { session.closeTab(tab.id) } }
                }
            }.navigationTitle("Các tab")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Xong") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button("Tab mới", systemImage: "plus") { session.addTab(); dismiss() } }
            }
        }
    }
}

struct LibraryView: View {
    @ObservedObject var session: BrowserSession
    @EnvironmentObject private var store: ProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var bookmarks = true
    private var records: [PageRecord] {
        guard let profile = store.profile(session.id) else { return [] }
        return bookmarks ? profile.bookmarks : profile.history
    }
    var body: some View {
        NavigationStack {
            List {
                Picker("Danh sách", selection: $bookmarks) { Text("Dấu trang").tag(true); Text("Lịch sử").tag(false) }.pickerStyle(.segmented)
                if records.isEmpty { ContentUnavailableView("Chưa có mục nào", systemImage: bookmarks ? "bookmark" : "clock") }
                ForEach(records) { record in
                    Button {
                        if let url = URL(string: record.url) { session.selectedTab?.navigate(url); dismiss() }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.title).font(.headline).foregroundStyle(.primary).lineLimit(2)
                            Text(record.url).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }.swipeActions {
                        Button("Xóa", role: .destructive) {
                            store.update(session.id) { value in
                                if bookmarks { value.bookmarks.removeAll { $0.id == record.id } }
                                else { value.history.removeAll { $0.id == record.id } }
                            }
                        }
                    }
                }
            }.navigationTitle("Thư viện").toolbar { Button("Xong") { dismiss() } }
        }
    }
}

struct DownloadListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var files: [URL] = []
    var body: some View {
        NavigationStack {
            List {
                if files.isEmpty { ContentUnavailableView("Chưa tải file", systemImage: "arrow.down.circle") }
                ForEach(files, id: \.self) { file in ShareLink(item: file) { Label(file.lastPathComponent, systemImage: "doc").lineLimit(2) } }
            }.navigationTitle("File đã tải").toolbar { Button("Xong") { dismiss() } }
            .onAppear {
                let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Downloads")
                files = ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []).sorted { $0.lastPathComponent < $1.lastPathComponent }
            }
        }
    }
}
