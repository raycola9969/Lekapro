import Foundation
import WebKit
import Combine

@MainActor
final class BrowserSession: ObservableObject, Identifiable {
    let id: UUID
    let dataStore: WKWebsiteDataStore
    let profile: BrowserProfile
    private let store: ProfileStore
    @Published var tabs: [BrowserTab] = []
    @Published var selectedTabID: UUID?
    @Published var message: String?
    @Published var downloads: [URL] = []
    private var started = false
    private var blocker: WKContentRuleList?
    private var saveTask: Task<Void, Never>?
    var selectedTab: BrowserTab? { tabs.first { $0.id == selectedTabID } }

    init(profile: BrowserProfile, store: ProfileStore) throws {
        self.id = profile.id; self.profile = profile; self.store = store
        if let proxyID = profile.proxyID, store.proxy(proxyID) == nil { throw BrowserError.invalid("Proxy của hồ sơ không còn tồn tại.") }
        dataStore = try DataStoreFactory.make(id: profile.dataStoreID, proxy: store.proxy(profile.proxyID))
    }
    func start() async {
        guard !started else { return }; started = true
        if profile.privacy.blockTrackers {
            do { blocker = try await PrivacyService.blocker() }
            catch { message = "Chưa bật được bộ chặn tracker: \(error.localizedDescription)" }
        }
        if profile.tabs.isEmpty { addTab(url: URL(string: profile.homeURL)) }
        else {
            for saved in profile.tabs.prefix(30) {
                let url = (try? AddressInput.resolve(saved.url)) ?? URL(string: "about:blank")!
                addTab(url: url, id: saved.id)
            }
            if tabs.contains(where: { $0.id == profile.selectedTabID }) { selectedTabID = profile.selectedTabID }
        }
        store.update(id) { $0.lastUsed = Date() }
        persist()
    }
    func addTab(url: URL? = nil, id: UUID = UUID()) {
        guard tabs.count < 30 else { message = "Tối đa 30 tab mỗi hồ sơ."; return }
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = dataStore
        configuration.allowsInlineMediaPlayback = true
        configuration.defaultWebpagePreferences.preferredContentMode = profile.desktopMode ? .desktop : .mobile
        if let blocker { configuration.userContentController.add(blocker) }
        PrivacyService.install(profile.privacy, controller: configuration.userContentController)
        let tab = BrowserTab(id: id, configuration: configuration, proxy: store.proxy(profile.proxyID))
        tab.onChange = { [weak self] in self?.scheduleSave() }
        tab.onNewTab = { [weak self] url in self?.addTab(url: url) }
        tab.onVisit = { [weak self] title, url in
            guard let self else { return }
            self.store.update(self.id) { value in
                value.history.removeAll { $0.url == url.absoluteString }
                value.history.insert(PageRecord(title: title, url: url.absoluteString), at: 0)
                value.history = Array(value.history.prefix(500))
            }
        }
        tab.onDownload = { [weak self] url in self?.downloads.insert(url, at: 0); self?.message = "Đã tải: \(url.lastPathComponent)" }
        tabs.append(tab); selectedTabID = tab.id
        tab.navigate(url ?? URL(string: profile.homeURL)!)
        scheduleSave()
    }
    func closeTab(_ id: UUID) {
        guard let tab = tabs.first(where: { $0.id == id }) else { return }
        tab.close(); tabs.removeAll { $0.id == id }
        if selectedTabID == id { selectedTabID = tabs.last?.id }
        if tabs.isEmpty { addTab(url: URL(string: "about:blank")) }
        persist()
    }
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            self?.persist()
        }
    }
    func persist() {
        guard started else { return }
        let snapshot = tabs.map { SavedTab(id: $0.id, url: $0.url?.absoluteString ?? "about:blank", title: $0.title) }
        store.update(id) { $0.tabs = snapshot; $0.selectedTabID = selectedTabID }
    }
    func close() {
        saveTask?.cancel(); persist()
        tabs.forEach { $0.close() }; tabs = []; selectedTabID = nil
        DataStoreFactory.release(id: profile.dataStoreID)
    }
    func bookmarkCurrentPage() {
        guard let tab = selectedTab, let url = tab.url, ["http", "https"].contains(url.scheme ?? "") else { return }
        store.update(id) { value in
            guard !value.bookmarks.contains(where: { $0.url == url.absoluteString }) else { return }
            value.bookmarks.append(PageRecord(title: tab.title, url: url.absoluteString))
        }
        message = "Đã thêm dấu trang."
    }
}

@MainActor
final class BrowserWorkspace: ObservableObject {
    private var sessions: [UUID: BrowserSession] = [:]
    func session(for profile: BrowserProfile, store: ProfileStore) throws -> BrowserSession {
        if let session = sessions[profile.id] { return session }
        let session = try BrowserSession(profile: profile, store: store)
        sessions[profile.id] = session
        return session
    }
    func close(_ id: UUID) { sessions.removeValue(forKey: id)?.close() }
    func closeAll() { Array(sessions.keys).forEach(close) }
    func persistAll() { sessions.values.forEach { $0.persist() } }
    func delete(_ profile: BrowserProfile, store: ProfileStore) async throws {
        close(profile.id)
        await CookieService.clear(try DataStoreFactory.make(id: profile.dataStoreID))
        DataStoreFactory.release(id: profile.dataStoreID)
        try store.removeProfile(profile.id)
    }
}
