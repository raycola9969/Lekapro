import Foundation
import Security

// The production path always defaults to Keychain. Unit tests can exercise
// password-change invalidation without unsigned simulator entitlements.
struct ProxySecretAccess {
    let password: (UUID) throws -> String?
    let save: (String, UUID) throws -> Void
    let remove: (UUID) throws -> Void
    static var keychain: Self {
        Self(password: { try SecretStore.password(for: $0) },
             save: { try SecretStore.save(password: $0, for: $1) },
             remove: { try SecretStore.remove($0) })
    }
}

enum SecretStore {
    private static let service = "app.lekapro.proxy"
    private static func query(_ id: UUID) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: id.uuidString]
    }
    static func password(for id: UUID) throws -> String? {
        var request = query(id)
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw BrowserError.invalid("Không đọc được Keychain (\(status)).")
        }
        return value
    }
    static func save(password: String, for id: UUID) throws {
        let request = query(id)
        let attributes: [String: Any] = [kSecValueData as String: Data(password.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        var status = SecItemUpdate(request as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(request.merging(attributes) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw BrowserError.invalid("Không lưu được Keychain (\(status)).") }
    }
    static func remove(_ id: UUID) throws {
        let status = SecItemDelete(query(id) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw BrowserError.invalid("Không xóa được Keychain (\(status)).")
        }
    }
}
