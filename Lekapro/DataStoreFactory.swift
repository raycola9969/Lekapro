import Foundation
import WebKit

@MainActor
enum DataStoreFactory {
    private static var stores: [String: WKWebsiteDataStore] = [:]

    static func make(id: UUID, proxy: ProxyRecord? = nil, forceLegacy: Bool = false, diagnosticQuota: UInt? = nil, diagnosticEphemeral: Bool = false) throws -> WKWebsiteDataStore {
        if diagnosticEphemeral {
            #if DEBUG
            guard proxy == nil, diagnosticQuota == nil else {
                throw BrowserError.invalid("Private-store QA currently requires a direct connection and no quota override.")
            }
            let key = "ephemeral:" + id.uuidString
            if let existing = stores[key] { return existing }
            let value = WKWebsiteDataStore.nonPersistent()
            stores[key] = value
            return value
            #else
            throw BrowserError.invalid("Private-store experiments require DEBUG.")
            #endif
        }
        let legacy: Bool
        if diagnosticQuota != nil { legacy = true }
        else if #available(iOS 17, *) { legacy = forceLegacy } else { legacy = true }
        let key = (legacy ? "legacy:" : "public:") + id.uuidString + (diagnosticQuota.map { ":quota:\($0)" } ?? "")
        if let existing = stores[key] { return existing }
        let store: WKWebsiteDataStore
        if #available(iOS 17, *), !legacy {
            store = WKWebsiteDataStore(forIdentifier: id)
            try ProxyService.apply(proxy, to: store)
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Lekapro/WebsiteProfiles", isDirectory: true)
                .appendingPathComponent(id.uuidString, isDirectory: true)
            let dictionary = try proxy.map { try ProxyService.legacyConfiguration(for: $0, password: SecretStore.password(for: $0.id)) }
            let candidate: WKWebsiteDataStore?
            if let quota = diagnosticQuota {
                candidate = try LegacyWebKitBridge.makeDiagnosticStore(at: base, proxy: dictionary, quota: quota)
            } else {
                candidate = try LegacyWebKitBridge.makeStore(at: base, proxy: dictionary)
            }
            guard let created = candidate else {
                throw BrowserError.invalid("Không tạo được kho dữ liệu riêng trên phiên bản WebKit này.")
            }
            store = created
        }
        stores[key] = store
        return store
    }
    static func release(id: UUID) {
        let prefixes = ["legacy:" + id.uuidString, "public:" + id.uuidString, "ephemeral:" + id.uuidString]
        for key in stores.keys.filter({ key in prefixes.contains(where: { key.hasPrefix($0) }) }) {
            stores.removeValue(forKey: key)
        }
    }
}
