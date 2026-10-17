import Foundation
import WebKit
import CryptoKit

// Only disposable QA profiles can be reset by the one-shot DEBUG harness.
// Uses WebKit's own store API; never moves or edits database files.
@MainActor
enum DiagnosticSiteState {
    enum Reset: String, Codable {
        case cookies, localStorage, indexedDB, caches, allSiteData, cookiesAndLocalStorage
        case allNativeData, allNativeDataAndNetwork

        var dataTypes: Set<String> {
            switch self {
            case .cookies: return [WKWebsiteDataTypeCookies]
            case .localStorage: return [WKWebsiteDataTypeLocalStorage]
            case .indexedDB: return [WKWebsiteDataTypeIndexedDBDatabases]
            case .caches: return [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache]
            case .allSiteData: return WKWebsiteDataStore.allWebsiteDataTypes()
            case .cookiesAndLocalStorage: return [WKWebsiteDataTypeCookies, WKWebsiteDataTypeLocalStorage]
            case .allNativeData, .allNativeDataAndNetwork: return WKWebsiteDataStore.allWebsiteDataTypes()
            }
        }
    }

    struct CopyRequest: Codable {
        enum Kind: String, Codable { case cookies, localStorage }
        var sourceProfileID: UUID
        var targetProfileID: UUID
        var kind: Kind
        var key: String
        var clearTargetFirst: Bool?
    }
    static let identityKeys: Set<String> = ["_vid_t", "_iidt", "_vid_s", "_vid_lr"]

    static func validateCopy(_ request: CopyRequest, source: BrowserProfile, target: BrowserProfile) throws {
        try validateTarget(source); try validateTarget(target)
        guard source.id != target.id, source.dataStoreID != target.dataStoreID,
              request.sourceProfileID == source.id, request.targetProfileID == target.id,
              identityKeys.contains(request.key) else {
            throw BrowserError.invalid("Token copies require distinct disposable QA stores and a known identity key.")
        }
    }

    // Controlled local HTML at the exact site origin. No site script, resource,
    // SDK method, or network request is loaded by this document.
    static func originDocument(store: WKWebsiteDataStore) async throws -> BrowserTab {
        let configuration = WKWebViewConfiguration(); configuration.websiteDataStore = store
        let tab = BrowserTab(configuration: configuration)
        tab.webView.loadHTMLString("<!doctype html><title>Disposable state session</title>",
            baseURL: URL(string: "https://fingerprint.com/"))
        let deadline = Date().addingTimeInterval(20)
        do {
            while tab.webView.title != "Disposable state session" || tab.webView.isLoading {
                guard Date() < deadline else { throw BrowserError.invalid("Disposable state session did not initialize.") }
                try await Task.sleep(for: .milliseconds(100))
            }
            let origin = try await tab.webView.evaluateJavaScript("location.origin") as? String
            guard origin == "https://fingerprint.com" else { throw BrowserError.invalid("State fixture has the wrong origin.") }
            return tab
        } catch { tab.close(); throw error }
    }

    static func localValues(_ tab: BrowserTab) async throws -> [String: String] {
        guard let values = try await tab.webView.evaluateJavaScript(
            "Object.fromEntries(Object.keys(localStorage).map(k=>[k,localStorage.getItem(k)]))") as? [String: String] else {
            throw BrowserError.invalid("Cannot enumerate the disposable origin storage.")
        }
        return values
    }

    static func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func snapshot(store: WKWebsiteDataStore) async throws -> [String: Any] {
        let document = try await originDocument(store: store)
        defer { document.close() }
        let local = try await localValues(document)
        let cookies = await CookieService.all(in: store)
        let records = await withCheckedContinuation { (continuation: CheckedContinuation<[WKWebsiteDataRecord], Never>) in
            store.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { continuation.resume(returning: $0) }
        }
        return ["localStorageKeyNames": local.keys.sorted(),
            "localIdentityTokens": local.filter { identityKeys.contains($0.key) }.mapValues {
                ["bytes": $0.utf8.count, "sha256": digest($0)] as [String: Any]
            }, "cookieCount": cookies.count,
            "cookieIdentityTokens": cookies.filter { identityKeys.contains($0.name) }.map {
                ["name": $0.name, "domain": $0.domain, "path": $0.path,
                 "bytes": $0.value.utf8.count, "sha256": digest($0.value)] as [String: Any]
            }, "nativeDataRecords": records.map { ["name": $0.displayName, "types": $0.dataTypes.sorted()] }]
    }

    static func copy(_ request: CopyRequest, source: BrowserProfile, target: BrowserProfile,
                     sourceStore: WKWebsiteDataStore, targetStore: WKWebsiteDataStore) async throws -> [String: Any] {
        #if DEBUG
        try validateCopy(request, source: source, target: target)
        let before = try await snapshot(store: targetStore)
        var cleared: [String: Any] = [:]
        if request.clearTargetFirst == true {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                targetStore.removeData(ofTypes: Reset.cookiesAndLocalStorage.dataTypes, modifiedSince: .distantPast) {
                    continuation.resume()
                }
            }
            cleared = try await snapshot(store: targetStore)
        }
        let sourceDocument = try await originDocument(store: sourceStore)
        let targetDocument = try await originDocument(store: targetStore)
        defer { sourceDocument.close(); targetDocument.close() }
        var count = 0
        switch request.kind {
        case .cookies:
            let cookies = await CookieService.all(in: sourceStore).filter { $0.name == request.key }
            guard !cookies.isEmpty else { throw BrowserError.invalid("The source identity cookie was absent.") }
            for cookie in cookies {
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    targetStore.httpCookieStore.setCookie(cookie) { continuation.resume() }
                }
            }
            count = cookies.count
        case .localStorage:
            let local = try await localValues(sourceDocument)
            guard let value = local[request.key] else { throw BrowserError.invalid("The source identity storage key was absent.") }
            _ = try await targetDocument.webView.callAsyncJavaScript("localStorage.setItem(key,value); return true;",
                arguments: ["key": request.key, "value": value], in: nil, contentWorld: .page)
            count = 1
        }
        return ["sourceProfileID": source.id.uuidString, "targetProfileID": target.id.uuidString,
            "kind": request.kind.rawValue, "key": request.key, "copiedValueCount": count,
            "targetBefore": before, "targetAfterClear": cleared, "targetAfter": try await snapshot(store: targetStore),
            "source": try await snapshot(store: sourceStore)]
        #else
        throw BrowserError.invalid("State experiments require a DEBUG build.")
        #endif
    }

    static func validateTarget(_ profile: BrowserProfile) throws {
        guard profile.tags == "qa-disposable-site-state" else {
            throw BrowserError.invalid("State resets require a dedicated disposable QA profile.")
        }
    }

    static func reset(_ action: Reset, profile: BrowserProfile, store: WKWebsiteDataStore) async throws -> [String: Any] {
        #if DEBUG
        try validateTarget(profile)
        let stateBefore = try await snapshot(store: store)
        let before = await CookieService.all(in: store)
        let types: Set<String>
        if action == .allNativeData || action == .allNativeDataAndNetwork {
            types = try LegacyWebKitBridge.diagnosticAllNativeDataTypes()
        } else { types = action.dataTypes }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            store.removeData(ofTypes: types, modifiedSince: .distantPast) { continuation.resume() }
        }
        let processBefore = LegacyWebKitBridge.diagnosticNetworkPID(store)
        if action == .allNativeDataAndNetwork { try LegacyWebKitBridge.restartDiagnosticNetwork(store) }
        let stateAfter = try await snapshot(store: store)
        let processAfter = LegacyWebKitBridge.diagnosticNetworkPID(store)
        if action == .allNativeDataAndNetwork, processBefore <= 0 || processAfter <= 0 || processBefore == processAfter {
            throw BrowserError.invalid("The diagnostic network process did not restart.")
        }
        let after = await CookieService.all(in: store)
        return ["profileID": profile.id.uuidString, "action": action.rawValue,
            "cookieCountBefore": before.count, "cookieCountAfter": after.count,
            "requestedNativeDataTypes": types.sorted(),
            "networkPIDBefore": processBefore, "networkPIDAfter": processAfter,
            "stateBefore": stateBefore, "stateAfter": stateAfter]
        #else
        throw BrowserError.invalid("State experiments require a DEBUG build.")
        #endif
    }
}
