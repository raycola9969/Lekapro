import Foundation
import UIKit
import WebKit

// DEBUG-only, one-shot QA of the real page in the normal browser UI.
// Reads rendered DOM and captures WebKit snapshots; never changes page results.
@MainActor
enum DevicePageDiagnostics {
    private struct Request: Decodable {
        var profileIDs: [UUID]
        var engineOptionsByProfileID: [String: DiagnosticEngineOptions]?
        var stateResetByProfileID: [String: DiagnosticSiteState.Reset]?
        var restartNetworkAfterStateResetProfileIDs: [UUID]?
        var customStateResetDataTypesByProfileID: [String: [String]]?
        var identityStateCopy: DiagnosticSiteState.CopyRequest?
    }
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
        let wasIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
        defer {
            UIApplication.shared.isIdleTimerDisabled = wasIdleTimerDisabled
            DiagnosticEngineRegistry.clear()
        }
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
            var experiments: [UUID: DiagnosticEngineOptions] = [:]
            var resets: [UUID: DiagnosticSiteState.Reset] = [:]
            for (key, action) in request.stateResetByProfileID ?? [:] {
                guard let id = UUID(uuidString: key), request.profileIDs.contains(id), let profile = store.profile(id) else {
                    throw BrowserError.invalid("State resets must name one of the two requested QA profiles.")
                }
                try DiagnosticSiteState.validateTarget(profile)
                resets[id] = action
            }
            let networkRestarts = Set(request.restartNetworkAfterStateResetProfileIDs ?? [])
            guard networkRestarts.allSatisfy({ request.profileIDs.contains($0) && resets[$0] != nil }) else {
                throw BrowserError.invalid("Network restarts require a selected disposable state-reset target.")
            }
            var customTypes: [UUID: Set<String>] = [:]
            for (key, values) in request.customStateResetDataTypesByProfileID ?? [:] {
                guard let id = UUID(uuidString: key), resets[id] == .customTypes, values.count <= 64 else {
                    throw BrowserError.invalid("Custom data types require a selected disposable custom-reset target.")
                }
                customTypes[id] = Set(values)
            }
            for (id, action) in resets { _ = try DiagnosticSiteState.selectedTypes(action, custom: customTypes[id]) }
            for (key, options) in request.engineOptionsByProfileID ?? [:] {
                guard let id = UUID(uuidString: key), request.profileIDs.contains(id) else {
                    throw BrowserError.invalid("Engine options must name one of the two requested QA profiles.")
                }
                try options.validate()
                experiments[id] = options
            }
            if let copy = request.identityStateCopy {
                guard resets.isEmpty, experiments.isEmpty,
                      request.profileIDs.contains(copy.sourceProfileID), request.profileIDs.contains(copy.targetProfileID),
                      let source = store.profile(copy.sourceProfileID), let target = store.profile(copy.targetProfileID) else {
                    throw BrowserError.invalid("Token copy must be the only intervention on the requested QA pair.")
                }
                try DiagnosticSiteState.validateCopy(copy, source: source, target: target)
            }
            DiagnosticEngineRegistry.set(experiments)
            if !experiments.isEmpty { result["nativeEngineExperimentsRequested"] = true }
            try FileManager.default.removeItem(at: input)
            try FileManager.default.createDirectory(at: evidence, withIntermediateDirectories: true)
            if let copy = request.identityStateCopy, let source = store.profile(copy.sourceProfileID),
               let target = store.profile(copy.targetProfileID) {
                let sourceSession = try workspace.session(for: source, store: store)
                let targetSession = try workspace.session(for: target, store: store)
                result["identityStateCopy"] = try await DiagnosticSiteState.copy(copy, source: source, target: target,
                    sourceStore: sourceSession.dataStore, targetStore: targetSession.dataStore)
                save()
            }
            for (index, id) in request.profileIDs.enumerated() {
                guard let profile = store.profile(id) else { throw BrowserError.invalid("Test profile was not found.") }
                let session = try workspace.session(for: profile, store: store)
                if let action = resets[id] {
                    let reset = try await DiagnosticSiteState.reset(action, profile: profile, store: session.dataStore,
                        restartNetwork: networkRestarts.contains(id), customDataTypes: customTypes[id])
                    var applied = result["siteStateResets"] as? [[String: Any]] ?? []
                    applied.append(reset); result["siteStateResets"] = applied; save()
                }
                if request.identityStateCopy != nil {
                    try DiagnosticSiteState.validateTarget(profile)
                    let state = try await DiagnosticSiteState.snapshot(store: session.dataStore, requireNativeRecords: true)
                    var before = result["beforeProfileNavigations"] as? [[String: Any]] ?? []
                    before.append(["profileID": id.uuidString, "navigationIndex": index, "state": state])
                    result["beforeProfileNavigations"] = before; save()
                }
                await session.start()
                guard let tab = session.selectedTab else { throw BrowserError.invalid("No browser tab was created.") }
                try await DeviceBrowserPresentation.show(session, store: store, workspace: workspace)
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
        await DeviceBrowserPresentation.hide()
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
      function responseAfter(label) {
        const at = text.toUpperCase().indexOf(label);
        if (at < 0) return null;
        const start = text.indexOf('{', at + label.length);
        if (start < 0) return null;
        let depth = 0, quoted = false, escaped = false;
        for (let i = start; i < text.length; i++) {
          const ch = text[i];
          if (quoted) {
            if (escaped) escaped = false;
            else if (ch === '\\') escaped = true;
            else if (ch === '"') quoted = false;
          } else if (ch === '"') quoted = true;
          else if (ch === '{') depth++;
          else if (ch === '}' && --depth === 0) {
            try { return JSON.parse(text.slice(start, i + 1)); } catch (_) { return null; }
          }
        }
        return null;
      }
      const agent = responseAfter('JAVASCRIPT AGENT RESPONSE');
      const server = responseAfter('SERVER API RESPONSE');
      const agentID = agent?.visitor_id ?? agent?.visitorId;
      const serverID = server?.identification?.visitor_id ?? server?.products?.identification?.data?.visitorId;
      const agentEvent = agent?.event_id ?? agent?.requestId;
      const serverEvent = server?.event_id ?? server?.requestId;
      const node = id ? [...document.querySelectorAll('body *')].find(el =>
        el.childElementCount === 0 && el.textContent.trim() === id && el.getBoundingClientRect().height > 0) : null;
      return {bodyText: text, visitorID: id, candidates: ids,
        agentResponse: agent, serverResponse: server,
        serverReady: !!(id && agentID === id && serverID === id && agentEvent && agentEvent === serverEvent),
        javascriptUserAgent: navigator.userAgent,
        javascriptContext: {timeZone:Intl.DateTimeFormat().resolvedOptions().timeZone,
          platform:navigator.platform,webAudioAvailable:typeof OfflineAudioContext === 'function' || typeof webkitOfflineAudioContext === 'function',
          offset:new Date('2026-01-15T12:00:00Z').getTimezoneOffset(),
          hour:new Date('2026-01-15T12:00:00Z').getHours(),
          locale:Intl.DateTimeFormat().resolvedOptions().locale,language:navigator.language,
          hardwareConcurrency:navigator.hardwareConcurrency,screen:[screen.width,screen.height]},
        timeOrigin: performance.timeOrigin, url: location.href, title: document.title,
        viewportWidth: innerWidth, viewportHeight: innerHeight,
        visitorY: node ? node.getBoundingClientRect().top + scrollY : 0};
    })()
    """#

    static func observe(tab: BrowserTab, previousOrigin: Double?, prefix: String, evidence: URL) async throws -> [String: Any] {
        let end = Date().addingTimeInterval(75)
        var last: [String: Any] = [:]
        while Date() < end {
            if let error = tab.navigationError { throw error }
            if !tab.webView.isLoading, tab.webView.url?.host == "fingerprint.com",
               let page = try await tab.webView.evaluateJavaScript(readPage) as? [String: Any],
               let origin = page["timeOrigin"] as? Double, previousOrigin == nil || previousOrigin != origin {
                last = page
                if page["serverReady"] as? Bool == true { break }
            }
            try await Task.sleep(for: .milliseconds(500))
        }
        let body = last.removeValue(forKey: "bodyText") as? String ?? ""
        do {
            last["siteStorageKeyNames"] = try await tab.webView.evaluateJavaScript("""
            ({localStorage:Object.keys(localStorage).sort(),sessionStorage:Object.keys(sessionStorage).sort(),
              scriptVisibleCookieNames:document.cookie.split(';').map(x=>x.split('=')[0].trim()).filter(Boolean).sort()})
            """)
        } catch { last["siteStorageKeyNamesError"] = (error as NSError).code }
        do {
            last["storageContext"] = try await tab.webView.callAsyncJavaScript("""
            return {secureContext:isSecureContext, estimateSupported:typeof navigator.storage?.estimate === 'function',
              estimate:typeof navigator.storage?.estimate === 'function' ? await navigator.storage.estimate() : null};
            """, arguments: [:], in: nil, contentWorld: .page)
        } catch { last["storageContextError"] = (error as NSError).code }
        do {
            last["workerContext"] = try await tab.webView.callAsyncJavaScript(#"""
            return await new Promise(resolve => {
              let worker, url;
              const finish = value => { clearTimeout(timer); worker?.terminate(); if (url) URL.revokeObjectURL(url); resolve(value); };
              const timer = setTimeout(() => finish({error:'Worker timed out'}), 3000);
              try {
                const code = "const d=new Date('2026-01-15T12:00:00Z');postMessage({timeZone:Intl.DateTimeFormat().resolvedOptions().timeZone,offset:d.getTimezoneOffset(),hour:d.getHours(),language:navigator.language,userAgent:navigator.userAgent,hardwareConcurrency:navigator.hardwareConcurrency})";
                url = URL.createObjectURL(new Blob([code], {type:'text/javascript'}));
                worker = new Worker(url);
                worker.onmessage = event => finish(event.data);
                worker.onerror = event => finish({error:String(event.message)});
              } catch (error) { finish({error:String(error)}); }
            });
            """#, arguments: [:], in: nil, contentWorld: .page)
        } catch { last["workerContextError"] = error.localizedDescription }
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
