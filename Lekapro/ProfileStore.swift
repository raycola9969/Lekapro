import Foundation
import Combine

@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var database = BrowserDatabase()
    @Published var errorMessage: String?
    private(set) var isReadOnly = false
    private let fileURL: URL
    private let secrets: ProxySecretAccess
    var profiles: [BrowserProfile] { database.profiles }
    var proxies: [ProxyRecord] { database.proxies }

    init(fileURL: URL? = nil, secrets: ProxySecretAccess = .keychain) {
        self.secrets = secrets
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
            if profile.effectiveTimeZoneMode == .custom, profile.timeZoneID == nil {
                throw BrowserError.invalid("Chưa chọn múi giờ thủ công.")
            }
            guard !profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw BrowserError.invalid("Tên hồ sơ không được để trống.")
            }
            try AddressInput.validateHome(profile.homeURL)
            try UserAgentPreset.validate(profile.userAgent)
            if let zone = profile.timeZoneID, TimeZone(identifier: zone) == nil {
                throw BrowserError.invalid("Múi giờ không hợp lệ.")
            }
            if let size = profile.minimumFontSize, !size.isFinite || !(0...32).contains(size) {
                throw BrowserError.invalid("Cỡ chữ tối thiểu nằm trong 0–32 điểm.")
            }
            if let id = profile.proxyID, !database.proxies.contains(where: { $0.id == id }) {
                throw BrowserError.invalid("Không tìm thấy proxy của hồ sơ.")
            }
        }
        for proxy in database.proxies { try proxy.validate() }
        let ledger = database.fingerprintLedger ?? []
        guard Set(ledger.map(\.identityDigest)).count == ledger.count else {
            throw BrowserError.invalid("Lịch sử kiểm tra ID bị trùng khóa.")
        }
        for entry in ledger {
            guard entry.identityDigest.count == 64,
                  entry.identityDigest.allSatisfy({ $0.isHexDigit }) else {
                throw BrowserError.invalid("Lịch sử kiểm tra ID không hợp lệ.")
            }
        }
        for profile in database.profiles where profile.fingerprintCheck?.state == .approved {
            guard let check = profile.fingerprintCheck, !check.canAutoDelete,
                  let visitor = check.visitorID, let environment = database.fingerprintEnvironmentID,
                  check.configurationDigest == (try FingerprintConfiguration.digest(profile,
                    proxy: database.proxies.first { $0.id == profile.proxyID })),
                  ledger.contains(where: { $0.identityDigest == FingerprintConfiguration.hash(environment + "\u{0}" + visitor)
                    && $0.profileID == profile.id && $0.dataStoreID == profile.dataStoreID }) else {
                throw BrowserError.invalid("Hồ sơ chưa có bằng chứng kiểm tra ID phù hợp cấu hình.")
            }
        }
    }
    func save(_ profile: BrowserProfile) throws {
        var next = database
        var value = profile
        if let index = next.profiles.firstIndex(where: { $0.id == profile.id }) {
            let previous = next.profiles[index]
            // Metadata saves and stale editor copies cannot overwrite a verdict.
            value.fingerprintCheck = previous.fingerprintCheck
            if let check = previous.fingerprintCheck,
               try FingerprintConfiguration.digest(previous, proxy: proxy(previous.proxyID)) !=
                    FingerprintConfiguration.digest(value, proxy: proxy(value.proxyID)) {
                value.fingerprintCheck = FingerprintCheck(canAutoDelete: check.canAutoDelete,
                    message: "Cấu hình đã đổi; cần kiểm tra ID lại.")
            }
            next.profiles[index] = value
        } else {
            if let requested = value.fingerprintCheck {
                value.fingerprintCheck = FingerprintCheck(canAutoDelete: requested.canAutoDelete)
            }
            next.profiles.append(value)
        }
        try commit(next)
    }

    func beginFingerprintReview(_ id: UUID) throws {
        var next = database
        guard let index = next.profiles.firstIndex(where: { $0.id == id }) else {
            throw BrowserError.invalid("Không tìm thấy hồ sơ.")
        }
        let disposable = next.profiles[index].fingerprintCheck?.canAutoDelete == true
        next.profiles[index].fingerprintCheck = FingerprintCheck(canAutoDelete: disposable)
        try commit(next)
    }

    func recordFingerprint(_ proof: FingerprintProof, for id: UUID) throws -> FingerprintDecision {
        var next = database
        guard let index = next.profiles.firstIndex(where: { $0.id == id }),
              let check = next.profiles[index].fingerprintCheck, check.state == .pending else {
            throw BrowserError.invalid("Hồ sơ không ở trạng thái chờ kiểm tra.")
        }
        let profile = next.profiles[index]
        guard proof.configurationDigest == (try FingerprintConfiguration.digest(profile, proxy: proxy(profile.proxyID))) else {
            throw BrowserError.invalid("Cấu hình đã thay đổi trong lúc đo. Hãy kiểm tra lại.")
        }
        if let expectedUA = profile.userAgent, proof.first.userAgent != expectedUA {
            throw BrowserError.invalid("User-Agent đo được không khớp cấu hình hồ sơ.")
        }
        guard next.fingerprintEnvironmentID == nil || next.fingerprintEnvironmentID == proof.first.environmentID else {
            throw BrowserError.invalid("Môi trường Fingerprint đã đổi; chưa thể so ID với lịch sử đang lưu.")
        }
        next.fingerprintEnvironmentID = proof.first.environmentID
        var ledger = next.fingerprintLedger ?? []
        let collision = ledger.first { $0.identityDigest == proof.identityDigest &&
            ($0.profileID != id || $0.dataStoreID != profile.dataStoreID) }
        let decision: FingerprintDecision
        if collision != nil {
            next.profiles[index].fingerprintCheck = FingerprintCheck(state: .duplicate,
                canAutoDelete: check.canAutoDelete, checkedAt: proof.checkedAt,
                visitorID: proof.first.visitorID, message: "ID đã có trong lịch sử Lekapro.",
                configurationDigest: proof.configurationDigest)
            decision = .duplicate(autoDelete: check.canAutoDelete)
        } else {
            if !ledger.contains(where: { $0.identityDigest == proof.identityDigest }) {
                ledger.append(FingerprintLedgerEntry(identityDigest: proof.identityDigest, profileID: id,
                    dataStoreID: profile.dataStoreID, firstRecordedAt: proof.checkedAt))
            }
            next.profiles[index].fingerprintCheck = FingerprintCheck(state: .approved, canAutoDelete: false,
                checkedAt: proof.checkedAt, visitorID: proof.first.visitorID,
                message: "Không trùng ID đã lưu tại thời điểm kiểm tra.", configurationDigest: proof.configurationDigest)
            decision = .approved
        }
        next.fingerprintLedger = ledger
        // Serialize the verdict and ledger together. Two concurrent checks of
        // the same ID cannot both reserve it for different profiles.
        try commit(next)
        return decision
    }

    func recordFingerprintFailure(_ id: UUID, message: String) throws {
        var next = database
        guard let index = next.profiles.firstIndex(where: { $0.id == id }),
              let previous = next.profiles[index].fingerprintCheck,
              previous.state == .pending || previous.state == .failed else { return }
        next.profiles[index].fingerprintCheck = FingerprintCheck(state: .failed,
            canAutoDelete: previous.canAutoDelete, message: message)
        try commit(next)
    }

    func rejectedCandidate(_ id: UUID, configurationDigest: String) throws -> BrowserProfile {
        guard let profile = profile(id), let check = profile.fingerprintCheck,
              check.state == .duplicate, check.canAutoDelete,
              check.configurationDigest == configurationDigest,
              try FingerprintConfiguration.digest(profile, proxy: proxy(profile.proxyID)) == configurationDigest else {
            throw BrowserError.invalid("Chỉ tự xóa hồ sơ mới bị trùng với đúng cấu hình vừa kiểm tra.")
        }
        return profile
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
        let previous = try secrets.password(proxy.id)
        let oldProxy = self.proxy(proxy.id)
        let connectionChanged = oldProxy?.kind != proxy.kind || oldProxy?.host != proxy.host ||
            oldProxy?.port != proxy.port || oldProxy?.username != proxy.username || (previous ?? "") != password
        if connectionChanged {
            for index in next.profiles.indices where next.profiles[index].proxyID == proxy.id {
                if let check = next.profiles[index].fingerprintCheck {
                    next.profiles[index].fingerprintCheck = FingerprintCheck(canAutoDelete: check.canAutoDelete,
                        message: "Proxy đã đổi; cần kiểm tra ID lại.")
                }
            }
        }
        try secrets.save(password, proxy.id)
        do { try commit(next) }
        catch {
            if let previous { try? secrets.save(previous, proxy.id) }
            else { try? secrets.remove(proxy.id) }
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
        try secrets.remove(id)
    }
    func exportConfiguration() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        var configuration = database
        configuration.fingerprintLedger = nil; configuration.fingerprintEnvironmentID = nil
        for index in configuration.profiles.indices { configuration.profiles[index].fingerprintCheck = nil }
        return try encoder.encode(configuration)
    }
    func importConfiguration(_ data: Data) throws {
        guard data.count < 10_000_000 else { throw BrowserError.invalid("File cấu hình quá lớn.") }
        let incoming = try JSONDecoder().decode(BrowserDatabase.self, from: data)
        var configuration = incoming
        configuration.fingerprintLedger = nil; configuration.fingerprintEnvironmentID = nil
        for index in configuration.profiles.indices { configuration.profiles[index].fingerprintCheck = nil }
        try Self.validate(configuration)
        var next = database
        var mapping: [UUID: UUID] = [:]
        for var proxy in configuration.proxies {
            let oldID = proxy.id
            proxy.id = UUID()
            mapping[oldID] = proxy.id
            next.proxies.append(proxy)
        }
        for var profile in configuration.profiles {
            profile.id = UUID()
            profile.dataStoreID = UUID()
            profile.proxyID = profile.proxyID.flatMap { mapping[$0] }
            profile.tabs = profile.tabs.map { value in var tab = value; tab.id = UUID(); return tab }
            profile.selectedTabID = profile.tabs.first?.id
            profile.fingerprintCheck = .newCandidate
            next.profiles.append(profile)
        }
        try commit(next)
    }
}
