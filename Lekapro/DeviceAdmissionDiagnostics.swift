import Foundation

// One-shot own-device QA invokes the production review screen, parser, ledger
// and deletion path. It cannot target old/approved or unguarded profiles.
@MainActor
enum DeviceAdmissionDiagnostics {
    private static var started = false
    static func startIfRequested(store: ProfileStore, workspace: BrowserWorkspace) {
        #if DEBUG
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let input = documents.appendingPathComponent("Lekapro-admission-request.json")
        guard !started, FileManager.default.fileExists(atPath: input.path) else { return }
        started = true
        Task { await run(input: input, store: store, workspace: workspace) }
        #endif
    }

    #if DEBUG
    private struct Request: Decodable { let profileIDs: [UUID] }
    private static func run(input: URL, store: ProfileStore, workspace: BrowserWorkspace) async {
        let output = input.deletingLastPathComponent().appendingPathComponent("Lekapro-admission-report.json")
        var report: [String: Any] = ["completed": false, "status": "running",
            "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"]
        var results: [[String: Any]] = []
        func save() {
            report["profiles"] = results
            if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
                try? data.write(to: output, options: [.atomic, .completeFileProtectionUnlessOpen])
            }
        }
        save()
        do {
            let request = try JSONDecoder().decode(Request.self, from: Data(contentsOf: input))
            guard request.profileIDs.count == 2, Set(request.profileIDs).count == 2 else {
                throw BrowserError.invalid("Admission QA requires exactly two different new candidates.")
            }
            for id in request.profileIDs {
                guard let profile = store.profile(id), let check = profile.fingerprintCheck,
                      check.state == .pending, check.canAutoDelete,
                      profile.tags == "qa-admission-candidate" else {
                    throw BrowserError.invalid("Admission QA cannot change an existing or approved profile.")
                }
            }
            let protected = store.profiles.filter { !request.profileIDs.contains($0.id) }
            let proxies = store.proxies
            report["protectedProfileCount"] = protected.count
            report["initialLedgerCount"] = store.database.fingerprintLedger?.count ?? 0
            try FileManager.default.removeItem(at: input)
            for id in request.profileIDs {
                let review = FingerprintReviewController()
                try await DeviceBrowserPresentation.showReview(review, profileID: id, store: store, workspace: workspace)
                let deadline = Date().addingTimeInterval(240)
                while !review.didStart || review.busy {
                    if Date() >= deadline { review.close(); throw BrowserError.invalid("Admission QA timed out.") }
                    try await Task.sleep(for: .milliseconds(200))
                }
                var row: [String: Any] = ["profileID": id.uuidString, "approved": review.approved,
                    "deleted": review.deleted, "message": review.message,
                    "profilePresent": store.profile(id) != nil]
                if let state = store.profile(id)?.fingerprintCheck?.state { row["state"] = state.rawValue }
                if let proof = review.diagnosticProof {
                    row["visitorID"] = proof.first.visitorID
                    row["reloadVisitorID"] = proof.reload.visitorID
                    row["eventID"] = proof.first.eventID; row["reloadEventID"] = proof.reload.eventID
                    row["environmentID"] = proof.first.environmentID
                    row["exitIP"] = proof.first.exitIP; row["reloadExitIP"] = proof.reload.exitIP
                    row["userAgent"] = proof.first.userAgent
                    row["firstTimeOrigin"] = proof.first.timeOrigin; row["reloadTimeOrigin"] = proof.reload.timeOrigin
                    row["configurationDigest"] = proof.configurationDigest
                }
                results.append(row); save()
                await DeviceBrowserPresentation.hide()
            }
            guard proxies == store.proxies,
                  protected.allSatisfy({ store.profile($0.id) == $0 }) else {
                throw BrowserError.invalid("An unrelated profile or proxy changed during admission QA.")
            }
            report["protectedProfilesAndProxiesUnchanged"] = true
            report["finalLedgerCount"] = store.database.fingerprintLedger?.count ?? 0
            report["completed"] = true; report["status"] = "finished"
        } catch {
            report["status"] = "error"; report["error"] = error.localizedDescription
        }
        await DeviceBrowserPresentation.hide()
        save()
    }
    #endif
}
