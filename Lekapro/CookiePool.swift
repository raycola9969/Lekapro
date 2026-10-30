import Foundation
import Combine
import CryptoKit
import Security
import WebKit

struct CookieSeedReceipt: Codable, Equatable {
    var domains: [String]
    var cookieCount: Int
}

struct CookieSeedConfiguration {
    let records: [CookieRecord]
    let domainCount: Int

    static func domain(_ value: String) -> String {
        value.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }
    func selection<R: RandomNumberGenerator>(using random: inout R, now: Date = Date()) throws -> [HTTPCookie] {
        guard (1...20).contains(domainCount) else { throw BrowserError.invalid("Chọn từ 1 đến 20 nhóm domain.") }
        let cookies = try records.map { try $0.cookie() }.filter { ($0.expiresDate ?? .distantFuture) > now }
        let groups = Dictionary(grouping: cookies, by: { Self.domain($0.domain) })
        guard !groups.isEmpty else { throw BrowserError.invalid("Kho không còn cookie còn hạn. Hãy nhập lại kho.") }
        let selected = groups.keys.sorted().shuffled(using: &random).prefix(domainCount)
        return selected.flatMap { groups[$0] ?? [] }
    }
    @MainActor
    func apply(to profile: BrowserProfile, proxy: ProxyRecord?) async throws -> CookieSeedReceipt {
        var random = SystemRandomNumberGenerator()
        let cookies = try selection(using: &random)
        let store = try DataStoreFactory.make(id: profile.dataStoreID, proxy: proxy)
        for cookie in cookies {
            try Task.checkCancellation()
            await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
                store.httpCookieStore.setCookie(cookie) { done.resume() }
            }
        }
        try Task.checkCancellation()
        let installed = await CookieService.all(in: store)
        for cookie in cookies {
            guard installed.contains(where: {
                Self.domain($0.domain) == Self.domain(cookie.domain) && $0.name == cookie.name &&
                $0.path == cookie.path && $0.value == cookie.value &&
                $0.isSecure == cookie.isSecure && $0.isHTTPOnly == cookie.isHTTPOnly
            }) else { throw BrowserError.invalid("Chưa nạp đủ cookie vào kho hồ sơ. Chưa mở website.") }
        }
        return CookieSeedReceipt(domains: Set(cookies.map { Self.domain($0.domain) }).sorted(), cookieCount: cookies.count)
    }
}

// Pool values are separate from profile/config exports. AES-GCM key stays in
// this device's Keychain; replacing/deleting the pool does not edit old stores.
@MainActor
final class CookiePoolStore: ObservableObject {
    static let shared = CookiePoolStore()
    private struct Payload: Codable {
        var records: [CookieRecord]
        var enabled: Bool
        var domainCount: Int
    }
    @Published private(set) var records: [CookieRecord] = []
    @Published private(set) var enabled = false
    @Published private(set) var domainCount = 3
    @Published private(set) var loadError: String?
    private let fileURL: URL
    private let testKey: SymmetricKey?
    var domains: [String] { Set(records.filter { ($0.expirationDate ?? .greatestFiniteMagnitude) > Date().timeIntervalSince1970 }
        .map { CookieSeedConfiguration.domain($0.domain) }).sorted() }
    var configuration: CookieSeedConfiguration? {
        enabled ? CookieSeedConfiguration(records: records, domainCount: domainCount) : nil
    }
    init(fileURL: URL? = nil, key: SymmetricKey? = nil) {
        self.fileURL = fileURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lekapro/cookie-pool.sealed")
        testKey = key
        if FileManager.default.fileExists(atPath: self.fileURL.path) {
            do {
                let sealed = try AES.GCM.SealedBox(combined: Data(contentsOf: self.fileURL))
                let data = try AES.GCM.open(sealed, using: encryptionKey(create: false))
                let saved = try JSONDecoder().decode(Payload.self, from: data)
                guard (1...20).contains(saved.domainCount), saved.records.count <= 10_000 else { throw BrowserError.invalid("Invalid pool") }
                _ = try saved.records.map { try $0.cookie() }
                records = saved.records; enabled = saved.enabled; domainCount = saved.domainCount
            } catch { loadError = "Không mở được kho cookie. Giữ nguyên file; hãy mở khóa máy rồi thử lại." }
        }
    }
    private func encryptionKey(create: Bool) throws -> SymmetricKey {
        if let testKey { return testKey }
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "app.lekapro.cookie-pool", kSecAttrAccount as String: "encryption-key"]
        var request = query
        request[kSecReturnData as String] = true; request[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &value)
        if status == errSecSuccess, let data = value as? Data, data.count == 32 { return SymmetricKey(data: data) }
        guard status == errSecItemNotFound, create else { throw BrowserError.invalid("Không đọc được khóa kho cookie.") }
        let key = SymmetricKey(size: .bits256)
        var attributes = query
        attributes[kSecValueData as String] = key.withUnsafeBytes { Data($0) }
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        guard SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess else { throw BrowserError.invalid("Không lưu được khóa kho cookie.") }
        return key
    }
    private func save(_ next: Payload) throws {
        guard loadError == nil else { throw BrowserError.invalid(loadError!) }
        let data = try JSONEncoder().encode(next)
        let sealed = try AES.GCM.seal(data, using: encryptionKey(create: true))
        guard let combined = sealed.combined else { throw BrowserError.invalid("Không mã hóa được kho cookie.") }
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try combined.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
        var url = fileURL; var attributes = URLResourceValues(); attributes.isExcludedFromBackup = true
        try? url.setResourceValues(attributes)
        records = next.records; enabled = next.enabled; domainCount = next.domainCount
    }
    func replace(with data: Data, now: Date = Date()) throws {
        let parsed = try CookieService.parse(data).filter { ($0.expiresDate ?? .distantFuture) > now }
        var unique: [String: CookieRecord] = [:]
        for cookie in parsed { unique[cookie.domain.lowercased()+"\u{0}"+cookie.path+"\u{0}"+cookie.name] = CookieRecord(cookie) }
        guard !unique.isEmpty else { throw BrowserError.invalid("File không có cookie còn hạn.") }
        let records = unique.keys.sorted().compactMap { unique[$0] }
        try save(Payload(records: records, enabled: true, domainCount: domainCount))
    }
    func setEnabled(_ value: Bool) throws {
        guard !value || !domains.isEmpty else { throw BrowserError.invalid("Hãy nhập kho cookie còn hạn trước.") }
        try save(Payload(records: records, enabled: value, domainCount: domainCount))
    }
    func setDomainCount(_ value: Int) throws {
        guard (1...20).contains(value) else { throw BrowserError.invalid("Chọn từ 1 đến 20 nhóm domain.") }
        try save(Payload(records: records, enabled: enabled, domainCount: value))
    }
    func clear() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) { try FileManager.default.removeItem(at: fileURL) }
        records = []; enabled = false; domainCount = 3; loadError = nil
    }
}
