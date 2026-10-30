import Foundation

@MainActor
enum DeviceAutomaticCreationDiagnostics {
    private static var started = false
    static func startIfRequested(store: ProfileStore, workspace: BrowserWorkspace) {
        #if DEBUG
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let input = documents.appendingPathComponent("Lekapro-automatic-request.json")
        guard !started, FileManager.default.fileExists(atPath: input.path) else { return }
        started = true
        Task { await run(input: input, store: store, workspace: workspace) }
        #endif
    }
    #if DEBUG
    private struct Request: Decodable { let proxyID: UUID; let useCookiePool: Bool? }
    private static func run(input: URL, store: ProfileStore, workspace: BrowserWorkspace) async {
        let output = input.deletingLastPathComponent().appendingPathComponent("Lekapro-automatic-report.json")
        var report: [String: Any] = ["completed": false, "status": "running",
            "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"]
        func save() {
            if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
                try? data.write(to: output, options: [.atomic, .completeFileProtectionUnlessOpen])
            }
        }
        save()
        do {
            let request = try JSONDecoder().decode(Request.self, from: Data(contentsOf: input))
            let cookieSeed = request.useCookiePool == true ? CookiePoolStore.shared.configuration : nil
            guard request.useCookiePool != true || (CookiePoolStore.shared.loadError == nil && cookieSeed != nil) else {
                throw BrowserError.invalid("Cookie pool must be imported and enabled before cookie QA.")
            }
            guard let proxy = store.proxy(request.proxyID) else { throw BrowserError.invalid("Missing QA proxy") }
            let password = try SecretStore.password(for: proxy.id) ?? ""
            let host = proxy.host.contains(":") ? "[\(proxy.host)]" : proxy.host
            let inputs = try ProxyPaste.parse("\(host):\(proxy.port):\(proxy.username):\(password)", kind: proxy.kind)
            let beforeProfiles = store.profiles, beforeProxies = store.proxies
            let ledger = store.database.fingerprintLedger ?? []
            try FileManager.default.removeItem(at: input)
            let creator = AutomaticProfileCreator()
            try await DeviceBrowserPresentation.showAutomatic(creator, store: store, workspace: workspace)
            await creator.run(inputs: inputs, store: store, workspace: workspace, cookieSeed: cookieSeed)
            report["cookiePoolRequested"] = request.useCookiePool == true
            report["events"] = creator.diagnosticEvents
            report["attempts"] = creator.results.first?.attempts
            report["approved"] = creator.approvedCount; report["duplicatesDeleted"] = creator.duplicateCount
            report["terminalState"] = creator.results.first.map { String(describing: $0.state) }
            report["profileID"] = creator.results.first?.profileID?.uuidString
            report["ledgerBefore"] = ledger.count; report["ledgerAfter"] = store.database.fingerprintLedger?.count ?? 0
            guard creator.finished, !creator.busy, creator.results.count == 1,
                  let row = creator.results.first, [.approved, .exhausted].contains(row.state),
                  beforeProfiles.allSatisfy({ store.profile($0.id) == $0 }), beforeProxies == store.proxies,
                  ledger.allSatisfy({ (store.database.fingerprintLedger ?? []).contains($0) }) else {
                throw BrowserError.invalid("Automatic creation incomplete or saved configuration changed")
            }
            report["attempts"] = row.attempts; report["approved"] = creator.approvedCount
            report["duplicatesDeleted"] = creator.duplicateCount
            report["events"] = creator.diagnosticEvents
            report["profileID"] = row.profileID?.uuidString
            report["oldProfilesProxiesAndLedgerPreserved"] = true
            report["ledgerBefore"] = ledger.count; report["ledgerAfter"] = store.database.fingerprintLedger?.count ?? 0
            report["profileCountBefore"] = beforeProfiles.count; report["profileCountAfter"] = store.profiles.count
            report["completed"] = true; report["status"] = "finished"
        } catch { report["status"] = "error"; report["error"] = error.localizedDescription }
        await DeviceBrowserPresentation.hide(); save()
    }
    #endif
}
