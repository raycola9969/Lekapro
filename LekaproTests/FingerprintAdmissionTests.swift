import XCTest
import WebKit
@testable import Lekapro

@MainActor
final class FingerprintAdmissionTests: XCTestCase {
    private let visitor = "AAAAAAAAAAAAAAAAAAAA"
    private let otherVisitor = "BBBBBBBBBBBBBBBBBBBB"
    private func file() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("profiles.json")
    }
    private func candidate(in store: ProfileStore) throws -> BrowserProfile {
        var profile = BrowserProfile(); profile.privacy.blockTrackers = false
        profile.fingerprintCheck = .newCandidate
        try store.save(profile)
        return try XCTUnwrap(store.profile(profile.id))
    }
    private func page(visitor: String, event: String, origin: Double, environment: String = "fixture-environment",
                      ua: String = "Fixture UA") -> [String: Any] {
        ["visitorID": visitor, "url": "https://fingerprint.com/demo/", "timeOrigin": origin,
         "javascriptUserAgent": ua,
         "agentResponse": ["visitor_id": visitor, "event_id": event, "cache_hit": false],
         "serverResponse": ["identification": ["visitor_id": visitor, "visitor_found": true],
                            "event_id": event, "environment_id": environment, "ip_address": "192.0.2.1",
                            "user_agent": ua, "url": "https://fingerprint.com/demo/"]]
    }
    private func observation(visitor: String, event: String, origin: Double,
                             environment: String = "fixture-environment", ua: String = "Fixture UA") throws -> FingerprintObservation {
        try FingerprintObservation(page: page(visitor: visitor, event: event, origin: origin, environment: environment, ua: ua),
            actualURL: URL(string: "https://fingerprint.com/demo/")!)
    }
    private func proof(_ profile: BrowserProfile, store: ProfileStore, visitor: String? = nil,
                       environment: String = "fixture-environment") throws -> FingerprintProof {
        let value = visitor ?? self.visitor, ua = profile.userAgent ?? "Fixture UA"
        return try FingerprintProof(
            first: observation(visitor: value, event: UUID().uuidString, origin: 1, environment: environment, ua: ua),
            reload: observation(visitor: value, event: UUID().uuidString, origin: 2, environment: environment, ua: ua),
            configurationDigest: FingerprintConfiguration.digest(profile, proxy: store.proxy(profile.proxyID)),
            checkedExitIP: "192.0.2.1")
    }

    func testTwoCandidatesCannotReserveTheSameID() throws {
        let store = ProfileStore(fileURL: file())
        let a = try candidate(in: store), b = try candidate(in: store)
        let first = try proof(a, store: store), second = try proof(b, store: store)
        XCTAssertEqual(try store.recordFingerprint(first, for: a.id), .approved)
        XCTAssertEqual(try store.recordFingerprint(second, for: b.id), .duplicate(autoDelete: true))
        XCTAssertEqual(store.database.fingerprintLedger?.count, 1)
        XCTAssertEqual(store.profile(a.id)?.fingerprintCheck?.state, .approved)
        XCTAssertEqual(store.profile(b.id)?.fingerprintCheck?.state, .duplicate)
        XCTAssertThrowsError(try BrowserWorkspace().session(for: b, store: store))
        XCTAssertThrowsError(try store.rejectedCandidate(a.id, configurationDigest: first.configurationDigest))
    }

    func testLedgerSurvivesProfileDeletionAndRelaunch() throws {
        let path = file(), store = ProfileStore(fileURL: path)
        let a = try candidate(in: store)
        XCTAssertEqual(try store.recordFingerprint(proof(a, store: store), for: a.id), .approved)
        try store.removeProfile(a.id)
        let reopened = ProfileStore(fileURL: path)
        XCTAssertFalse(reopened.isReadOnly)
        let b = try candidate(in: reopened)
        XCTAssertEqual(try reopened.recordFingerprint(proof(b, store: reopened), for: b.id), .duplicate(autoDelete: true))
        XCTAssertEqual(reopened.database.fingerprintLedger?.count, 1)
    }

    func testRecheckOfOwnIDIsAllowedAndExistingProfileNeverAutoDeletes() throws {
        let store = ProfileStore(fileURL: file()), a = try candidate(in: store)
        _ = try store.recordFingerprint(proof(a, store: store), for: a.id)
        try store.beginFingerprintReview(a.id)
        XCTAssertEqual(try store.recordFingerprint(proof(a, store: store), for: a.id), .approved)
        var old = BrowserProfile(); old.privacy.blockTrackers = false
        try store.save(old); try store.beginFingerprintReview(old.id)
        XCTAssertEqual(try store.recordFingerprint(proof(old, store: store), for: old.id), .duplicate(autoDelete: false))
        XCTAssertNotNil(store.profile(old.id))
        XCTAssertEqual(store.database.fingerprintLedger?.count, 1)
    }

    func testFailureBlocksBrowsingWithoutDeletingCandidateOrClaimingAnID() throws {
        let store = ProfileStore(fileURL: file()), a = try candidate(in: store)
        try store.recordFingerprintFailure(a.id, message: "Timed out")
        XCTAssertNotNil(store.profile(a.id))
        XCTAssertEqual(store.profile(a.id)?.fingerprintCheck?.state, .failed)
        XCTAssertTrue(store.database.fingerprintLedger?.isEmpty ?? true)
        XCTAssertThrowsError(try BrowserWorkspace().session(for: a, store: store))
        try store.beginFingerprintReview(a.id)
        XCTAssertEqual(try store.recordFingerprint(proof(a, store: store), for: a.id), .approved)
    }

    func testFailedDiskWriteCannotApproveOrReserveAnID() throws {
        let path = file(), store = ProfileStore(fileURL: path), a = try candidate(in: store)
        let saved = try Data(contentsOf: path)
        try FileManager.default.removeItem(at: path)
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: false)
        defer {
            try? FileManager.default.removeItem(at: path)
            try? saved.write(to: path)
        }
        XCTAssertThrowsError(try store.recordFingerprint(proof(a, store: store), for: a.id))
        XCTAssertEqual(store.profile(a.id)?.fingerprintCheck?.state, .pending)
        XCTAssertTrue(store.database.fingerprintLedger?.isEmpty ?? true)
        XCTAssertNotNil(store.profile(a.id))
    }

    func testCancelAndRetryCannotRunTwoChecksOnTheSameProfile() async throws {
        let store = ProfileStore(fileURL: file()), workspace = BrowserWorkspace(), a = try candidate(in: store)
        let first = FingerprintReviewController(), second = FingerprintReviewController()
        let task = Task { await first.run(profileID: a.id, store: store, workspace: workspace) }
        let deadline = Date().addingTimeInterval(10)
        while first.session == nil && !task.isCancelled {
            guard Date() < deadline else {
                first.close(); task.cancel(); await task.value
                XCTFail("First review did not create its offline tab"); return
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        // Closing the screen must not release the per-profile lock before its
        // suspended work (including any deletion) has actually finished.
        first.close()
        await second.run(profileID: a.id, store: store, workspace: workspace)
        XCTAssertFalse(second.approved)
        XCTAssertNil(second.session)
        XCTAssertTrue(second.message.contains("lần kiểm tra trước"))
        task.cancel(); await task.value
        XCTAssertNotNil(store.profile(a.id))
        XCTAssertEqual(store.profile(a.id)?.fingerprintCheck?.state, .pending)
    }

    func testMetadataKeepsVerdictButUAAndStaleEvidenceInvalidateIt() throws {
        let store = ProfileStore(fileURL: file()), a = try candidate(in: store)
        let oldProof = try proof(a, store: store)
        _ = try store.recordFingerprint(oldProof, for: a.id)
        var edited = a; edited.name = "Renamed"; edited.history = [PageRecord(title: "Saved", url: "https://example.com")]
        try store.save(edited) // The stale editor's pending check must not overwrite approval.
        XCTAssertEqual(store.profile(a.id)?.fingerprintCheck?.state, .approved)
        edited.userAgent = UserAgentPreset.ios172.value
        try store.save(edited)
        XCTAssertEqual(store.profile(a.id)?.fingerprintCheck?.state, .pending)
        XCTAssertEqual(store.profile(a.id)?.fingerprintCheck?.canAutoDelete, false)
        XCTAssertThrowsError(try store.recordFingerprint(oldProof, for: a.id))
        let changed = try XCTUnwrap(store.profile(a.id))
        XCTAssertEqual(try store.recordFingerprint(proof(changed, store: store), for: a.id), .approved)
        XCTAssertEqual(store.profile(a.id)?.history, edited.history)
    }

    func testProxyPasswordChangeRequiresRecheckButRenameDoesNot() throws {
        let store = ProfileStore(fileURL: file())
        var proxy = ProxyRecord(); proxy.host = "127.0.0.1"
        defer { try? SecretStore.remove(proxy.id) }
        try store.saveProxy(proxy, password: "first")
        var a = BrowserProfile(); a.proxyID = proxy.id; a.fingerprintCheck = .newCandidate
        try store.save(a)
        _ = try store.recordFingerprint(proof(a, store: store), for: a.id)
        proxy.name = "Renamed proxy"
        try store.saveProxy(proxy, password: "first")
        XCTAssertEqual(store.profile(a.id)?.fingerprintCheck?.state, .approved)
        try store.saveProxy(proxy, password: "second")
        XCTAssertEqual(store.profile(a.id)?.fingerprintCheck?.state, .pending)
        XCTAssertEqual(store.profile(a.id)?.fingerprintCheck?.canAutoDelete, false)
    }

    func testChangedEnvironmentDoesNotAppearUnique() throws {
        let store = ProfileStore(fileURL: file()), a = try candidate(in: store)
        _ = try store.recordFingerprint(proof(a, store: store), for: a.id)
        let b = try candidate(in: store)
        XCTAssertThrowsError(try store.recordFingerprint(proof(b, store: store, visitor: otherVisitor, environment: "changed-environment"), for: b.id))
        XCTAssertEqual(store.profile(b.id)?.fingerprintCheck?.state, .pending)
        XCTAssertEqual(store.database.fingerprintLedger?.count, 1)
    }

    func testExportAndImportCannotTransferApprovalOrReplaceHistory() throws {
        let store = ProfileStore(fileURL: file()), a = try candidate(in: store)
        _ = try store.recordFingerprint(proof(a, store: store), for: a.id)
        let exported = try store.exportConfiguration()
        XCTAssertFalse(String(decoding: exported, as: UTF8.self).contains(visitor))
        // Even an imported full database cannot bring its receipts/approval.
        try store.importConfiguration(JSONEncoder().encode(store.database))
        XCTAssertEqual(store.database.fingerprintLedger?.count, 1)
        let copy = try XCTUnwrap(store.profiles.first { $0.id != a.id })
        XCTAssertEqual(copy.fingerprintCheck, .newCandidate)
        XCTAssertNotEqual(copy.dataStoreID, a.dataStoreID)
        XCTAssertEqual(try store.recordFingerprint(proof(copy, store: store), for: copy.id), .duplicate(autoDelete: true))
        let duplicated = try XCTUnwrap(store.profile(a.id)).duplicated()
        XCTAssertEqual(duplicated.fingerprintCheck, .newCandidate)
    }

    func testMalformedCachedAndMismatchedEvidenceNeverFormsProof() throws {
        let url = URL(string: "https://fingerprint.com/demo/")!
        var cached = page(visitor: visitor, event: "event-a", origin: 1)
        var agent = try XCTUnwrap(cached["agentResponse"] as? [String: Any]); agent["cache_hit"] = true
        cached["agentResponse"] = agent
        XCTAssertThrowsError(try FingerprintObservation(page: cached, actualURL: url))
        XCTAssertThrowsError(try FingerprintObservation(page: page(visitor: visitor, event: "event-a", origin: 1), actualURL: URL(string: "https://example.com/demo/")!))
        let first = try observation(visitor: visitor, event: "event-a", origin: 1)
        let sameEvent = try observation(visitor: visitor, event: "event-a", origin: 2)
        let differentID = try observation(visitor: otherVisitor, event: "event-b", origin: 2)
        let differentEnvironment = try observation(visitor: visitor, event: "event-b", origin: 2, environment: "other")
        for reload in [sameEvent, differentID, differentEnvironment] {
            XCTAssertThrowsError(try FingerprintProof(first: first, reload: reload, configurationDigest: "test", checkedExitIP: "192.0.2.1"))
        }
        XCTAssertThrowsError(try FingerprintProof(first: first,
            reload: observation(visitor: visitor, event: "event-b", origin: 2), configurationDigest: "test", checkedExitIP: "192.0.2.2"))
    }

    func testReviewSessionDoesNotRestoreOrOverwriteExistingTabsAndHistory() async throws {
        let store = ProfileStore(fileURL: file())
        var a = BrowserProfile(); a.privacy.blockTrackers = false; a.fingerprintCheck = .newCandidate
        a.tabs = [SavedTab(url: "https://example.com/saved", title: "Saved")]
        a.history = [PageRecord(title: "Saved history", url: "https://example.com/saved")]
        try store.save(a)
        let before = try XCTUnwrap(store.profile(a.id))
        XCTAssertThrowsError(try BrowserSession(profile: a, store: store))
        let session = try BrowserSession(profile: a, store: store, persistsBrowsingState: false)
        await session.start()
        XCTAssertEqual(session.tabs.count, 1)
        XCTAssertEqual(session.selectedTab?.url?.absoluteString, "about:blank")
        session.persist(); session.close()
        XCTAssertEqual(store.profile(a.id), before)
    }

    func testRejectedCandidateDeletionPreservesExistingCookieProfileAndLedger() async throws {
        let store = ProfileStore(fileURL: file()), workspace = BrowserWorkspace()
        let a = try candidate(in: store), b = try candidate(in: store)
        let acceptedProof = try proof(a, store: store), rejectedProof = try proof(b, store: store)
        _ = try store.recordFingerprint(acceptedProof, for: a.id)
        _ = try store.recordFingerprint(rejectedProof, for: b.id)
        let firstStore = try DataStoreFactory.make(id: a.dataStoreID)
        let rejectedStore = try DataStoreFactory.make(id: b.dataStoreID)
        defer { DataStoreFactory.release(id: a.dataStoreID); DataStoreFactory.release(id: b.dataStoreID) }
        for (value, dataStore) in [("keep", firstStore), ("remove", rejectedStore)] {
            let data = try JSONEncoder().encode([CookieRecord(name: "qa_admission", value: value, domain: "lekapro.invalid")])
            _ = try await CookieService.importData(data, into: dataStore)
        }
        let before = store.profile(a.id), ledger = store.database.fingerprintLedger
        try await workspace.deleteRejectedCandidate(b.id, configurationDigest: rejectedProof.configurationDigest, store: store)
        XCTAssertNil(store.profile(b.id))
        XCTAssertEqual(store.profile(a.id), before)
        XCTAssertEqual(store.database.fingerprintLedger, ledger)
        let kept = await CookieService.all(in: firstStore), removed = await CookieService.all(in: rejectedStore)
        XCTAssertTrue(kept.contains { $0.name == "qa_admission" && $0.value == "keep" })
        XCTAssertFalse(removed.contains { $0.name == "qa_admission" })
        do {
            try await workspace.deleteRejectedCandidate(a.id, configurationDigest: acceptedProof.configurationDigest, store: store)
            XCTFail("An accepted profile must never be automatically deleted")
        } catch {}
        XCTAssertNotNil(store.profile(a.id))
    }

    func testLegacyDatabaseLoadsWithoutMarkingOldProfilesAsVerified() throws {
        let path = file(), old = BrowserProfile()
        try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(BrowserDatabase(profiles: [old])).write(to: path)
        let store = ProfileStore(fileURL: path)
        XCTAssertFalse(store.isReadOnly)
        XCTAssertNil(store.profile(old.id)?.fingerprintCheck)
        XCTAssertNil(store.database.fingerprintLedger)
    }
}
