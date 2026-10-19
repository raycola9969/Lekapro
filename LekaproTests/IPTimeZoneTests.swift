import XCTest
import WebKit
@testable import Lekapro

@MainActor
final class IPTimeZoneTests: XCTestCase {
    private final class Resolver: IPTimeZoneResolving {
        var result: Result<IPTimeZone, Error>
        var calls = 0
        var pause = false
        var cancelled = false
        var waiting: CheckedContinuation<Void, Never>?
        init(_ zone: String = "Asia/Tokyo") throws { result = .success(try IPTimeZone(ip: "192.0.2.1", identifier: zone)) }
        func resolve(dataStore: WKWebsiteDataStore, proxy: ProxyRecord?, userAgent: String?) async throws -> IPTimeZone {
            calls += 1; cancelled = false
            if pause { await withCheckedContinuation { waiting = $0 } }
            guard !cancelled else { throw CancellationError() }
            return try result.get()
        }
        func resume() { waiting?.resume(); waiting = nil }
        func cancel() { cancelled = true; resume() }
    }
    private func store() -> ProfileStore {
        ProfileStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("profiles.json"))
    }
    private func profile(in store: ProfileStore) throws -> BrowserProfile {
        var p = BrowserProfile(); p.timeZoneMode = .ip; p.privacy.blockTrackers = false
        p.tabs = [SavedTab(url: "about:blank", title: "Saved")]
        try store.save(p); return p
    }

    func testResponseMustDescribeObservedIPWithValidTimeZone() throws {
        let good: [String: Any] = ["success": true, "ip": "192.0.2.1", "timezone": ["id": "America/Chicago"]]
        XCTAssertEqual(try IPTimeZone(response: good, expectedIP: "192.0.2.1").identifier, "America/Chicago")
        XCTAssertThrowsError(try IPTimeZone(response: good, expectedIP: "192.0.2.2"))
        for bad: [String: Any] in [[:], ["success": false], ["success": true, "ip": "192.0.2.1"],
            ["success": true, "ip": "192.0.2.1", "timezone": ["id": "Invalid/Zone"]]] {
            XCTAssertThrowsError(try IPTimeZone(response: bad, expectedIP: "192.0.2.1"))
        }
        XCTAssertThrowsError(try IPTimeZone(ip: "not-an-ip", identifier: "UTC"))
        XCTAssertTrue(IPTimeZone.sameIP("2001:db8::1", "2001:0db8:0:0:0:0:0:1"))
    }

    func testLegacyConfigurationStillLoadsAndNewModePersists() throws {
        var old = BrowserProfile(); old.timeZoneID = "Asia/Tokyo"
        let decoded = try JSONDecoder().decode(BrowserProfile.self, from: JSONEncoder().encode(old))
        XCTAssertNil(decoded.timeZoneMode); XCTAssertEqual(decoded.effectiveTimeZoneMode, .custom)
        let s = store(); var automatic = try profile(in: s)
        let data = try JSONEncoder().encode(s.database)
        XCTAssertEqual(try JSONDecoder().decode(BrowserDatabase.self, from: data).profiles.first?.effectiveTimeZoneMode, .ip)
        let before = try FingerprintConfiguration.digest(automatic, proxy: nil)
        automatic.timeZoneMode = .device
        XCTAssertNotEqual(before, try FingerprintConfiguration.digest(automatic, proxy: nil))
    }

    func testNoWebsiteTabsOpenUntilLookupCompletes() async throws {
        let s = store(), p = try profile(in: s), resolver = try Resolver()
        resolver.pause = true
        let session = try BrowserSession(profile: p, store: s, timeZoneResolver: resolver)
        defer { session.close() }
        let work = Task { await session.start() }
        while resolver.waiting == nil { await Task.yield() }
        session.addTab(url: URL(string: "https://example.com"))
        XCTAssertTrue(session.tabs.isEmpty)
        session.persist(); XCTAssertEqual(s.profile(p.id)?.tabs, p.tabs)
        resolver.resume(); await work.value
        XCTAssertEqual(session.tabs.count, 1); XCTAssertEqual(session.ipTimeZone?.identifier, "Asia/Tokyo")
    }

    func testLookupFailureKeepsSavedTabsAndRetryCanRecover() async throws {
        let s = store(), p = try profile(in: s), resolver = try Resolver()
        resolver.result = .failure(BrowserError.invalid("Fixture lookup unavailable"))
        let session = try BrowserSession(profile: p, store: s, timeZoneResolver: resolver)
        defer { session.close() }
        await session.start(); session.persist(); session.addTab()
        XCTAssertTrue(session.tabs.isEmpty); XCTAssertNotNil(session.startupError)
        XCTAssertEqual(s.profile(p.id)?.tabs, p.tabs)
        resolver.result = .success(try IPTimeZone(ip: "192.0.2.1", identifier: "UTC"))
        await session.retryStart()
        XCTAssertNil(session.startupError); XCTAssertEqual(session.tabs.count, 1); XCTAssertEqual(resolver.calls, 2)
    }

    func testClosingDuringLookupCannotOpenOrOverwriteTabs() async throws {
        let s = store(), p = try profile(in: s), resolver = try Resolver()
        resolver.pause = true
        let session = try BrowserSession(profile: p, store: s, timeZoneResolver: resolver)
        let work = Task { await session.start() }
        while resolver.waiting == nil { await Task.yield() }
        session.close(); await work.value
        XCTAssertTrue(session.tabs.isEmpty); XCTAssertEqual(s.profile(p.id)?.tabs, p.tabs)
    }

    func testResolvedTimeZoneAppliesNativelyToPageAndWorkerInSeparateProfiles() async throws {
        let s = store()
        for (zone, expectedOffset) in [("Asia/Tokyo", -540), ("America/Chicago", 360), ("Asia/Ho_Chi_Minh", -420)] {
            let p = try profile(in: s), resolver = try Resolver(zone)
            let session = try BrowserSession(profile: p, store: s, timeZoneResolver: resolver)
            await session.start(); defer { session.close() }
            let tab = try XCTUnwrap(session.selectedTab)
            let result = try await Self.context(tab, expectedZone: zone)
            let canonical = try XCTUnwrap(result["expectedCanonical"] as? String)
            XCTAssertEqual(result["zone"] as? String, canonical)
            XCTAssertEqual(result["workerZone"] as? String, canonical)
            XCTAssertEqual(result["offset"] as? Int, expectedOffset)
            XCTAssertEqual(result["workerOffset"] as? Int, expectedOffset)
            XCTAssertEqual(tab.webView.configuration.userContentController.userScripts.count, 0)
        }
    }

    static func context(_ tab: BrowserTab, expectedZone: String) async throws -> [String: Any] {
        tab.webView.loadHTMLString("<!doctype html><title>Timezone check</title>", baseURL: URL(string: "https://timezone.lekapro.invalid"))
        let deadline = Date().addingTimeInterval(15)
        while tab.webView.isLoading || tab.webView.url?.host != "timezone.lekapro.invalid" {
            guard Date() < deadline else { throw BrowserError.invalid("Local timezone fixture did not load") }
            try await Task.sleep(for: .milliseconds(100))
        }
        let result = try await tab.webView.callAsyncJavaScript(#"""
        const date = new Date('2026-01-15T12:00:00Z');
        const source = "const d=new Date('2026-01-15T12:00:00Z');postMessage({workerZone:Intl.DateTimeFormat().resolvedOptions().timeZone,workerOffset:d.getTimezoneOffset()})";
        const url=URL.createObjectURL(new Blob([source],{type:'text/javascript'}));
        return await new Promise((resolve,reject)=>{
          const worker=new Worker(url), timer=setTimeout(()=>{worker.terminate();URL.revokeObjectURL(url);reject(new Error('Worker timed out'))},5000);
          worker.onmessage=e=>{clearTimeout(timer);worker.terminate();URL.revokeObjectURL(url);resolve({zone:Intl.DateTimeFormat().resolvedOptions().timeZone,expectedCanonical:Intl.DateTimeFormat('en-US',{timeZone:expectedZone}).resolvedOptions().timeZone,offset:date.getTimezoneOffset(),...e.data})};
          worker.onerror=()=>{clearTimeout(timer);worker.terminate();URL.revokeObjectURL(url);reject(new Error('Worker failed'))};
        });
        """#, arguments: ["expectedZone": expectedZone], in: nil, contentWorld: .page)
        return try XCTUnwrap(result as? [String: Any])
    }
}
