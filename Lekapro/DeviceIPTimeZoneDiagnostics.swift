import Foundation
import UIKit
import WebKit

// One-shot DEBUG check. Its two in-memory profiles never enter the user's list.
@MainActor
enum DeviceIPTimeZoneDiagnostics {
    private static var started = false
    static func startIfRequested(store: ProfileStore, workspace: BrowserWorkspace) {
        #if DEBUG
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let input = directory.appendingPathComponent("Lekapro-timezone-request.json")
        guard !started, FileManager.default.fileExists(atPath: input.path) else { return }
        started = true
        Task { await run(input: input, store: store, workspace: workspace) }
        #endif
    }
    #if DEBUG
    private struct Request: Decodable { var proxyIDs: [UUID?] }
    private static func run(input: URL, store: ProfileStore, workspace: BrowserWorkspace) async {
        let output = input.deletingLastPathComponent().appendingPathComponent("Lekapro-timezone-report.json")
        let beforeProfiles = store.profiles, beforeProxies = store.proxies
        let ledger = store.database.fingerprintLedger
        let idle = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
        defer { UIApplication.shared.isIdleTimerDisabled = idle }
        var rows: [[String: Any]] = []
        var report: [String: Any] = ["completed": false, "status": "running", "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"]
        func save() {
            report["profiles"] = rows
            if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
                try? data.write(to: output, options: [.atomic, .completeFileProtectionUnlessOpen])
            }
        }
        save()
        do {
            let request = try JSONDecoder().decode(Request.self, from: Data(contentsOf: input))
            guard request.proxyIDs.count == 2, request.proxyIDs[0] == nil,
                  let proxyID = request.proxyIDs[1], store.proxy(proxyID) != nil else {
                throw BrowserError.invalid("Timezone QA requires direct and one saved proxy.")
            }
            try FileManager.default.removeItem(at: input)
            for proxyID in request.proxyIDs {
                var profile = BrowserProfile(); profile.timeZoneMode = .ip; profile.proxyID = proxyID
                profile.privacy.blockTrackers = false
                let session = try BrowserSession(profile: profile, store: store, persistsBrowsingState: false)
                do {
                    try await DeviceBrowserPresentation.show(session, store: store, workspace: workspace)
                    let deadline = Date().addingTimeInterval(90)
                    while session.selectedTab == nil && session.startupError == nil {
                        guard Date() < deadline else { throw BrowserError.invalid("Timezone startup timed out") }
                        try await Task.sleep(for: .milliseconds(200))
                    }
                    if let error = session.startupError { throw BrowserError.invalid(error) }
                    guard let tab = session.selectedTab, let zone = session.ipTimeZone else {
                        throw BrowserError.invalid("Missing resolved timezone")
                    }
                    tab.navigate(URL(string: "https://api.ipify.org/?format=json&timezone_qa=\(UUID().uuidString)")!)
                    var actualIP: String?
                    let networkDeadline = Date().addingTimeInterval(40)
                    while Date() < networkDeadline {
                        if let error = tab.navigationError { throw error }
                        if !tab.webView.isLoading, tab.webView.url?.host == "api.ipify.org",
                           let body = try await tab.webView.evaluateJavaScript("document.body.innerText") as? String,
                           let data = body.data(using: .utf8),
                           let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let ip = value["ip"] as? String { actualIP = ip; break }
                        try await Task.sleep(for: .milliseconds(200))
                    }
                    guard let actualIP, IPTimeZone.sameIP(actualIP, zone.exitIP) else {
                        throw BrowserError.invalid("Exit IP changed after lookup")
                    }
                    let value = try await tab.webView.callAsyncJavaScript(#"""
                    const d = new Date('2026-01-15T12:00:00Z');
                    const code = "const d=new Date('2026-01-15T12:00:00Z');postMessage({workerZone:Intl.DateTimeFormat().resolvedOptions().timeZone,workerOffset:d.getTimezoneOffset()})";
                    const url=URL.createObjectURL(new Blob([code],{type:'text/javascript'}));
                    return await new Promise((resolve,reject)=>{
                      const w=new Worker(url), timer=setTimeout(()=>{w.terminate();URL.revokeObjectURL(url);reject(new Error('Worker timeout'))},10000);
                      w.onmessage=e=>{clearTimeout(timer);w.terminate();URL.revokeObjectURL(url);resolve({zone:Intl.DateTimeFormat().resolvedOptions().timeZone,expectedCanonical:Intl.DateTimeFormat('en-US',{timeZone:expectedZone}).resolvedOptions().timeZone,offset:d.getTimezoneOffset(),...e.data})};
                      w.onerror=()=>{clearTimeout(timer);w.terminate();URL.revokeObjectURL(url);reject(new Error('Worker failed'))};
                    });
                    """#, arguments: ["expectedZone": zone.identifier], in: nil, contentWorld: .page)
                    guard let context = value as? [String: Any],
                          let canonical = context["expectedCanonical"] as? String,
                          context["zone"] as? String == canonical,
                          context["workerZone"] as? String == canonical,
                          let date = ISO8601DateFormatter().date(from: "2026-01-15T12:00:00Z"),
                          let timezone = TimeZone(identifier: zone.identifier),
                          context["offset"] as? Int == -timezone.secondsFromGMT(for: date) / 60,
                          context["workerOffset"] as? Int == context["offset"] as? Int else {
                        throw BrowserError.invalid("Native page or Worker timezone mismatch")
                    }
                    rows.append(["route": proxyID == nil ? "direct" : "proxy", "exitIP": actualIP,
                        "resolvedTimeZone": zone.identifier, "context": context, "dataStoreID": profile.dataStoreID.uuidString,
                        "passed": true]); save()
                } catch { session.close(); await DeviceBrowserPresentation.hide(); throw error }
                session.close(); await DeviceBrowserPresentation.hide()
                await CookieService.clear(session.dataStore)
            }
            guard beforeProfiles == store.profiles, beforeProxies == store.proxies,
                  ledger == store.database.fingerprintLedger else {
                throw BrowserError.invalid("Timezone QA changed saved profiles/proxies/ledger")
            }
            report["savedConfigurationUnchanged"] = true
            report["completed"] = true; report["status"] = "finished"
        } catch { report["status"] = "error"; report["error"] = error.localizedDescription }
        await DeviceBrowserPresentation.hide(); save()
    }
    #endif
}
