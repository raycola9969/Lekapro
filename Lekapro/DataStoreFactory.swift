import Foundation
import WebKit

@MainActor
enum DataStoreFactory {
    private static var stores: [String: WKWebsiteDataStore] = [:]

    static func make(id: UUID, proxy: ProxyRecord? = nil, forceLegacy: Bool = false) throws -> WKWebsiteDataStore {
        let legacy: Bool
        if #available(iOS 17, *) { legacy = forceLegacy } else { legacy = true }
        let key = (legacy ? "legacy:" : "public:") + id.uuidString
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
            let candidate: WKWebsiteDataStore? = try LegacyWebKitBridge.makeStore(at: base, proxy: dictionary)
            guard let created = candidate else {
                throw BrowserError.invalid("Không tạo được kho dữ liệu riêng trên phiên bản WebKit này.")
            }
            store = created
        }
        stores[key] = store
        return store
    }
    static func release(id: UUID) {
        stores.removeValue(forKey: "legacy:" + id.uuidString)
        stores.removeValue(forKey: "public:" + id.uuidString)
    }
}
