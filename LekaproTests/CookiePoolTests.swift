import XCTest
import CryptoKit
import WebKit
@testable import Lekapro

@MainActor
final class CookiePoolTests: XCTestCase {
    private struct Random: RandomNumberGenerator {
        var state: UInt64 = 123456789
        mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    }
    private func file() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("pool.sealed") }
    private func fixture() -> [CookieRecord] {
        var login = CookieRecord(name: "session", value: "fixture-secret-session", domain: ".alpha.invalid", path: "/account", secure: true,
                                 expirationDate: Date().addingTimeInterval(86400).timeIntervalSince1970)
        login.httpOnly = true; login.sameSite = "strict"
        return [login, CookieRecord(name: "preference", value: "fixture-blue", domain: ".alpha.invalid"),
                CookieRecord(name: "session", value: "fixture-beta", domain: "beta.invalid"),
                CookieRecord(name: "preference", value: "fixture-green", domain: "gamma.invalid"),
                CookieRecord(name: "expired", value: "fixture-expired", domain: "expired.invalid", expirationDate: 1)]
    }
    func testSelectionsContainCompleteDistinctDomainGroupsAndSkipExpiredCookies() throws {
        let records = fixture(), configuration = CookieSeedConfiguration(records: records, domainCount: 2)
        var random = Random(); var combinations = Set<String>()
        for _ in 0..<32 {
            let cookies = try configuration.selection(using: &random)
            let domains = Set(cookies.map { CookieSeedConfiguration.domain($0.domain) })
            XCTAssertEqual(domains.count, 2); XCTAssertFalse(domains.contains("expired.invalid"))
            if domains.contains("alpha.invalid") { XCTAssertEqual(cookies.filter { CookieSeedConfiguration.domain($0.domain)=="alpha.invalid" }.count, 2) }
            combinations.insert(domains.sorted().joined(separator: ","))
        }
        XCTAssertGreaterThan(combinations.count, 1)
    }
    func testEncryptedPoolPersistsSettingsAndKeepsPreviousDataOnBadReplacement() throws {
        let url = file(), key = SymmetricKey(size: .bits256), pool = CookiePoolStore(fileURL: url, key: key)
        try pool.replace(with: JSONEncoder().encode(fixture()))
        try pool.setDomainCount(2)
        XCTAssertEqual(pool.records.count, 4); XCTAssertEqual(pool.domains.count, 3); XCTAssertTrue(pool.enabled)
        let raw = try Data(contentsOf: url)
        XCTAssertFalse(String(decoding: raw, as: UTF8.self).contains("fixture-secret-session"))
        XCTAssertFalse(String(decoding: raw, as: UTF8.self).contains("alpha.invalid"))
        XCTAssertThrowsError(try pool.replace(with: Data("bad input".utf8)))
        XCTAssertEqual(try Data(contentsOf: url), raw)
        let restored = CookiePoolStore(fileURL: url, key: key)
        XCTAssertNil(restored.loadError); XCTAssertEqual(restored.domainCount, 2); XCTAssertEqual(restored.records, pool.records)
        let wrongKey = CookiePoolStore(fileURL: url, key: SymmetricKey(size: .bits256))
        XCTAssertNotNil(wrongKey.loadError)
        XCTAssertThrowsError(try wrongKey.replace(with: JSONEncoder().encode(fixture())))
        XCTAssertEqual(try Data(contentsOf: url), raw)
        try restored.clear(); XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
    func testNetscapeImportDeduplicatesAndRetainsCookieSecurity() throws {
        let pool = CookiePoolStore(fileURL: file(), key: SymmetricKey(size: .bits256))
        let text = "# Netscape HTTP Cookie File\n#HttpOnly_.alpha.invalid\tTRUE\t/account\tTRUE\t0\tsession\tfirst\n#HttpOnly_.alpha.invalid\tTRUE\t/account\tTRUE\t0\tsession\tlast#HttpOnly_literal\n"
        try pool.replace(with: Data(text.utf8))
        XCTAssertEqual(pool.records.count, 1)
        let cookie = try XCTUnwrap(pool.records.first).cookie()
        XCTAssertEqual(cookie.value, "last#HttpOnly_literal"); XCTAssertTrue(cookie.isSecure); XCTAssertTrue(cookie.isHTTPOnly)
        XCTAssertEqual(cookie.path, "/account"); XCTAssertNil(cookie.expiresDate)
    }
    func testCookieSeedInstallsOnlyIntoSelectedStoreBeforeNavigation() async throws {
        let profile = BrowserProfile(), other = BrowserProfile()
        let config = CookieSeedConfiguration(records: Array(fixture().prefix(2)), domainCount: 3)
        let a = try DataStoreFactory.make(id: profile.dataStoreID), b = try DataStoreFactory.make(id: other.dataStoreID)
        defer { DataStoreFactory.release(id: profile.dataStoreID); DataStoreFactory.release(id: other.dataStoreID) }
        let receipt = try await config.apply(to: profile, proxy: nil)
        XCTAssertEqual(receipt.domains, ["alpha.invalid"]); XCTAssertEqual(receipt.cookieCount, 2)
        let cookies = await CookieService.all(in: a), otherCookies = await CookieService.all(in: b)
        XCTAssertEqual(cookies.count, 2); XCTAssertTrue(otherCookies.isEmpty)
        let session = try XCTUnwrap(cookies.first { $0.name == "session" })
        XCTAssertTrue(session.isHTTPOnly); XCTAssertTrue(session.isSecure)
        XCTAssertEqual(session.path, "/account"); XCTAssertEqual(session.sameSitePolicy, .sameSiteStrict)
        XCTAssertEqual(try CookieRecord(session).cookie().sameSitePolicy, .sameSiteStrict)
    }
    func testCreatorSeedsEveryFreshAttemptBeforeRunningReview() async throws {
        var passwords: [UUID:String] = [:]
        let s = ProfileStore(fileURL: file(), secrets: ProxySecretAccess(password: { passwords[$0] }, save: { passwords[$1]=$0 }, remove: { passwords.removeValue(forKey:$0) }))
        let config = CookieSeedConfiguration(records: Array(fixture().prefix(2)), domainCount: 1)
        var calls=0; var storeIDs=Set<UUID>()
        // The unsigned simulator uses in-memory proxy secrets. Exercise real
        // WebKit cookie writes directly; the device QA covers saved proxy setup.
        let creator = AutomaticProfileCreator(cookieSeeder: { configuration, profile, _ in
            try await configuration.apply(to: profile, proxy: nil)
        }, runner: { id, store, _, _ in
            calls+=1
            do {
                let profile = try XCTUnwrap(store.profile(id)); storeIDs.insert(profile.dataStoreID)
                XCTAssertEqual(profile.cookieSeed?.cookieCount, 2)
                let dataStore = try DataStoreFactory.make(id: profile.dataStoreID)
                let cookies = await CookieService.all(in: dataStore); XCTAssertEqual(cookies.count, 2)
                // Fixture rejection makes the creator try a new UUID; real
                // Fingerprint evidence validation remains covered separately.
                try store.removeProfile(id); return .duplicateDeleted
            } catch { XCTFail("Cookie fixture did not reach the review"); return .failed }
        })
        await creator.run(inputs: try ProxyPaste.parse("127.0.0.1:1080:fixture:fixture"), store: s, workspace: BrowserWorkspace(), cookieSeed: config)
        XCTAssertEqual(calls,3); XCTAssertEqual(storeIDs.count,3); XCTAssertTrue(s.profiles.isEmpty)
        for id in storeIDs { DataStoreFactory.release(id:id) }
    }
    func testExpiredPoolStopsBeforeAnyReviewOrApprovalAndDuplicateMetadataIsReset() async throws {
        var passwords:[UUID:String]=[:]
        let store=ProfileStore(fileURL:file(),secrets:ProxySecretAccess(password:{passwords[$0]},save:{passwords[$1]=$0},remove:{passwords.removeValue(forKey:$0)}))
        var called=false
        let creator=AutomaticProfileCreator { _,_,_,_ in called=true;return .approved }
        await creator.run(inputs:try ProxyPaste.parse("127.0.0.1:1080:fixture:fixture"),store:store,workspace:BrowserWorkspace(),cookieSeed:CookieSeedConfiguration(records:[fixture().last!],domainCount:1))
        XCTAssertFalse(called);XCTAssertEqual(creator.approvedCount,0)
        XCTAssertEqual(store.profiles.first?.fingerprintCheck?.state,.failed)
        var profile=BrowserProfile();profile.cookieSeed=CookieSeedReceipt(domains:["alpha.invalid"],cookieCount:2)
        XCTAssertNil(profile.duplicated().cookieSeed)
        let data=try JSONEncoder().encode(profile)
        XCTAssertEqual(try JSONDecoder().decode(BrowserProfile.self,from:data).cookieSeed,profile.cookieSeed)
    }
}
