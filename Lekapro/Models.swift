import Foundation

struct PrivacySettings: Codable, Equatable {
    var blockTrackers = true
    var blockCanvasReadback = false
    var blockAudioReadback = false
    var blockWebRTC = false
    var canvasNoise: Bool?
    var audioNoise: Bool?
    var audioNoiseScale: AudioNoiseScale?
    var blockWebGL: Bool?
    var reduceHardwareInfo: Bool?
    var protectBlobWorkers: Bool?
}

enum AudioNoiseScale: String, Codable, CaseIterable, Identifiable {
    case fine, standard
    var id: String { rawValue }
    var title: String { self == .fine ? "Rất nhỏ" : "Tiêu chuẩn" }
    var amplitude: Double { self == .fine ? 0.0000001 : 0.00001 }
}

struct SavedTab: Codable, Identifiable, Equatable {
    var id = UUID()
    var url = "about:blank"
    var title = "Tab mới"
}

struct PageRecord: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var url: String
    var date = Date()
}

enum UserAgentPreset: String, CaseIterable, Identifiable {
    case automatic, ios172, ios174, ios175, ios176, ios177, ios1879, ipad161
    case crios119, crios174, crios175, crios176, fxios119, fxios174, fxios175, fxios176, custom
    var id: String { rawValue }
    var title: String {
        switch self {
        case .automatic: return "Tự động theo WebKit"
        case .ios172: return "iPhone iOS 17.2 Safari"
        case .ios174: return "iPhone iOS 17.4 Safari"
        case .ios175: return "iPhone iOS 17.5 Safari"
        case .ios176: return "iPhone iOS 17.6 Safari"
        case .ios177: return "iPhone iOS 17.7 Safari"
        case .ios1879: return "iPhone iOS 18.7.9 Safari"
        case .ipad161: return "iPad iOS 16.1 Safari · UA"
        case .crios119: return "iPhone Chrome 119 · UA"
        case .crios174: return "iPhone iOS 17.4 Chrome 119 · UA"
        case .crios175: return "iPhone iOS 17.5 Chrome 119 · UA"
        case .crios176: return "iPhone iOS 17.6 Chrome 119 · UA"
        case .fxios119: return "iPhone Firefox 119 · UA"
        case .fxios174: return "iPhone iOS 17.4 Firefox 119 · UA"
        case .fxios175: return "iPhone iOS 17.5 Firefox 119 · UA"
        case .fxios176: return "iPhone iOS 17.6 Firefox 119 · UA"
        case .custom: return "Tùy chỉnh"
        }
    }
    var value: String? {
        switch self {
        case .ios172:
            return "Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1"
        case .ios174:
            return "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1"
        case .ios175:
            return "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
        case .ios176:
            return "Mozilla/5.0 (iPhone; CPU iPhone OS 17_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Mobile/15E148 Safari/604.1"
        case .ios177:
            return "Mozilla/5.0 (iPhone; CPU iPhone OS 17_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.7 Mobile/15E148 Safari/604.1"
        case .ios1879:
            return "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7_9 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.7 Mobile/15E148 Safari/604.1"
        case .ipad161:
            return "Mozilla/5.0 (iPad; CPU OS 16_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.1 Mobile/15E148 Safari/604.1"
        case .crios119:
            return "Mozilla/5.0 (iPhone; CPU iPhone OS 16_1_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/119.0.6045.41 Mobile/15E148 Safari/604.1"
        case .crios174, .crios175, .crios176:
            let os = self == .crios174 ? "17_4" : self == .crios175 ? "17_5" : "17_6"
            return "Mozilla/5.0 (iPhone; CPU iPhone OS \(os) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/119.0.6045.41 Mobile/15E148 Safari/604.1"
        case .fxios119:
            return "Mozilla/5.0 (iPhone; CPU iPhone OS 16_1_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/119.0 Mobile/15E148 Safari/605.1.15"
        case .fxios174, .fxios175, .fxios176:
            let os = self == .fxios174 ? "17_4" : self == .fxios175 ? "17_5" : "17_6"
            return "Mozilla/5.0 (iPhone; CPU iPhone OS \(os) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/119.0 Mobile/15E148 Safari/605.1.15"
        case .automatic, .custom: return nil
        }
    }
    static func matching(_ value: String?) -> Self {
        guard let value else { return .automatic }
        return allCases.first { $0.value == value } ?? .custom
    }
    static func validate(_ value: String?) throws {
        guard let value else { return }
        guard !value.trimmingCharacters(in: .whitespaces).isEmpty,
              value.utf8.count <= 512,
              value.unicodeScalars.allSatisfy({ (32...126).contains($0.value) }) else {
            throw BrowserError.invalid("User-Agent cần 1–512 ký tự ASCII hiển thị, không có xuống dòng.")
        }
    }
}

struct BrowserProfile: Codable, Identifiable, Equatable {
    var id = UUID()
    var dataStoreID = UUID()
    var name = "Hồ sơ mới"
    var notes = ""
    var tags = ""
    var color = "mint"
    var homeURL = "https://www.google.com"
    var desktopMode = false
    var userAgent: String?
    var timeZoneID: String?
    var minimumFontSize: Double?
    var fontFamily: ProfileFont?
    var proxyID: UUID?
    var privacy = PrivacySettings()
    var tabs: [SavedTab] = []
    var selectedTabID: UUID?
    var bookmarks: [PageRecord] = []
    var history: [PageRecord] = []
    var createdAt = Date()
    var lastUsed: Date?

    func duplicated() -> BrowserProfile {
        var copy = self
        copy.id = UUID()
        copy.dataStoreID = UUID()
        copy.name += " (bản sao)"
        copy.tabs = []
        copy.selectedTabID = nil
        copy.bookmarks = []
        copy.history = []
        copy.createdAt = Date()
        copy.lastUsed = nil
        return copy
    }
}

enum ProfileFont: String, Codable, CaseIterable, Identifiable {
    case serif, sansSerif, monospaced
    var id: String { rawValue }
    var title: String {
        switch self {
        case .serif: return "Có chân"
        case .sansSerif: return "Không chân"
        case .monospaced: return "Đơn cách"
        }
    }
    var css: String {
        switch self {
        case .serif: return "serif"
        case .sansSerif: return "sans-serif"
        case .monospaced: return "monospace"
        }
    }
}

enum ProxyKind: String, Codable, CaseIterable, Identifiable {
    case socks5, http, https
    var id: String { rawValue }
    var title: String {
        switch self {
        case .socks5: return "SOCKS5"
        case .http: return "HTTP CONNECT"
        case .https: return "HTTPS CONNECT"
        }
    }
}

struct ProxyRecord: Codable, Identifiable, Equatable {
    var id = UUID()
    var name = "Proxy mới"
    var kind: ProxyKind = .socks5
    var host = ""
    var port = 1080
    var username = ""
    var endpoint: String { "\(kind.rawValue)://\(host):\(port)" }
    func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BrowserError.invalid("Nhập tên proxy.")
        }
        guard !host.isEmpty, !host.contains(where: { $0.isWhitespace }),
              !host.contains("/"), !host.contains("@"), (1...65535).contains(port) else {
            throw BrowserError.invalid("Host chỉ chứa hostname/IP; cổng nằm trong 1–65535.")
        }
    }
}

struct BrowserDatabase: Codable {
    var version = 1
    var profiles: [BrowserProfile] = []
    var proxies: [ProxyRecord] = []
}

enum BrowserError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self { case .invalid(let message): return message }
    }
}

enum AddressInput {
    static func resolve(_ input: String) throws -> URL {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if text == "about:blank" { return URL(string: text)! }
        guard !text.isEmpty else { throw BrowserError.invalid("Nhập địa chỉ hoặc từ khóa.") }
        if text.contains("://") {
            guard let url = URL(string: text), let host = url.host, !host.isEmpty,
                  ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
                  url.user == nil, url.password == nil else {
                throw BrowserError.invalid("Chỉ mở URL HTTP hoặc HTTPS, không chứa mật khẩu.")
            }
            return url
        }
        if !text.contains(where: { $0.isWhitespace }),
           text.contains(".") || text.hasPrefix("localhost") || text.hasPrefix("[") {
            guard let url = URL(string: "https://" + text), let host = url.host, !host.isEmpty,
                  url.user == nil, url.password == nil else { throw BrowserError.invalid("Địa chỉ không hợp lệ.") }
            return url
        }
        var parts = URLComponents(string: "https://www.google.com/search")!
        parts.queryItems = [URLQueryItem(name: "q", value: text)]
        return parts.url!
    }
    static func validateHome(_ input: String) throws {
        let url = try resolve(input)
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? ""), input.contains("://") else {
            throw BrowserError.invalid("Trang chủ cần URL đầy đủ, ví dụ https://example.com.")
        }
    }
}
