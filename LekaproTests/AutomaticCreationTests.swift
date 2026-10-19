import XCTest
import UIKit
@testable import Lekapro

@MainActor
final class AutomaticCreationTests: XCTestCase {
    private func store() -> ProfileStore {
        var passwords: [UUID: String] = [:]
        let secret = ProxySecretAccess(password: { passwords[$0] }, save: { passwords[$1] = $0 }, remove: { _ = passwords.removeValue(forKey: $0) })
        return ProfileStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("profiles.json"), secrets: secret)
    }
    private func inputs(_ count: Int = 1) throws -> [PastedProxy] {
        try ProxyPaste.parse((0..<count).map { "127.0.0.1:\(1080 + $0):fixture-user:fixture-password" }.joined(separator: "\n"))
    }
    private func proof(_ id: UUID, _ store: ProfileStore, visitor: String) throws -> FingerprintProof {
        let profile = try XCTUnwrap(store.profile(id)), ua = profile.userAgent ?? "Fixture UA"
        let url = URL(string: "https://fingerprint.com/demo/")!
        func observation(_ origin: Double) throws -> FingerprintObservation {
            let event = UUID().uuidString
            return try FingerprintObservation(page: ["visitorID": visitor, "url": url.absoluteString, "timeOrigin": origin,
                "javascriptUserAgent": ua, "agentResponse": ["visitor_id": visitor, "event_id": event, "cache_hit": false],
                "serverResponse": ["identification": ["visitor_id": visitor], "event_id": event,
                    "environment_id": "quick-fixture", "ip_address": "192.0.2.1", "user_agent": ua, "url": url.absoluteString]], actualURL: url)
        }
        return try FingerprintProof(first: observation(1), reload: observation(2),
            configurationDigest: FingerprintConfiguration.digest(profile, proxy: store.proxy(profile.proxyID)), checkedExitIP: "192.0.2.1")
    }
    private func seed(_ store: ProfileStore) throws -> BrowserProfile {
        var profile = BrowserProfile(); profile.fingerprintCheck = .newCandidate
        try store.save(profile); _ = try store.recordFingerprint(proof(profile.id, store, visitor: "AAAAAAAAAAAAAAAAAAAA"), for: profile.id)
        return try XCTUnwrap(store.profile(profile.id))
    }

    func testPasteParsesMultipleRowsPasswordColonIPv6AndDeduplicates() throws {
        let result = try ProxyPaste.parse("example.invalid:8080:user:pass:with:colon\n[2001:db8::1]:1080::\nexample.invalid:8080:user:pass:with:colon")
        XCTAssertEqual(result.count, 2); XCTAssertEqual(result[0].password, "pass:with:colon")
        XCTAssertEqual(result[0].record.kind, .socks5); XCTAssertEqual(result[1].record.host, "2001:db8::1")
        XCTAssertEqual(result[1].record.username, ""); XCTAssertEqual(result[1].password, "")
        XCTAssertEqual(try ProxyPaste.parse("host.invalid:3128:u:p", kind: .http)[0].record.kind, .http)
    }
    func testPasteRejectsMalformedRowsWithoutEchoingSecrets() throws {
        for input in ["", "host:0:user:private-value", "host:65536:u:private-value", "https://host:12:u:private-value", "host:12:user", "[bad]:12:u:private-value", "bad host:12:u:private-value", "host:12:u:private-value\tX"] {
            XCTAssertThrowsError(try ProxyPaste.parse(input)) { error in XCTAssertFalse(error.localizedDescription.contains("private-value")) }
        }
        XCTAssertThrowsError(try inputs(21))
    }
    func testPastedCredentialsReuseExactProxyWithoutChangingOldPassword() throws {
        let s = store(), input = try inputs()[0]
        let first = try s.proxyForQuickCreation(input)
        XCTAssertEqual(try s.proxyForQuickCreation(input).id, first.id)
        let changed = PastedProxy(record: input.record, password: "second-password")
        // A freshly parsed line always owns a new UUID.
        var newRecord = changed.record; newRecord.id = UUID()
        let second = try s.proxyForQuickCreation(PastedProxy(record: newRecord, password: changed.password))
        XCTAssertNotEqual(first.id, second.id); XCTAssertEqual(s.proxies.count, 2)
        XCTAssertEqual(try s.proxyForQuickCreation(input).id, first.id)
    }
    func testCreatorApprovesOnlyVerifiedProfileAndStopsAfterSuccess() async throws {
        let s = store(); var calls = 0
        let creator = AutomaticProfileCreator { id, store, _, _ in
            calls += 1
            do { _ = try store.recordFingerprint(self.proof(id, store, visitor: "BBBBBBBBBBBBBBBBBBBB"), for: id); return .approved }
            catch { XCTFail("Fixture approval failed"); return .failed }
        }
        await creator.run(inputs: try inputs(), store: s, workspace: BrowserWorkspace())
        XCTAssertEqual(calls, 1); XCTAssertEqual(creator.approvedCount, 1); XCTAssertTrue(creator.finished)
        XCTAssertEqual(s.profiles.count, 1); XCTAssertEqual(s.database.fingerprintLedger?.count, 1)
        XCTAssertEqual(s.profiles.first?.effectiveTimeZoneMode, .ip)
        XCTAssertEqual(s.profiles.first?.fingerprintCheck?.state, .approved)
    }
    func testDuplicateThenUniqueRetriesOnlyFreshCandidatesAndKeepsOldProfile() async throws {
        let s = store(), original = try seed(s); var calls = 0, stores: Set<UUID> = []
        let creator = AutomaticProfileCreator { id, store, _, _ in
            calls += 1
            do {
                stores.insert(try XCTUnwrap(store.profile(id)?.dataStoreID))
                let p = try self.proof(id, store, visitor: calls == 1 ? "AAAAAAAAAAAAAAAAAAAA" : "BBBBBBBBBBBBBBBBBBBB")
                switch try store.recordFingerprint(p, for: id) {
                case .approved: return .approved
                case .duplicate:
                    // The WebKit deletion itself is covered by admission tests.
                    _ = try store.rejectedCandidate(id, configurationDigest: p.configurationDigest)
                    try store.removeProfile(id); return .duplicateDeleted
                }
            } catch { XCTFail("Fixture decision failed"); return .failed }
        }
        await creator.run(inputs: try inputs(), store: s, workspace: BrowserWorkspace())
        XCTAssertEqual(calls, 2); XCTAssertEqual(stores.count, 2)
        XCTAssertEqual(creator.duplicateCount, 1); XCTAssertEqual(creator.approvedCount, 1)
        XCTAssertEqual(s.profile(original.id), original); XCTAssertEqual(s.database.fingerprintLedger?.count, 2)
    }
    func testAllDuplicatesStopAtThreeAndPreserveHistoryAcrossQueueItems() async throws {
        let s = store(), original = try seed(s); let ledger = s.database.fingerprintLedger
        var calls = 0
        let creator = AutomaticProfileCreator { id, store, _, _ in
            calls += 1
            do {
                let p = try self.proof(id, store, visitor: "AAAAAAAAAAAAAAAAAAAA")
                XCTAssertEqual(try store.recordFingerprint(p, for: id), .duplicate(autoDelete: true))
                try store.removeProfile(id); return .duplicateDeleted
            } catch { XCTFail("Fixture rejection failed"); return .failed }
        }
        await creator.run(inputs: try inputs(2), store: s, workspace: BrowserWorkspace())
        XCTAssertEqual(calls, 6); XCTAssertEqual(creator.duplicateCount, 6); XCTAssertEqual(creator.approvedCount, 0)
        XCTAssertTrue(creator.results.allSatisfy { $0.state == .exhausted && $0.attempts == 3 })
        XCTAssertEqual(s.profiles, [original]); XCTAssertEqual(s.database.fingerprintLedger, ledger)
    }
    func testMeasurementFailureDoesNotRetryOrDeleteCandidate() async throws {
        let s = store(); var calls = 0
        let creator = AutomaticProfileCreator { id, store, _, _ in
            calls += 1; try? store.recordFingerprintFailure(id, message: "Fixture network failure"); return .failed
        }
        await creator.run(inputs: try inputs(), store: s, workspace: BrowserWorkspace())
        XCTAssertEqual(calls, 1); XCTAssertEqual(s.profiles.count, 1)
        XCTAssertEqual(s.profiles.first?.fingerprintCheck?.state, .failed)
        XCTAssertEqual(creator.results.first?.state, .failed); XCTAssertEqual(creator.approvedCount, 0)
        XCTAssertTrue(s.database.fingerprintLedger?.isEmpty ?? true)
    }
    func testUnverifiedSuccessCannotBypassAdmission() async throws {
        let s = store(), creator = AutomaticProfileCreator { _, _, _, _ in .approved }
        await creator.run(inputs: try inputs(), store: s, workspace: BrowserWorkspace())
        XCTAssertEqual(creator.approvedCount, 0); XCTAssertEqual(creator.results.first?.state, .failed)
        XCTAssertEqual(s.profiles.first?.fingerprintCheck?.state, .pending)
    }
    func testCancelStopsQueueAndKeepsUnapprovedCandidate() async throws {
        let s = store(); var creator: AutomaticProfileCreator!
        creator = AutomaticProfileCreator { _, _, _, _ in creator.cancel(); return .failed }
        let idle = UIApplication.shared.isIdleTimerDisabled
        await creator.run(inputs: try inputs(2), store: s, workspace: BrowserWorkspace())
        XCTAssertEqual(s.profiles.count, 1); XCTAssertEqual(s.proxies.count, 1)
        XCTAssertTrue(creator.results.allSatisfy { $0.state == .cancelled }); XCTAssertFalse(creator.busy)
        XCTAssertEqual(UIApplication.shared.isIdleTimerDisabled, idle)
    }
}
