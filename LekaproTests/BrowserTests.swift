import XCTest
import WebKit
@testable import Lekapro

@MainActor
final class BrowserTests: XCTestCase {
    private func temporaryFile() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("profiles.json")
    }
    func testAddressParsingDoesNotOpenLocalOrScriptURLs() throws {
        XCTAssertEqual(try AddressInput.resolve("example.com/path").absoluteString, "https://example.com/path")
        XCTAssertEqual(try AddressInput.resolve("hello world").host, "www.google.com")
        XCTAssertThrowsError(try AddressInput.resolve("file:///etc/passwd"))
        XCTAssertThrowsError(try AddressInput.resolve("https://user:password@example.com"))
        XCTAssertThrowsError(try AddressInput.validateHome("example.com"))
    }
    func testDuplicateStartsWithFreshWebsiteIdentity() {
        var profile = BrowserProfile()
        profile.tabs = [SavedTab(url: "https://example.com", title: "Example")]
        profile.history = [PageRecord(title: "Example", url: "https://example.com")]
        let duplicate = profile.duplicated()
        XCTAssertNotEqual(profile.id, duplicate.id)
        XCTAssertNotEqual(profile.dataStoreID, duplicate.dataStoreID)
        XCTAssertTrue(duplicate.tabs.isEmpty)
        XCTAssertTrue(duplicate.history.isEmpty)
        XCTAssertEqual(duplicate.privacy, profile.privacy)
    }
    func testProfilesBeforeUserAgentSettingStillLoadAndRetainData() throws {
        var profile = BrowserProfile()
        profile.userAgent = UserAgentPreset.ios172.value
        profile.history = [PageRecord(title: "Existing history", url: "https://example.com")]
        var old = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(profile)) as? [String: Any])
        old.removeValue(forKey: "userAgent")
        let decoded = try JSONDecoder().decode(BrowserProfile.self, from: JSONSerialization.data(withJSONObject: old))
        XCTAssertNil(decoded.userAgent)
        XCTAssertEqual(decoded.id, profile.id)
        XCTAssertEqual(decoded.dataStoreID, profile.dataStoreID)
        XCTAssertEqual(decoded.history, profile.history)
        let store = ProfileStore(fileURL: temporaryFile())
        try store.save(profile)
        var changed = try XCTUnwrap(store.profile(profile.id))
        changed.userAgent = UserAgentPreset.ios1879.value
        try store.save(changed)
        XCTAssertEqual(store.profile(profile.id)?.dataStoreID, profile.dataStoreID)
        XCTAssertEqual(store.profile(profile.id)?.history, profile.history)
        changed.userAgent = "Bad\r\nInjected: value"
        XCTAssertThrowsError(try store.save(changed))
        XCTAssertEqual(store.profile(profile.id)?.userAgent, UserAgentPreset.ios1879.value)
    }
    func testProfileUserAgentReachesJavaScriptAndNewTabs() async throws {
        let store = ProfileStore(fileURL: temporaryFile())
        var profile = BrowserProfile()
        profile.userAgent = UserAgentPreset.ios172.value
        profile.privacy.blockTrackers = false
        profile.tabs = [SavedTab(url: "about:blank", title: "QA")]
        try store.save(profile)
        let session = try BrowserSession(profile: profile, store: store)
        await session.start()
        defer { session.close() }
        session.addTab(url: URL(string: "about:blank"))
        for tab in session.tabs {
            let deadline = Date().addingTimeInterval(15)
            while tab.webView.url == nil || tab.webView.isLoading {
                guard Date() < deadline else { XCTFail("WebKit did not finish loading"); return }
                try await Task.sleep(for: .milliseconds(100))
            }
            let value = try await tab.webView.evaluateJavaScript("navigator.userAgent") as? String
            XCTAssertEqual(value, UserAgentPreset.ios172.value)
            XCTAssertTrue(tab.webView.configuration.websiteDataStore === session.dataStore)
        }
    }
    func testConfigurationImportCreatesNewIDsAndKeepsExistingProfiles() throws {
        let file = temporaryFile()
        let store = ProfileStore(fileURL: file)
        let first = BrowserProfile()
        try store.save(first)
        let backup = try store.exportConfiguration()
        try store.importConfiguration(backup)
        XCTAssertEqual(store.profiles.count, 2)
        XCTAssertEqual(Set(store.profiles.map(\.dataStoreID)).count, 2)
        XCTAssertEqual(store.profiles[0].id, first.id)
        let reopened = ProfileStore(fileURL: file)
        XCTAssertEqual(reopened.profiles.count, 2)
        XCTAssertFalse(reopened.isReadOnly)
    }
    func testCorruptDatabaseIsPreservedAndNotOverwritten() throws {
        let file = temporaryFile()
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let corrupt = Data("broken data".utf8)
        try corrupt.write(to: file)
        let store = ProfileStore(fileURL: file)
        XCTAssertTrue(store.isReadOnly)
        XCTAssertThrowsError(try store.save(BrowserProfile()))
        XCTAssertEqual(try Data(contentsOf: file), corrupt)
    }
    func testSharedWebsiteDataIdentityIsRejected() {
        let first = BrowserProfile()
        var second = BrowserProfile(); second.dataStoreID = first.dataStoreID
        XCTAssertThrowsError(try ProfileStore.validate(BrowserDatabase(profiles: [first, second])))
    }
    func testProxyRequiresCredentialsAndDisallowsDirectFailover() throws {
        var proxy = ProxyRecord(); proxy.host = "127.0.0.1"; proxy.username = "test"
        XCTAssertThrowsError(try ProxyService.legacyConfiguration(for: proxy, password: nil))
        if #available(iOS 17, *) {
            let config = try ProxyService.configuration(for: proxy, password: "example")
            XCTAssertFalse(config.allowFailover)
        }
        let legacy = try ProxyService.legacyConfiguration(for: proxy, password: "example")
        XCTAssertEqual(legacy["SOCKSProxy"] as? String, "127.0.0.1")
        XCTAssertEqual(legacy["SOCKSPassword"] as? String, "example")
        XCTAssertEqual(legacy["kCFStreamPropertySOCKSUser"] as? String, "test")
        XCTAssertEqual(legacy["kCFStreamPropertySOCKSPassword"] as? String, "example")
        proxy.port = 70000
        XCTAssertThrowsError(try ProxyService.legacyConfiguration(for: proxy, password: "example"))
    }
    func testNetscapeCookieParsingAndValidation() throws {
        let source = "# Netscape HTTP Cookie File\n#HttpOnly_.example.com\tTRUE\t/\tTRUE\t0\tsession\tvalue\n"
        let cookies = try CookieService.parse(Data(source.utf8))
        XCTAssertEqual(cookies.count, 1)
        XCTAssertEqual(cookies.first?.name, "session")
        XCTAssertTrue(cookies.first?.isSecure == true)
        XCTAssertTrue(cookies.first?.isHTTPOnly == true)
        XCTAssertNil(cookies.first?.expiresDate)
        XCTAssertThrowsError(try CookieService.parse(Data("not cookie data".utf8)))
        XCTAssertThrowsError(try CookieRecord(name: "test", value: "value", domain: "bad/domain").cookie())
    }
    func testCookiesAreSharedWithinProfileAndIsolatedBetweenProfiles() async throws {
        let idA = UUID(), idB = UUID()
        let storeA = try DataStoreFactory.make(id: idA)
        let storeB = try DataStoreFactory.make(id: idB)
        let cookieA = try CookieRecord(name: "account", value: "A", domain: "example.com").cookie()
        let cookieB = try CookieRecord(name: "account", value: "B", domain: "example.com").cookie()
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in storeA.httpCookieStore.setCookie(cookieA) { c.resume() } }
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in storeB.httpCookieStore.setCookie(cookieB) { c.resume() } }
        let config1 = WKWebViewConfiguration(); config1.websiteDataStore = storeA
        let config2 = WKWebViewConfiguration(); config2.websiteDataStore = try DataStoreFactory.make(id: idA)
        let tab1 = WKWebView(frame: .zero, configuration: config1)
        let tab2 = WKWebView(frame: .zero, configuration: config2)
        let a1 = await CookieService.all(in: tab1.configuration.websiteDataStore)
        let a2 = await CookieService.all(in: tab2.configuration.websiteDataStore)
        let b = await CookieService.all(in: storeB)
        XCTAssertEqual(a1.first(where: { $0.name == "account" })?.value, "A")
        XCTAssertEqual(a2.first(where: { $0.name == "account" })?.value, "A")
        XCTAssertEqual(b.first(where: { $0.name == "account" })?.value, "B")
        await CookieService.clear(storeA)
        let remainingA = await CookieService.all(in: storeA)
        let remainingB = await CookieService.all(in: storeB)
        XCTAssertTrue(remainingA.isEmpty)
        XCTAssertEqual(remainingB.first(where: { $0.name == "account" })?.value, "B")
        await CookieService.clear(storeB)
    }
    func testTrackerRulesCompileInWebKit() async throws {
        let list = try await PrivacyService.blocker()
        XCTAssertEqual(list.identifier, "Lekapro.Trackers.v1")
    }
    func testLegacyStoresShareWithinProfileAndIsolateBetweenProfiles() async throws {
        let idA = UUID(), idB = UUID()
        let storeA = try DataStoreFactory.make(id: idA, forceLegacy: true)
        let storeA2 = try DataStoreFactory.make(id: idA, forceLegacy: true)
        let storeB = try DataStoreFactory.make(id: idB, forceLegacy: true)
        XCTAssertTrue(storeA.isPersistent)
        XCTAssertTrue(storeA === storeA2)
        let data = Data("[{\"name\":\"legacy\",\"value\":\"A\",\"domain\":\"lekapro.invalid\"}]".utf8)
        _ = try await CookieService.importData(data, into: storeA)
        let a = await CookieService.all(in: storeA2)
        let b = await CookieService.all(in: storeB)
        XCTAssertEqual(a.first(where: { $0.name == "legacy" })?.value, "A")
        XCTAssertTrue(b.isEmpty)
        await CookieService.clear(storeA); await CookieService.clear(storeB)
        DataStoreFactory.release(id: idA); DataStoreFactory.release(id: idB)
    }
}
