import Foundation
import WebKit

struct CookieRecord: Codable, Equatable {
    var name: String
    var value: String
    var domain: String
    var path: String?
    var secure: Bool?
    var httpOnly: Bool?
    var expirationDate: Double?
    var sameSite: String?

    init(_ cookie: HTTPCookie) {
        name = cookie.name; value = cookie.value; domain = cookie.domain
        path = cookie.path; secure = cookie.isSecure; httpOnly = cookie.isHTTPOnly
        expirationDate = cookie.expiresDate?.timeIntervalSince1970
        if cookie.sameSitePolicy == .strict { sameSite = "strict" }
        else if cookie.sameSitePolicy == .lax { sameSite = "lax" }
    }
    init(name: String, value: String, domain: String, path: String = "/", secure: Bool = false, expirationDate: Double? = nil) {
        self.name = name; self.value = value; self.domain = domain; self.path = path
        self.secure = secure; self.expirationDate = expirationDate
    }
    func cookie() throws -> HTTPCookie {
        guard !name.isEmpty, !domain.isEmpty, !domain.contains(where: { $0.isWhitespace }),
              !domain.contains("/"), !(name + value).contains("\n"), !(name + value).contains("\r") else {
            throw BrowserError.invalid("Cookie có tên hoặc domain không hợp lệ.")
        }
        var properties: [HTTPCookiePropertyKey: Any] = [.name: name, .value: value, .domain: domain, .path: path ?? "/"]
        if secure == true { properties[.secure] = "TRUE" }
        if httpOnly == true { properties[HTTPCookiePropertyKey("HttpOnly")] = "TRUE" }
        if let policy = sameSite?.lowercased(), ["strict", "lax"].contains(policy) {
            properties[.sameSitePolicy] = (policy == "strict" ? HTTPCookieStringPolicy.strict : .lax).rawValue
        }
        if let expiry = expirationDate, expiry > 0 { properties[.expires] = Date(timeIntervalSince1970: expiry) }
        guard let cookie = HTTPCookie(properties: properties) else { throw BrowserError.invalid("Không tạo được cookie: \(name).") }
        return cookie
    }
}

@MainActor
enum CookieService {
    static func parse(_ data: Data) throws -> [HTTPCookie] {
        guard data.count <= 10_000_000 else { throw BrowserError.invalid("File cookie quá lớn.") }
        let records: [CookieRecord]
        if let decoded = try? JSONDecoder().decode([CookieRecord].self, from: data) { records = decoded }
        else {
            guard let text = String(data: data, encoding: .utf8) else { throw BrowserError.invalid("File phải là UTF-8.") }
            var parsed: [CookieRecord] = []
            for line in text.components(separatedBy: .newlines) {
                guard !line.isEmpty, !line.hasPrefix("#") || line.hasPrefix("#HttpOnly_") else { continue }
                let fields = line.replacingOccurrences(of: "#HttpOnly_", with: "").components(separatedBy: "\t")
                guard fields.count == 7, let expiry = Double(fields[4]) else { throw BrowserError.invalid("Định dạng cookie cần JSON hoặc Netscape TXT hợp lệ.") }
                var record = CookieRecord(name: fields[5], value: fields[6], domain: fields[0], path: fields[2], secure: fields[3].uppercased() == "TRUE", expirationDate: expiry > 0 ? expiry : nil)
                record.httpOnly = line.hasPrefix("#HttpOnly_")
                parsed.append(record)
            }
            guard !parsed.isEmpty else { throw BrowserError.invalid("File không chứa cookie hợp lệ.") }
            records = parsed
        }
        guard records.count <= 10_000 else { throw BrowserError.invalid("Tối đa 10.000 cookie mỗi lần nhập.") }
        return try records.map { try $0.cookie() }
    }
    static func all(in store: WKWebsiteDataStore) async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in store.httpCookieStore.getAllCookies { continuation.resume(returning: $0) } }
    }
    static func importData(_ data: Data, into store: WKWebsiteDataStore) async throws -> Int {
        let cookies = try parse(data)
        for cookie in cookies {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                store.httpCookieStore.setCookie(cookie) { continuation.resume() }
            }
        }
        return cookies.count
    }
    static func export(from store: WKWebsiteDataStore) async throws -> Data {
        let cookies = await all(in: store)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(cookies.map(CookieRecord.init))
    }
    static func clear(_ store: WKWebsiteDataStore) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) { continuation.resume() }
        }
    }
}
