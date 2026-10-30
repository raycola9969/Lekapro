#if DEBUG
import Foundation

// Explicit one-shot import from a regular file in our own Documents directory.
// No network listener or arbitrary paths; uses the same parser/encrypted pool
// as the UI. A populated pool is preserved unless replacement is requested.
@MainActor
enum DeviceCookiePoolImport {
    private struct Request: Decodable {
        let operation: String
        let filename: String
        let replaceExisting: Bool?
    }
    private static var started = false
    static func startIfRequested(store: ProfileStore) {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let input = directory.appendingPathComponent("Lekapro-cookie-import-request.json")
        guard !started, FileManager.default.fileExists(atPath: input.path) else { return }
        started = true
        let output = directory.appendingPathComponent("Lekapro-cookie-import-report.json")
        var result: [String: Any] = ["completed":false,"status":"running",
            "build":Bundle.main.object(forInfoDictionaryKey:"CFBundleVersion") as? String ?? "unknown"]
        do {
            let requestData = try Data(contentsOf:input)
            guard requestData.count < 2048 else { throw BrowserError.invalid("Invalid cookie import request") }
            let request = try JSONDecoder().decode(Request.self,from:requestData)
            guard request.operation == "import-cookie-pool", !request.filename.isEmpty,
                  request.filename.utf8.count < 256,
                  !request.filename.contains("/"), !request.filename.contains("\\"),
                  !request.filename.contains(".."),
                  ["json","txt"].contains((request.filename as NSString).pathExtension.lowercased()) else {
                throw BrowserError.invalid("Cookie import requires an explicit JSON/TXT file in app Documents")
            }
            let source = directory.appendingPathComponent(request.filename).standardizedFileURL
            guard source.resolvingSymlinksInPath().deletingLastPathComponent() == directory.resolvingSymlinksInPath(),
                  try source.resourceValues(forKeys:[.isSymbolicLinkKey]).isSymbolicLink != true,
                  try source.resourceValues(forKeys:[.isRegularFileKey]).isRegularFile == true else {
                throw BrowserError.invalid("Cookie import source is outside the authorized directory")
            }
            let pool = CookiePoolStore.shared
            guard pool.loadError == nil, pool.records.isEmpty || request.replaceExisting == true else {
                throw BrowserError.invalid("Existing cookie pool was preserved")
            }
            let encoder = JSONEncoder();encoder.outputFormatting=[.sortedKeys]
            let before = try encoder.encode(store.database)
            try FileManager.default.removeItem(at:input)
            try pool.replace(with:DocumentReader.read(source))
            guard try encoder.encode(store.database) == before else { throw BrowserError.invalid("User database changed") }
            result["cookieCount"] = pool.records.count;result["domains"] = pool.domains
            result["enabled"] = pool.enabled;result["domainsPerProfile"] = pool.domainCount
            result["encryptedPoolImported"] = true;result["userDatabaseUnchanged"] = true
            result["completed"] = true;result["status"] = "finished"
        } catch {
            result["status"] = "error";result["error"] = error.localizedDescription
        }
        if let data = try? JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]) {
            try? data.write(to:output,options:[.atomic,.completeFileProtectionUnlessOpen])
        }
    }
}
#endif
