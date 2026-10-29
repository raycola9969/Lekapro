#if DEBUG
import Foundation
import CryptoKit
import WebKit

// Local .invalid fixtures only. No user profile, proxy, cookie pool or ID check
// is changed. Runs the production encrypted pool and cookie-install functions.
@MainActor
enum DeviceCookiePoolDiagnostics {
    private static var started = false
    static func startIfRequested(store: ProfileStore) {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let request = documents.appendingPathComponent("Lekapro-cookie-pool-request.json")
        guard !started, FileManager.default.fileExists(atPath: request.path) else { return }
        started = true
        Task {
            let output = documents.appendingPathComponent("Lekapro-cookie-pool-report.json")
            var result: [String: Any] = ["completed":false,"status":"running",
                "build":Bundle.main.object(forInfoDictionaryKey:"CFBundleVersion") as? String ?? "unknown"]
            func save() {
                if let data = try? JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]) {
                    try? data.write(to:output,options:[.atomic,.completeFileProtectionUnlessOpen])
                }
            }
            save()
            let before = store.database
            let candidates = (0..<3).map { _ in BrowserProfile() }
            let folder = FileManager.default.urls(for:.cachesDirectory,in:.userDomainMask)[0]
                .appendingPathComponent("Lekapro-cookie-pool-fixture-"+UUID().uuidString)
            let file = folder.appendingPathComponent("pool.sealed")
            result["ownedStoreIDs"] = candidates.map { $0.dataStoreID.uuidString }
            do {
                let data = try Data(contentsOf:request)
                guard data.count < 1024,
                      let body = try JSONSerialization.jsonObject(with:data) as? [String:String],
                      body == ["fixture":"own-cookie-pool"] else { throw BrowserError.invalid("Invalid cookie-pool QA request") }
                try FileManager.default.removeItem(at:request)
                var secure = CookieRecord(name:"qa_secure",value:"local-fixture-only",domain:"alpha.invalid",secure:true,
                    expirationDate:Date().addingTimeInterval(3600).timeIntervalSince1970)
                secure.httpOnly = true; secure.sameSite = "strict"
                let records = [secure,CookieRecord(name:"qa_preference",value:"blue",domain:"alpha.invalid"),
                    CookieRecord(name:"qa_preference",value:"green",domain:"beta.invalid"),
                    CookieRecord(name:"qa_preference",value:"red",domain:"gamma.invalid"),
                    CookieRecord(name:"qa_expired",value:"expired",domain:"expired.invalid",expirationDate:1)]
                let pool = CookiePoolStore(fileURL:file)
                try pool.replace(with:JSONEncoder().encode(records));try pool.setDomainCount(2)
                let reopened = CookiePoolStore(fileURL:file)
                guard reopened.loadError == nil, reopened.records.count == 4, reopened.domainCount == 2,
                      let configuration = reopened.configuration else { throw BrowserError.invalid("Encrypted pool reload failed") }
                result["encryptedPoolReloadedWithDeviceKeychain"] = true
                var assignments:[[String:Any]] = []
                for candidate in candidates.prefix(2) {
                    let receipt = try await configuration.apply(to:candidate,proxy:nil)
                    guard receipt.domains.count == 2, !receipt.domains.contains("expired.invalid") else {
                        throw BrowserError.invalid("Random domain grouping failed")
                    }
                    assignments.append(["domains":receipt.domains,"cookieCount":receipt.cookieCount])
                }
                result["randomAssignments"] = assignments
                let a = try DataStoreFactory.make(id:candidates[0].dataStoreID)
                let b = try DataStoreFactory.make(id:candidates[1].dataStoreID)
                let isolated = try CookieRecord(name:"qa_isolation",value:"A",domain:"isolation.invalid").cookie()
                await withCheckedContinuation { (done:CheckedContinuation<Void,Never>) in a.httpCookieStore.setCookie(isolated) { done.resume() } }
                let bCookies = await CookieService.all(in:b)
                guard !bCookies.contains(where:{$0.name=="qa_isolation"}) else { throw BrowserError.invalid("Store isolation failed") }
                let security = CookieSeedConfiguration(records:[secure],domainCount:1)
                _ = try await security.apply(to:candidates[2],proxy:nil)
                let third = try DataStoreFactory.make(id:candidates[2].dataStoreID)
                let installed = await CookieService.all(in:third)
                guard let actual = installed.first(where:{$0.name=="qa_secure"}), actual.isSecure, actual.isHTTPOnly,
                      actual.sameSitePolicy == .sameSiteStrict else { throw BrowserError.invalid("Cookie security attributes changed") }
                result["secureHttpOnlySameSitePreserved"] = true
                result["storesIsolated"] = true;result["navigationRequestsMade"] = 0
                let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
                guard try encoder.encode(store.database) == encoder.encode(before) else { throw BrowserError.invalid("User database changed") }
                result["userDatabaseUnchanged"] = true
                try reopened.clear()
                for candidate in candidates {
                    DataStoreFactory.release(id:candidate.dataStoreID)
                    try DataStoreFactory.removeRejectedLegacyDirectory(id:candidate.dataStoreID)
                }
                try? FileManager.default.removeItem(at:folder)
                result["ownedStoresRemoved"] = true
                result["completed"] = true;result["status"] = "finished"
            } catch { result["status"] = "error";result["error"] = error.localizedDescription }
            save()
        }
    }
}
#endif
