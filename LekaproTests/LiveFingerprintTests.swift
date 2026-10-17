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
        let availableCases = ["native-ua", "fine-audio-ua", "native-quota", "quota-audio-ua"]
        let selected = ProcessInfo.processInfo.environment["LEKAPRO_LIVE_CASES"]?
            .split(separator: ",").map(String.init) ?? availableCases
        guard !selected.isEmpty, selected.allSatisfy({ availableCases.contains($0) }) else {
            throw BrowserError.invalid("Unknown live observation case.")
        }
        for testCase in selected {
            let jointCase = testCase == "quota-audio-ua"
            let fineAudio = testCase == "fine-audio-ua" || jointCase
            let quotaCase = testCase == "native-quota" || jointCase
            var pages: [[String: Any]] = []
            var profiles: [BrowserProfile] = []
            var current: [String: Any] = ["case": testCase,
                "completed": false]
            do {
                for index in 0..<2 {
                    var profile = BrowserProfile()
                    profile.tabs = [SavedTab(url: "about:blank", title: "Live probe start")]
                    profile.userAgent = quotaCase ? nil : (index == 0 ? UserAgentPreset.ios172.value : UserAgentPreset.ios1879.value)
                    if jointCase {
                        profile.userAgent = index == 1 ? UserAgentPreset.ios1879.value : UserAgentPreset.ios172.value?
                            .replacingOccurrences(of: "17_2", with: "18_4")
                            .replacingOccurrences(of: "Version/17.2", with: "Version/18.4")
                    }
                    profile.privacy.blockTrackers = false
                    profile.privacy.audioNoise = fineAudio
                    profile.privacy.audioNoiseScale = .fine
                    try store.save(profile)
                    profiles.append(profile)
                    let session: BrowserSession?
                    let tab: BrowserTab
                    if quotaCase {
                        session = nil
                        let config = WKWebViewConfiguration()
                        config.websiteDataStore = try LegacyWebKitBridge.makeQuotaStore(
                            at: root.appendingPathComponent(UUID().uuidString), quota: quota(testCase, index: index))
                        ReadbackPrivacy.install(profile: profile, controller: config.userContentController)
                        tab = BrowserTab(configuration: config, userAgent: profile.userAgent)
                        tab.navigate(URL(string: "about:blank")!)
                    } else {
                        let created = try BrowserSession(profile: profile, store: store)
                        session = created
                        await created.start()
                        tab = try XCTUnwrap(created.selectedTab)
                    }
                    defer { tab.webView.removeFromSuperview(); if let session { session.close() } else { tab.close() } }
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
                    if quotaCase { try verifyQuota(first, testCase: testCase, index: index) }
                    pages.append(first)
                    let origin = try XCTUnwrap(first["timeOrigin"] as? Double)
                    tab.webView.reloadFromOrigin()
                    let reload = try await DevicePageDiagnostics.observe(tab: tab, previousOrigin: origin,
                        prefix: "\(fineAudio)-\(index)-reload", evidence: root)
                    try verify(reload)
                    if quotaCase { try verifyQuota(reload, testCase: testCase, index: index) }
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
                if quotaCase { current["nativeQuotaAppliedOnEveryVisit"] = true }
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

    private func quota(_ testCase: String, index: Int) -> UInt {
        // Synthetic test limits; no user's measured device values are published.
        testCase == "quota-audio-ua" ? [37_700_000_000, 38_000_000_000][index] : UInt(index + 1) * 1024 * 1024 * 1024
    }

    private func verifyQuota(_ page: [String: Any], testCase: String, index: Int) throws {
        let context = page["storageContext"] as? [String: Any] ?? [:]
        let estimate = context["estimate"] as? [String: Any] ?? [:]
        guard context["secureContext"] as? Bool == true,
              (estimate["quota"] as? NSNumber)?.uint64Value == UInt64(quota(testCase, index: index)) else {
            throw BrowserError.invalid("The configured native quota was not observed on the HTTPS page.")
        }
    }
}
