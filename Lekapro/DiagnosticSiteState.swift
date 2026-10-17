import Foundation
import WebKit
import CryptoKit

// Only disposable QA profiles can be reset by the one-shot DEBUG harness.
// Uses WebKit's own store API; never moves or edits database files.
@MainActor
enum DiagnosticSiteState {
    private final class Pending<Value> {
        var continuation: CheckedContinuation<Value, Error>?
        init(_ continuation: CheckedContinuation<Value, Error>) { self.continuation = continuation }
        func finish(_ result: Result<Value, Error>) {
            guard let continuation else { return }
            self.continuation = nil; continuation.resume(with: result)
        }
    }

    private static func bounded<Value>(_ label: String, timeout duration: Duration = .seconds(120),
        operation: (@escaping (Result<Value, Error>) -> Void) -> Void) async throws -> Value {
        try await withCheckedThrowingContinuation { continuation in
            let pending = Pending(continuation)
            let timeout = Task { @MainActor in
                do { try await Task.sleep(for: duration) } catch { return }
                pending.finish(.failure(BrowserError.invalid("State experiment timed out: " + label)))
            }
            operation { result in
                Task { @MainActor in timeout.cancel(); pending.finish(result) }
            }
        }
    }
    private static func cookies(in store: WKWebsiteDataStore) async throws -> [HTTPCookie] {
        try await bounded("cookie enumeration") { done in
            store.httpCookieStore.getAllCookies { done(.success($0)) }
        }
    }
    private static func javascript(_ source: String, in tab: BrowserTab) async throws -> Any {
        try await bounded("local origin JavaScript") { done in
            tab.webView.evaluateJavaScript(source) { value, error in
                if let error { done(.failure(error)) } else { done(.success(value ?? NSNull())) }
            }
        }
    }
    private static func remove(types: Set<String>, from store: WKWebsiteDataStore) async throws {
        let _: Bool = try await bounded("native data removal") { done in
            store.removeData(ofTypes: types, modifiedSince: .distantPast) { done(.success(true)) }
        }
    }
    private static func networkPID(in store: WKWebsiteDataStore, differentFrom previous: Int32? = nil) async throws -> Int32 {
        let deadline = Date().addingTimeInterval(25)
        repeat {
            let pid = LegacyWebKitBridge.diagnosticNetworkPID(store)
            if pid > 0, previous == nil || pid != previous { return pid }
            try await Task.sleep(for: .milliseconds(100))
        } while Date() < deadline
        throw BrowserError.invalid("Diagnostic network process did not become ready.")
    }
    private static func flushNetwork(_ store: WKWebsiteDataStore) async throws {
        let _: Bool = try await bounded("persistent network-session flush") { done in
            let accepted = LegacyWebKitBridge.flushDiagnosticNetwork(store) { done(.success(true)) }
            if !accepted { done(.failure(BrowserError.invalid("Persistent network-session flush is unavailable."))) }
        }
    }
    enum Reset: String, Codable {
        case cookies, localStorage, indexedDB, caches, allSiteData, cookiesAndLocalStorage
        case allNativeData, allNativeDataAndNetwork
        case networkOnly, allSiteDataAndNetwork

        var dataTypes: Set<String> {
            switch self {
            case .cookies: return [WKWebsiteDataTypeCookies]
            case .localStorage: return [WKWebsiteDataTypeLocalStorage]
            case .indexedDB: return [WKWebsiteDataTypeIndexedDBDatabases]
            case .caches: return [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache]
            case .allSiteData: return WKWebsiteDataStore.allWebsiteDataTypes()
            case .cookiesAndLocalStorage: return [WKWebsiteDataTypeCookies, WKWebsiteDataTypeLocalStorage]
            case .allNativeData, .allNativeDataAndNetwork: return WKWebsiteDataStore.allWebsiteDataTypes()
            case .networkOnly: return []
            case .allSiteDataAndNetwork: return WKWebsiteDataStore.allWebsiteDataTypes()
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
        var clearAllTargetWebsiteData: Bool?
        var restartTargetNetworkAfterCopy: Bool?
    }
    static let identityKeys: Set<String> = ["_vid_t", "_iidt", "_vid_s", "_vid_lr"]

    static func validateCopy(_ request: CopyRequest, source: BrowserProfile, target: BrowserProfile) throws {
        try validateTarget(source); try validateTarget(target)
        guard source.id != target.id, source.dataStoreID != target.dataStoreID,
              request.sourceProfileID == source.id, request.targetProfileID == target.id,
              identityKeys.contains(request.key) else {
            throw BrowserError.invalid("Token copies require distinct disposable QA stores and a known identity key.")
        }
        if request.clearAllTargetWebsiteData == true, request.clearTargetFirst != true {
            throw BrowserError.invalid("Full target clearing must be explicitly enabled for the disposable copy target.")
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
            let origin = try await javascript("location.origin", in: tab) as? String
            guard origin == "https://fingerprint.com" else { throw BrowserError.invalid("State fixture has the wrong origin.") }
            return tab
        } catch { tab.close(); throw error }
    }

    static func localValues(_ tab: BrowserTab) async throws -> [String: String] {
        guard let values = try await javascript(
            "Object.fromEntries(Object.keys(localStorage).map(k=>[k,localStorage.getItem(k)]))", in: tab) as? [String: String] else {
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
        let cookieRecords = try await cookies(in: store)
        var result: [String: Any] = ["localStorageKeyNames": local.keys.sorted(),
            "localIdentityTokens": local.filter { identityKeys.contains($0.key) }.mapValues {
                ["bytes": $0.utf8.count, "sha256": digest($0)] as [String: Any]
            }, "cookieCount": cookieRecords.count,
            "cookieIdentityTokens": cookieRecords.filter { identityKeys.contains($0.name) }.map {
                ["name": $0.name, "domain": $0.domain, "path": $0.path,
                 "bytes": $0.value.utf8.count, "sha256": digest($0.value)] as [String: Any]
            }]
        // Store-record enumeration can stall on background simulator processes.
        // It is optional metadata: a timeout is explicitly unknown, never empty.
        do {
            let records: [WKWebsiteDataRecord] = try await bounded("native record enumeration", timeout: .seconds(15)) { done in
                store.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { done(.success($0)) }
            }
            result["nativeDataRecords"] = records.map { ["name": $0.displayName, "types": $0.dataTypes.sorted()] }
        } catch { result["nativeDataRecordsError"] = error.localizedDescription }
        return result
    }

    static func copy(_ request: CopyRequest, source: BrowserProfile, target: BrowserProfile,
                     sourceStore: WKWebsiteDataStore, targetStore: WKWebsiteDataStore) async throws -> [String: Any] {
        #if DEBUG
        try validateCopy(request, source: source, target: target)
        let before = try await snapshot(store: targetStore)
        var cleared: [String: Any] = [:]
        if request.clearTargetFirst == true {
            let types = request.clearAllTargetWebsiteData == true ? WKWebsiteDataStore.allWebsiteDataTypes() : Reset.cookiesAndLocalStorage.dataTypes
            try await remove(types: types, from: targetStore)
            cleared = try await snapshot(store: targetStore)
        }
        let sourceDocument = try await originDocument(store: sourceStore)
        let targetDocument = try await originDocument(store: targetStore)
        defer { sourceDocument.close(); targetDocument.close() }
        var count = 0
        switch request.kind {
        case .cookies:
            let sourceCookies = try await cookies(in: sourceStore).filter { $0.name == request.key }
            guard !sourceCookies.isEmpty else { throw BrowserError.invalid("The source identity cookie was absent.") }
            for cookie in sourceCookies {
                let _: Bool = try await bounded("identity cookie installation") { done in
                    targetStore.httpCookieStore.setCookie(cookie) { done(.success(true)) }
                }
            }
            count = sourceCookies.count
        case .localStorage:
            let local = try await localValues(sourceDocument)
            guard let value = local[request.key] else { throw BrowserError.invalid("The source identity storage key was absent.") }
            _ = try await targetDocument.webView.callAsyncJavaScript("localStorage.setItem(key,value); return true;",
                arguments: ["key": request.key, "value": value], in: nil, contentWorld: .page)
            count = 1
        }
        var networkBefore: Int32 = 0, networkAfter: Int32 = 0
        if request.restartTargetNetworkAfterCopy == true {
            _ = try await networkPID(in: sourceStore)
            try await flushNetwork(sourceStore)
            _ = try await networkPID(in: targetStore)
            try await flushNetwork(targetStore)
            networkBefore = try await networkPID(in: targetStore)
            try LegacyWebKitBridge.restartDiagnosticNetwork(targetStore)
            networkAfter = try await networkPID(in: targetStore, differentFrom: networkBefore)
        }
        return ["sourceProfileID": source.id.uuidString, "targetProfileID": target.id.uuidString,
            "kind": request.kind.rawValue, "key": request.key, "copiedValueCount": count,
            "allTargetWebsiteDataRemovalRequested": request.clearAllTargetWebsiteData == true,
            "targetNetworkPIDBefore": networkBefore, "targetNetworkPIDAfter": networkAfter,
            "persistentStateFlushCompleted": request.restartTargetNetworkAfterCopy == true,
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

    static func reset(_ action: Reset, profile: BrowserProfile, store: WKWebsiteDataStore,
                      restartNetwork: Bool = false) async throws -> [String: Any] {
        #if DEBUG
        try validateTarget(profile)
        let stateBefore = try await snapshot(store: store)
        let before = try await cookies(in: store)
        let types: Set<String>
        if action == .allNativeData || action == .allNativeDataAndNetwork {
            types = try LegacyWebKitBridge.diagnosticAllNativeDataTypes()
        } else { types = action.dataTypes }
        if !types.isEmpty { try await remove(types: types, from: store) }
        let restartsNetwork = restartNetwork || [Reset.allNativeDataAndNetwork, .allSiteDataAndNetwork, .networkOnly].contains(action)
        let processBefore: Int32
        if restartsNetwork {
            _ = try await networkPID(in: store)
            try await flushNetwork(store)
            processBefore = try await networkPID(in: store)
            try LegacyWebKitBridge.restartDiagnosticNetwork(store)
        } else { processBefore = LegacyWebKitBridge.diagnosticNetworkPID(store) }
        let stateAfter = try await snapshot(store: store)
        let processAfter: Int32
        if restartsNetwork { processAfter = try await networkPID(in: store, differentFrom: processBefore) }
        else { processAfter = LegacyWebKitBridge.diagnosticNetworkPID(store) }
        if restartsNetwork, processBefore <= 0 || processAfter <= 0 || processBefore == processAfter {
            throw BrowserError.invalid("The diagnostic network process did not restart.")
        }
        let after = try await cookies(in: store)
        return ["profileID": profile.id.uuidString, "action": action.rawValue,
            "cookieCountBefore": before.count, "cookieCountAfter": after.count,
            "requestedNativeDataTypes": types.sorted(),
            "networkRestartRequested": restartsNetwork,
            "persistentStateFlushCompleted": restartsNetwork,
            "networkPIDBefore": processBefore, "networkPIDAfter": processAfter,
            "stateBefore": stateBefore, "stateAfter": stateAfter]
        #else
        throw BrowserError.invalid("State experiments require a DEBUG build.")
        #endif
    }
}
