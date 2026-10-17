import Foundation
import UIKit
import WebKit

// One-shot DEBUG QA requested through a file inside this app's Documents.
// Uses normal BrowserSession / BrowserView, with no page or fingerprint overrides.
@MainActor
enum DeviceUserAgentDiagnostics {
    private struct Request: Decodable { var profileIDs: [UUID] }
    private static var task: Task<Void, Never>?

    static func startIfRequested(store: ProfileStore, workspace: BrowserWorkspace) {
        #if DEBUG
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let input = folder.appendingPathComponent("Lekapro-ua-request.json")
        guard task == nil, FileManager.default.fileExists(atPath: input.path) else { return }
        task = Task { await run(input: input, folder: folder, store: store, workspace: workspace) }
        #endif
    }

    private static func run(input: URL, folder: URL, store: ProfileStore, workspace: BrowserWorkspace) async {
        let wasIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
        defer { UIApplication.shared.isIdleTimerDisabled = wasIdleTimerDisabled }
        let output = folder.appendingPathComponent("Lekapro-ua-check.json")
        let evidence = folder.appendingPathComponent("Lekapro-ua-evidence", isDirectory: true)
        var result: [String: Any] = ["completed": false, "status": "running",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "actualOSVersion": UIDevice.current.systemVersion,
            "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            "url": "https://fingerprint.com/demo/", "proxyEnabled": false,
            "canvasOrAudioOverrides": false]
        var phases: [[String: Any]] = []
        func save() {
            result["phases"] = phases
            if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) {
                try? data.write(to: output, options: [.atomic, .completeFileProtectionUnlessOpen])
            }
        }
        save()
        do {
            defer { try? FileManager.default.removeItem(at: input) }
            let data = try Data(contentsOf: input)
            guard data.count < 8192 else { throw BrowserError.invalid("UA test request is too large.") }
            let request = try JSONDecoder().decode(Request.self, from: data)
            guard request.profileIDs.count == 2, Set(request.profileIDs).count == 2 else {
                throw BrowserError.invalid("UA test requires two different dedicated profile IDs.")
            }
            try FileManager.default.removeItem(at: input)
            try FileManager.default.createDirectory(at: evidence, withIntermediateDirectories: true)
            for (index, id) in request.profileIDs.enumerated() {
                if let existing = store.profile(id) {
                    guard existing.tags == "qa-user-agent", existing.proxyID == nil else {
                        throw BrowserError.invalid("UA test cannot modify an unrelated profile.")
                    }
                } else {
                    var profile = BrowserProfile()
                    profile.id = id; profile.name = "QA User-Agent \(index == 0 ? "A" : "B")"
                    profile.tags = "qa-user-agent"
                    profile.homeURL = "https://fingerprint.com/demo/"
                    profile.privacy.blockTrackers = false
                    try store.save(profile)
                }
            }
            let experiments: [(String, [UserAgentPreset])] = [
                ("baseline", [.ios1879, .ios1879]),
                ("different-UA", [.ios172, .ios1879]),
                ("restore-UA", [.ios1879, .ios1879])
            ]
            for (phaseIndex, experiment) in experiments.enumerated() {
                phases.append(["name": experiment.0, "observations": [[String: Any]]()]); save()
                for (index, id) in request.profileIDs.enumerated() {
                    await DeviceBrowserPresentation.hide()
                    workspace.close(id)
                    guard var profile = store.profile(id) else { throw BrowserError.invalid("QA profile disappeared.") }
                    guard profile.proxyID == nil, !profile.desktopMode,
                          !profile.privacy.blockTrackers, !profile.privacy.blockCanvasReadback,
                          !profile.privacy.blockAudioReadback, !profile.privacy.blockWebRTC else {
                        throw BrowserError.invalid("QA profile settings changed outside the UA experiment.")
                    }
                    profile.userAgent = experiment.1[index].value
                    let blank = SavedTab(url: "about:blank", title: "UA experiment")
                    profile.tabs = [blank]; profile.selectedTabID = blank.id
                    try store.save(profile)
                    let session = try workspace.session(for: profile, store: store)
                    await session.start()
                    guard let tab = session.selectedTab else { throw BrowserError.invalid("QA browser tab was not created.") }
                    try await DeviceBrowserPresentation.show(session, store: store, workspace: workspace)
                    let deadline = Date().addingTimeInterval(15)
                    while tab.webView.window == nil || tab.webView.bounds.width < 100 {
                        guard Date() < deadline else { throw BrowserError.invalid("QA browser was not presented.") }
                        try await Task.sleep(for: .milliseconds(100))
                    }
                    tab.navigate(URL(string: "https://fingerprint.com/demo/")!)
                    let prefix = "phase-\(phaseIndex)-profile-\(index)"
                    let first = try await DevicePageDiagnostics.observe(tab: tab, previousOrigin: nil,
                        prefix: prefix + "-initial", evidence: evidence)
                    var observations = phases[phaseIndex]["observations"] as? [[String: Any]] ?? []
                    observations.append(["profileID": id.uuidString, "dataStoreID": profile.dataStoreID.uuidString,
                        "configuredUserAgent": profile.userAgent ?? "", "initial": first])
                    phases[phaseIndex]["observations"] = observations; save()
                    guard first["serverReady"] as? Bool == true,
                          first["javascriptUserAgent"] as? String == profile.userAgent,
                          let firstID = first["visitorID"] as? String,
                          let origin = first["timeOrigin"] as? Double else {
                        throw BrowserError.invalid("UA or Fingerprint server response was not verified. See saved evidence.")
                    }
                    tab.webView.reloadFromOrigin()
                    let reloaded = try await DevicePageDiagnostics.observe(tab: tab, previousOrigin: origin,
                        prefix: prefix + "-reload", evidence: evidence)
                    observations[index]["reload"] = reloaded
                    observations[index]["stableOnReload"] = reloaded["visitorID"] as? String == firstID
                    phases[phaseIndex]["observations"] = observations; save()
                    guard reloaded["serverReady"] as? Bool == true,
                          reloaded["javascriptUserAgent"] as? String == profile.userAgent else {
                        throw BrowserError.invalid("Reload did not return a matching UA and Fingerprint response.")
                    }
                    session.persist()
                }
            }
            result["completed"] = true; result["status"] = "finished"
        } catch {
            result["status"] = "error"; result["error"] = error.localizedDescription
        }
        await DeviceBrowserPresentation.hide()
        save()
    }
}
