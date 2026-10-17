import Foundation

struct PrivacySettings: Codable, Equatable {
    var blockTrackers = true
    var blockCanvasReadback = false
    var blockAudioReadback = false
    var blockWebRTC = false
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

struct BrowserProfile: Codable, Identifiable, Equatable {
    var id = UUID()
    var dataStoreID = UUID()
    var name = "Hồ sơ mới"
    var notes = ""
    var tags = ""
    var color = "mint"
    var homeURL = "https://www.google.com"
    var desktopMode = false
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
