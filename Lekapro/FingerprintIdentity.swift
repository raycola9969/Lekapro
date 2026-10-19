import Foundation
import CryptoKit

struct FingerprintCheck: Codable, Equatable {
    enum State: String, Codable { case pending, approved, failed, duplicate }
    var state: State = .pending
    var canAutoDelete = false
    var checkedAt: Date?
    var visitorID: String?
    var message: String?
    var configurationDigest: String?

    static var newCandidate: Self { Self(canAutoDelete: true) }
    var allowsBrowsing: Bool { state == .approved }
    var title: String {
        switch state {
        case .pending: return "Chờ kiểm tra ID"
        case .approved: return "ID không trùng lúc kiểm tra"
        case .failed: return "Chưa đo được ID"
        case .duplicate: return "ID bị trùng · không sử dụng"
        }
    }
}

struct FingerprintLedgerEntry: Codable, Equatable {
    let identityDigest: String
    let profileID: UUID
    let dataStoreID: UUID
    let firstRecordedAt: Date
}

struct FingerprintObservation: Equatable {
    let visitorID: String
    let eventID: String
    let environmentID: String
    let exitIP: String
    let userAgent: String
    let timeOrigin: Double

    // This is a consistency check of the HTTPS demo's displayed agent/server
    // responses, not cryptographic attestation or our own Server API access.
    init(page: [String: Any], actualURL: URL) throws {
        guard Self.isDemo(actualURL),
              let pageURL = page["url"] as? String, pageURL == actualURL.absoluteString,
              let visitor = page["visitorID"] as? String, Self.validID(visitor),
              let agent = page["agentResponse"] as? [String: Any],
              let server = page["serverResponse"] as? [String: Any],
              let identity = server["identification"] as? [String: Any],
              agent["visitor_id"] as? String == visitor, identity["visitor_id"] as? String == visitor,
              agent["cache_hit"] as? Bool == false,
              let event = agent["event_id"] as? String, !event.isEmpty, event.count <= 256,
              server["event_id"] as? String == event,
              let environment = server["environment_id"] as? String, !environment.isEmpty, environment.count <= 256,
              let ip = server["ip_address"] as? String, !ip.isEmpty,
              let ua = page["javascriptUserAgent"] as? String, !ua.isEmpty,
              server["user_agent"] as? String == ua,
              let serverURL = server["url"] as? String, serverURL == pageURL,
              let origin = page["timeOrigin"] as? Double, origin.isFinite, origin > 0 else {
            throw BrowserError.invalid("Chưa có phản hồi Fingerprint mới khớp giữa trang, agent và server.")
        }
        visitorID = visitor; eventID = event; environmentID = environment
        exitIP = ip; userAgent = ua; timeOrigin = origin
    }

    static func isDemo(_ url: URL) -> Bool {
        url.scheme == "https" && url.host == "fingerprint.com" &&
            ["/demo", "/demo/"].contains(url.path) && url.user == nil && url.password == nil &&
            (url.port == nil || url.port == 443)
    }
    private static func validID(_ value: String) -> Bool {
        (16...64).contains(value.utf8.count) && value.utf8.allSatisfy {
            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0)
        }
    }
}

struct FingerprintProof {
    let first: FingerprintObservation
    let reload: FingerprintObservation
    let configurationDigest: String
    let checkedAt: Date

    init(first: FingerprintObservation, reload: FingerprintObservation,
         configurationDigest: String, checkedExitIP: String, checkedAt: Date = Date()) throws {
        guard first.visitorID == reload.visitorID, first.eventID != reload.eventID,
              first.environmentID == reload.environmentID, first.userAgent == reload.userAgent,
              first.timeOrigin != reload.timeOrigin,
              first.exitIP == checkedExitIP, reload.exitIP == checkedExitIP else {
            throw BrowserError.invalid("ID, IP hoặc môi trường thay đổi khi tải lại. Hồ sơ chưa đạt kiểm tra.")
        }
        self.first = first; self.reload = reload; self.configurationDigest = configurationDigest; self.checkedAt = checkedAt
    }
    var identityDigest: String {
        FingerprintConfiguration.hash(first.environmentID + "\u{0}" + first.visitorID)
    }
}

enum FingerprintConfiguration {
    private struct Value: Encodable {
        let dataStoreID: UUID
        let userAgent: String?
        let desktopMode: Bool
        let timeZoneID: String?
        let minimumFontSize: Double?
        let fontFamily: ProfileFont?
        let privacy: PrivacySettings
        let proxyID: UUID?
        let proxyKind: ProxyKind?
        let proxyHost: String?
        let proxyPort: Int?
        let proxyUsername: String?
    }
    static func digest(_ profile: BrowserProfile, proxy: ProxyRecord?) throws -> String {
        let value = Value(dataStoreID: profile.dataStoreID, userAgent: profile.userAgent,
            desktopMode: profile.desktopMode, timeZoneID: profile.timeZoneID,
            minimumFontSize: profile.minimumFontSize, fontFamily: profile.fontFamily,
            privacy: profile.privacy, proxyID: profile.proxyID, proxyKind: proxy?.kind,
            proxyHost: proxy?.host, proxyPort: proxy?.port, proxyUsername: proxy?.username)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return SHA256.hash(data: try encoder.encode(value)).map { String(format: "%02x", $0) }.joined()
    }
    static func hash(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

enum FingerprintDecision: Equatable {
    case approved
    case duplicate(autoDelete: Bool)
}
