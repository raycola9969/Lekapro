import Foundation
import Combine

@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var database = BrowserDatabase()
    @Published var errorMessage: String?
    private(set) var isReadOnly = false
    private let fileURL: URL
    var profiles: [BrowserProfile] { database.profiles }
    var proxies: [ProxyRecord] { database.proxies }

    init(fileURL: URL? = nil) {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lekapro", isDirectory: true)
        self.fileURL = fileURL ?? directory.appendingPathComponent("profiles.json")
        do {
            try FileManager.default.createDirectory(at: self.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: self.fileURL.path) {
                database = try JSONDecoder().decode(BrowserDatabase.self, from: Data(contentsOf: self.fileURL))
                try Self.validate(database)
            }
        } catch {
            isReadOnly = true
            errorMessage = "Không đọc được dữ liệu. File gốc được giữ nguyên. \(error.localizedDescription)"
        }
    }
    func profile(_ id: UUID) -> BrowserProfile? { profiles.first { $0.id == id } }
    func proxy(_ id: UUID?) -> ProxyRecord? { proxies.first { $0.id == id } }

    private func commit(_ next: BrowserDatabase) throws {
        guard !isReadOnly else { throw BrowserError.invalid("Dữ liệu ở chế độ chỉ đọc do lỗi tải file.") }
        try Self.validate(next)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(next).write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
        database = next
    }
    static func validate(_ database: BrowserDatabase) throws {
        guard database.version == 1 else { throw BrowserError.invalid("Phiên bản dữ liệu chưa được hỗ trợ.") }
        guard Set(database.profiles.map(\.id)).count == database.profiles.count,
              Set(database.profiles.map(\.dataStoreID)).count == database.profiles.count,
              Set(database.proxies.map(\.id)).count == database.proxies.count else {
            throw BrowserError.invalid("Định danh hồ sơ hoặc proxy bị trùng.")
        }
        for profile in database.profiles {
            guard !profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw BrowserError.invalid("Tên hồ sơ không được để trống.")
            }
            try AddressInput.validateHome(profile.homeURL)
            try UserAgentPreset.validate(profile.userAgent)
            if let id = profile.proxyID, !database.proxies.contains(where: { $0.id == id }) {
                throw BrowserError.invalid("Không tìm thấy proxy của hồ sơ.")
            }
        }
        for proxy in database.proxies { try proxy.validate() }
    }
    func save(_ profile: BrowserProfile) throws {
        var next = database
        if let index = next.profiles.firstIndex(where: { $0.id == profile.id }) { next.profiles[index] = profile }
        else { next.profiles.append(profile) }
        try commit(next)
    }
    func update(_ id: UUID, change: (inout BrowserProfile) -> Void) {
        guard var value = profile(id) else { return }
        change(&value)
        do { try save(value) } catch { errorMessage = error.localizedDescription }
    }
    func removeProfile(_ id: UUID) throws {
        var next = database
        next.profiles.removeAll { $0.id == id }
        try commit(next)
    }
    func saveProxy(_ proxy: ProxyRecord, password: String) throws {
        try proxy.validate()
        var next = database
        if let index = next.proxies.firstIndex(where: { $0.id == proxy.id }) { next.proxies[index] = proxy }
        else { next.proxies.append(proxy) }
        let previous = try SecretStore.password(for: proxy.id)
        try SecretStore.save(password: password, for: proxy.id)
        do { try commit(next) }
        catch {
            if let previous { try? SecretStore.save(password: previous, for: proxy.id) }
            else { try? SecretStore.remove(proxy.id) }
            throw error
        }
    }
    func removeProxy(_ id: UUID) throws {
        guard !profiles.contains(where: { $0.proxyID == id }) else {
            throw BrowserError.invalid("Proxy đang được sử dụng. Đổi cấu hình hồ sơ trước khi xóa.")
        }
        var next = database
        next.proxies.removeAll { $0.id == id }
        try commit(next)
        try SecretStore.remove(id)
    }
    func exportConfiguration() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(database)
    }
    func importConfiguration(_ data: Data) throws {
        guard data.count < 10_000_000 else { throw BrowserError.invalid("File cấu hình quá lớn.") }
        let incoming = try JSONDecoder().decode(BrowserDatabase.self, from: data)
        try Self.validate(incoming)
        var next = database
        var mapping: [UUID: UUID] = [:]
        for var proxy in incoming.proxies {
            let oldID = proxy.id
            proxy.id = UUID()
            mapping[oldID] = proxy.id
            next.proxies.append(proxy)
        }
        for var profile in incoming.profiles {
            profile.id = UUID()
            profile.dataStoreID = UUID()
            profile.proxyID = profile.proxyID.flatMap { mapping[$0] }
            profile.tabs = profile.tabs.map { value in var tab = value; tab.id = UUID(); return tab }
            profile.selectedTabID = profile.tabs.first?.id
            next.profiles.append(profile)
        }
        try commit(next)
    }
}
