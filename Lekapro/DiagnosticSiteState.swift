import Foundation
import WebKit

// Only disposable QA profiles can be reset by the one-shot DEBUG harness.
// Uses WebKit's own store API; never moves or edits database files.
@MainActor
enum DiagnosticSiteState {
    enum Reset: String, Codable {
        case cookies, localStorage, indexedDB, caches, allSiteData

        var dataTypes: Set<String> {
            switch self {
            case .cookies: return [WKWebsiteDataTypeCookies]
            case .localStorage: return [WKWebsiteDataTypeLocalStorage]
            case .indexedDB: return [WKWebsiteDataTypeIndexedDBDatabases]
            case .caches: return [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache]
            case .allSiteData: return WKWebsiteDataStore.allWebsiteDataTypes()
            }
        }
    }

    static func validateTarget(_ profile: BrowserProfile) throws {
        guard profile.tags == "qa-disposable-site-state" else {
            throw BrowserError.invalid("State resets require a dedicated disposable QA profile.")
        }
    }

    static func reset(_ action: Reset, profile: BrowserProfile, store: WKWebsiteDataStore) async throws -> [String: Any] {
        #if DEBUG
        try validateTarget(profile)
        let before = await CookieService.all(in: store)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            store.removeData(ofTypes: action.dataTypes, modifiedSince: .distantPast) { continuation.resume() }
        }
        let after = await CookieService.all(in: store)
        return ["profileID": profile.id.uuidString, "action": action.rawValue,
            "cookieCountBefore": before.count, "cookieCountAfter": after.count]
        #else
        throw BrowserError.invalid("State experiments require a DEBUG build.")
        #endif
    }
}
