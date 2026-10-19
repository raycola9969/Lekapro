import Foundation
import WebKit
import Combine

@MainActor
final class BrowserSession: ObservableObject, Identifiable {
    let id: UUID
    let dataStore: WKWebsiteDataStore
    let profile: BrowserProfile
    private let store: ProfileStore
    private let persistsBrowsingState: Bool
    @Published var tabs: [BrowserTab] = []
    @Published var selectedTabID: UUID?
    @Published var message: String?
    @Published var downloads: [URL] = []
    @Published private(set) var ipTimeZone: IPTimeZone?
    @Published private(set) var startupError: String?
    private var started = false
    private var ready = false
    private var closed = false
    private let timeZoneResolver: any IPTimeZoneResolving
    private var blocker: WKContentRuleList?
    private var saveRevision = 0
    private var processPool: WKProcessPool?
    private let fontStyle: NSObject?
    var selectedTab: BrowserTab? { tabs.first { $0.id == selectedTabID } }

    init(profile: BrowserProfile, store: ProfileStore, persistsBrowsingState: Bool = true,
         timeZoneResolver: (any IPTimeZoneResolving)? = nil) throws {
        self.id = profile.id; self.profile = profile; self.store = store
        self.timeZoneResolver = timeZoneResolver ?? IPTimeZoneResolver()
        self.persistsBrowsingState = persistsBrowsingState
        if persistsBrowsingState, let check = store.profile(profile.id)?.fingerprintCheck, !check.allowsBrowsing {
            throw BrowserError.invalid("Hồ sơ cần kiểm tra ID trước khi sử dụng.")
        }
        if let font = profile.fontFamily {
            fontStyle = try LegacyWebKitBridge.makeFontStyle(family: font.css)
        } else { fontStyle = nil }
        if profile.effectiveTimeZoneMode == .custom, let zone = profile.timeZoneID {
            processPool = try LegacyWebKitBridge.makeProcessPool(timeZone: zone)
        }
        if let proxyID = profile.proxyID, store.proxy(proxyID) == nil { throw BrowserError.invalid("Proxy của hồ sơ không còn tồn tại.") }
        dataStore = try DataStoreFactory.make(id: profile.dataStoreID, proxy: store.proxy(profile.proxyID),
            diagnosticQuota: DiagnosticEngineRegistry.originQuota(profileID: profile.id),
            diagnosticEphemeral: DiagnosticEngineRegistry.ephemeralStore(profileID: profile.id))
    }
    func start() async {
        guard !started, !closed else { return }; started = true
        startupError = nil
        if profile.effectiveTimeZoneMode == .ip {
            message = "Đang xác định múi giờ theo IP thoát…"
            do {
                let value = try await timeZoneResolver.resolve(dataStore: dataStore,
                    proxy: store.proxy(profile.proxyID), userAgent: profile.userAgent)
                try Task.checkCancellation()
                guard !closed else { return }
                processPool = try LegacyWebKitBridge.makeProcessPool(timeZone: value.identifier)
                ipTimeZone = value; message = "Múi giờ theo IP: \(value.identifier)"
            } catch {
                guard !closed else { return }
                startupError = error.localizedDescription; message = startupError
                return
            }
        }
        guard !closed else { return }
        if profile.privacy.blockTrackers {
            do { blocker = try await PrivacyService.blocker() }
            catch { message = "Chưa bật được bộ chặn tracker: \(error.localizedDescription)" }
        }
        guard !closed, !Task.isCancelled else { return }
        ready = true
        if !persistsBrowsingState { addTab(url: URL(string: "about:blank")); return }
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
        guard ready, !closed else { return }
        guard tabs.count < 30 else { message = "Tối đa 30 tab mỗi hồ sơ."; return }
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = dataStore
        if let processPool { configuration.processPool = processPool }
        if let size = profile.minimumFontSize { configuration.preferences.minimumFontSize = CGFloat(size) }
        if let fontStyle { LegacyWebKitBridge.installFontStyle(fontStyle, controller: configuration.userContentController) }
        configuration.allowsInlineMediaPlayback = true
        configuration.defaultWebpagePreferences.preferredContentMode = profile.desktopMode ? .desktop : .mobile
        do { try DiagnosticEngineRegistry.apply(profileID: profile.id, configuration: configuration) }
        catch { message = error.localizedDescription; return }
        if let blocker { configuration.userContentController.add(blocker) }
        PrivacyService.install(profile.privacy, controller: configuration.userContentController)
        ReadbackPrivacy.install(profile: profile, controller: configuration.userContentController)
        let tab = BrowserTab(id: id, configuration: configuration, proxy: store.proxy(profile.proxyID), userAgent: profile.userAgent,
            diagnosticNavigatorPlatform: DiagnosticEngineRegistry.navigatorPlatform(profileID: profile.id))
        tab.onChange = { [weak self] in self?.scheduleSave() }
        tab.onNewTab = { [weak self] url in self?.addTab(url: url) }
        tab.onVisit = { [weak self] title, url in
            guard let self, self.persistsBrowsingState else { return }
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
        saveRevision &+= 1
        let revision = saveRevision
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) { [weak self] in
            guard let self, self.saveRevision == revision else { return }
            self.persist()
        }
    }
    func persist() {
        guard started, ready, persistsBrowsingState else { return }
        let snapshot = tabs.map { SavedTab(id: $0.id, url: $0.url?.absoluteString ?? "about:blank", title: $0.title) }
        store.update(id) { $0.tabs = snapshot; $0.selectedTabID = selectedTabID }
    }
    func close() {
        closed = true; timeZoneResolver.cancel()
        saveRevision &+= 1; persist()
        tabs.forEach { $0.close() }; tabs = []; selectedTabID = nil
        DataStoreFactory.release(id: profile.dataStoreID)
    }
    func retryStart() async {
        guard startupError != nil, tabs.isEmpty, !closed else { return }
        started = false; await start()
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
    @Published var diagnosticSession: BrowserSession?
    private var sessions: [UUID: BrowserSession] = [:]
    func session(for profile: BrowserProfile, store: ProfileStore) throws -> BrowserSession {
        guard let current = store.profile(profile.id) else { throw BrowserError.invalid("Không tìm thấy hồ sơ.") }
        if let check = current.fingerprintCheck, !check.allowsBrowsing {
            throw BrowserError.invalid("Hồ sơ cần kiểm tra ID trước khi sử dụng.")
        }
        if let session = sessions[profile.id], current.effectiveTimeZoneMode != .ip { return session }
        close(profile.id)
        // Closing may persist the latest tabs; use that snapshot when reopening.
        let session = try BrowserSession(profile: store.profile(profile.id) ?? current, store: store)
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
    func deleteRejectedCandidate(_ id: UUID, configurationDigest: String, store: ProfileStore) async throws {
        let candidate = try store.rejectedCandidate(id, configurationDigest: configurationDigest)
        close(id)
        await CookieService.clear(try DataStoreFactory.make(id: candidate.dataStoreID))
        DataStoreFactory.release(id: candidate.dataStoreID)
        _ = try store.rejectedCandidate(id, configurationDigest: configurationDigest)
        try store.removeProfile(id)
    }
}
