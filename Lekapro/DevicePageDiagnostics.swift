import Foundation
import UIKit
import WebKit

// DEBUG-only, one-shot QA of the real page in the normal browser UI.
// Reads rendered DOM and captures WebKit snapshots; never changes page results.
@MainActor
enum DevicePageDiagnostics {
    private struct Request: Decodable { var profileIDs: [UUID] }
    private static var task: Task<Void, Never>?

    static func startIfRequested(store: ProfileStore, workspace: BrowserWorkspace) {
        #if DEBUG
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let input = folder.appendingPathComponent("Lekapro-page-request.json")
        guard task == nil, FileManager.default.fileExists(atPath: input.path) else { return }
        task = Task { await run(input: input, folder: folder, store: store, workspace: workspace) }
        #endif
    }

    private static func run(input: URL, folder: URL, store: ProfileStore, workspace: BrowserWorkspace) async {
        let output = folder.appendingPathComponent("Lekapro-fingerprint-check.json")
        let evidence = folder.appendingPathComponent("Lekapro-fingerprint-evidence", isDirectory: true)
        var result: [String: Any] = ["completed": false, "status": "running",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "url": "https://fingerprint.com/demo/",
            "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"]
        var observations: [[String: Any]] = []
        func save() {
            result["profiles"] = observations
            if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) {
                try? data.write(to: output, options: [.atomic, .completeFileProtectionUnlessOpen])
            }
        }
        save()
        do {
            defer { try? FileManager.default.removeItem(at: input) }
            let data = try Data(contentsOf: input)
            guard data.count < 8192 else { throw BrowserError.invalid("Page test request is too large.") }
            let request = try JSONDecoder().decode(Request.self, from: data)
            guard request.profileIDs.count == 2, Set(request.profileIDs).count == 2 else {
                throw BrowserError.invalid("Select exactly two different existing profiles.")
            }
            try FileManager.default.removeItem(at: input)
            try FileManager.default.createDirectory(at: evidence, withIntermediateDirectories: true)
            for (index, id) in request.profileIDs.enumerated() {
                guard let profile = store.profile(id) else { throw BrowserError.invalid("Test profile was not found.") }
                let session = try workspace.session(for: profile, store: store)
                await session.start()
                guard let tab = session.selectedTab else { throw BrowserError.invalid("No browser tab was created.") }
                if workspace.diagnosticSession != nil {
                    workspace.diagnosticSession = nil
                    try await Task.sleep(for: .milliseconds(700))
                }
                workspace.diagnosticSession = session
                let deadline = Date().addingTimeInterval(15)
                while tab.webView.window == nil || tab.webView.bounds.width < 100 {
                    guard Date() < deadline else { throw BrowserError.invalid("Browser view was not presented.") }
                    try await Task.sleep(for: .milliseconds(100))
                }
                tab.navigate(URL(string: "https://fingerprint.com/demo/")!)
                let first = try await observe(tab: tab, previousOrigin: nil,
                    prefix: "profile-\(index)-initial", evidence: evidence)
                observations.append(["profileID": id.uuidString, "profileName": profile.name,
                    "usesProxy": profile.proxyID != nil, "initial": first])
                save()
                guard let origin = first["timeOrigin"] as? Double,
                      let visitorID = first["visitorID"] as? String else {
                    throw BrowserError.invalid("Visitor ID was not visible in the demo. See saved page evidence.")
                }
                tab.webView.reloadFromOrigin()
                let reloaded = try await observe(tab: tab, previousOrigin: origin,
                    prefix: "profile-\(index)-reload", evidence: evidence)
                observations[index]["reload"] = reloaded
                guard let reloadedID = reloaded["visitorID"] as? String else {
                    save(); throw BrowserError.invalid("No Visitor ID was visible after reload. See saved page evidence.")
                }
                observations[index]["stableOnReload"] = reloadedID == visitorID
                session.persist(); save()
            }
            let ids = observations.compactMap { ($0["initial"] as? [String: Any])?["visitorID"] as? String }
            result["differentVisitorIDs"] = ids.count == 2 && ids[0] != ids[1]
            result["completed"] = true; result["status"] = "finished"
        } catch {
            result["status"] = "error"; result["error"] = error.localizedDescription
        }
        save()
    }

    private static let readPage = #"""
    (() => {
      const text = document.body?.innerText ?? '';
      const candidates = [];
      const patterns = [
        /"visitorId"\s*:\s*"([a-zA-Z0-9]{16,64})"/g,
        /Your Device['’]s Visitor ID\s*\n\s*([a-zA-Z0-9]{16,64})/gi,
        /(?:Your Unique Visitor ID|VISITOR ID:)\s*\n?\s*([a-zA-Z0-9]{16,64})/gi
      ];
      for (const pattern of patterns) for (const match of text.matchAll(pattern)) candidates.push(match[1]);
      const ids = [...new Set(candidates)];
      const id = ids.length === 1 ? ids[0] : null;
      const node = id ? [...document.querySelectorAll('body *')].find(el =>
        el.childElementCount === 0 && el.textContent.trim() === id && el.getBoundingClientRect().height > 0) : null;
      return {bodyText: text, visitorID: id, candidates: ids,
        timeOrigin: performance.timeOrigin, url: location.href, title: document.title,
        viewportWidth: innerWidth, viewportHeight: innerHeight,
        visitorY: node ? node.getBoundingClientRect().top + scrollY : 0};
    })()
    """#

    private static func observe(tab: BrowserTab, previousOrigin: Double?, prefix: String, evidence: URL) async throws -> [String: Any] {
        let end = Date().addingTimeInterval(75)
        var last: [String: Any] = [:]
        while Date() < end {
            if let error = tab.navigationError { throw error }
            if !tab.webView.isLoading, tab.webView.url?.host == "fingerprint.com",
               let page = try await tab.webView.evaluateJavaScript(readPage) as? [String: Any],
               let origin = page["timeOrigin"] as? Double, previousOrigin == nil || previousOrigin != origin {
                last = page
                if page["visitorID"] is String { break }
            }
            try await Task.sleep(for: .milliseconds(500))
        }
        let body = last.removeValue(forKey: "bodyText") as? String ?? ""
        try body.write(to: evidence.appendingPathComponent(prefix + ".txt"), atomically: true, encoding: .utf8)
        if let y = last["visitorY"] as? Double, y > 0 {
            let limit = max(0, tab.webView.scrollView.contentSize.height - tab.webView.bounds.height)
            tab.webView.scrollView.setContentOffset(CGPoint(x: 0, y: min(limit, max(0, y - 120))), animated: false)
            try await Task.sleep(for: .milliseconds(400))
        }
        let snapshot = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UIImage, Error>) in
            tab.webView.takeSnapshot(with: nil) { image, error in
                if let image { continuation.resume(returning: image) }
                else { continuation.resume(throwing: error ?? BrowserError.invalid("No WebKit snapshot was returned.")) }
            }
        }
        try snapshot.pngData()?.write(to: evidence.appendingPathComponent(prefix + ".png"), options: .atomic)
        last["evidencePrefix"] = prefix
        last["webViewWidth"] = tab.webView.bounds.width
        last["webViewHeight"] = tab.webView.bounds.height
        return last
    }
}
