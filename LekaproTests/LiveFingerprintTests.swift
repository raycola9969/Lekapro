import XCTest
import UIKit
import WebKit
@testable import Lekapro

// Manual/CI integration probe. Network results are observations, not unit-test
// expectations: matching or different Visitor IDs both produce an honest report.
@MainActor
final class LiveFingerprintTests: XCTestCase {
    func testVisibleDemoOnCurrentWebKit() async throws {
        guard ProcessInfo.processInfo.environment["LEKAPRO_LIVE_FINGERPRINT"] == "1" else {
            throw XCTSkip("Live network probe requires explicit opt-in.")
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let output = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lekapro-live-probe", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let store = ProfileStore(fileURL: root.appendingPathComponent("profiles.json"))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        defer { window.isHidden = true; previousWindow?.makeKeyAndVisible() }
        var report: [String: Any] = ["actualOS": UIDevice.current.systemVersion,
            "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            "environment": "iOS Simulator; not the user's ExitAnty device",
            "target": "https://fingerprint.com/demo/", "completed": false,
            "timestamp": ISO8601DateFormatter().string(from: Date())]
        var cases: [[String: Any]] = []
        func save() throws {
            report["experiments"] = cases
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                .write(to: output.appendingPathComponent("sanitized-summary.json"), options: .atomic)
        }
        try save()
        for fineAudio in [false, true] {
            var pages: [[String: Any]] = []
            var profiles: [BrowserProfile] = []
            var current: [String: Any] = ["case": fineAudio ? "fine-audio-ua" : "native-ua",
                "completed": false]
            do {
                for index in 0..<2 {
                    var profile = BrowserProfile()
                    profile.tabs = [SavedTab(url: "about:blank", title: "Live probe start")]
                    profile.userAgent = index == 0 ? UserAgentPreset.ios172.value : UserAgentPreset.ios1879.value
                    profile.privacy.blockTrackers = false
                    profile.privacy.audioNoise = fineAudio
                    profile.privacy.audioNoiseScale = .fine
                    try store.save(profile)
                    profiles.append(profile)
                    let session = try BrowserSession(profile: profile, store: store)
                    await session.start()
                    let tab = try XCTUnwrap(session.selectedTab)
                    defer { tab.webView.removeFromSuperview(); session.close() }
                    let blankDeadline = Date().addingTimeInterval(30)
                    while tab.webView.url == nil || tab.webView.isLoading {
                        guard Date() < blankDeadline else { throw BrowserError.invalid("Initial blank page did not load.") }
                        try await Task.sleep(for: .milliseconds(100))
                    }
                    tab.webView.frame = try XCTUnwrap(window.rootViewController).view.bounds
                    window.rootViewController?.view.addSubview(tab.webView)
                    tab.navigate(URL(string: "https://fingerprint.com/demo/")!)
                    let first = try await DevicePageDiagnostics.observe(tab: tab, previousOrigin: nil,
                        prefix: "\(fineAudio)-\(index)-initial", evidence: root)
                    try verify(first)
                    pages.append(first)
                    let origin = try XCTUnwrap(first["timeOrigin"] as? Double)
                    tab.webView.reloadFromOrigin()
                    let reload = try await DevicePageDiagnostics.observe(tab: tab, previousOrigin: origin,
                        prefix: "\(fineAudio)-\(index)-reload", evidence: root)
                    try verify(reload)
                    pages.append(reload)
                }
                let ids = pages.compactMap { $0["visitorID"] as? String }
                let agents = pages.compactMap { $0["agentResponse"] as? [String: Any] }
                let events = agents.compactMap { $0["event_id"] as? String }
                let attributes = pages.compactMap {
                    ($0["serverResponse"] as? [String: Any])?["raw_device_attributes"] as? [String: Any]
                }
                guard ids.count == 4, events.count == 4, Set(events).count == 4, attributes.count == 4 else {
                    throw BrowserError.invalid("Four independent server events are required.")
                }
                current["completed"] = true
                current["verifiedPages"] = 4
                current["allEventsUnique"] = true
                current["allAgentResponsesUncached"] = agents.allSatisfy { $0["cache_hit"] as? Bool == false }
                current["uniqueVisitorCount"] = Set(ids).count
                current["differentVisitorIDs"] = ids[0] != ids[2]
                current["stableOnReload"] = [ids[0] == ids[1], ids[2] == ids[3]]
                current["changedRawAttributesAfterReload"] = Set(attributes[1].keys).union(attributes[3].keys).filter {
                    !NSDictionary(dictionary: ["v": attributes[1][$0] ?? NSNull()])
                        .isEqual(to: ["v": attributes[3][$0] ?? NSNull()])
                }.sorted()
            } catch {
                // No identifiers, page text, event IDs or IPs enter public CI artifacts.
                current["errorDomain"] = (error as NSError).domain
                current["errorCode"] = (error as NSError).code
                current["verifiedPages"] = pages.count
                cases.append(current); try save()
                throw BrowserError.invalid("Live demo observation did not finish; see sanitized summary.")
            }
            cases.append(current); try save()
            for profile in profiles {
                await CookieService.clear(try DataStoreFactory.make(id: profile.dataStoreID))
                DataStoreFactory.release(id: profile.dataStoreID)
            }
        }
        report["completed"] = true
        try save()
    }

    private func verify(_ page: [String: Any]) throws {
        let agent = page["agentResponse"] as? [String: Any] ?? [:]
        let server = page["serverResponse"] as? [String: Any] ?? [:]
        let identification = server["identification"] as? [String: Any] ?? [:]
        guard page["serverReady"] as? Bool == true,
              let visitor = page["visitorID"] as? String,
              visitor == agent["visitor_id"] as? String,
              visitor == identification["visitor_id"] as? String,
              let event = server["event_id"] as? String, event == agent["event_id"] as? String,
              agent["cache_hit"] as? Bool == false,
              server["user_agent"] as? String == page["javascriptUserAgent"] as? String else {
            throw BrowserError.invalid("Visible page, agent and server could not be independently matched.")
        }
    }
}
