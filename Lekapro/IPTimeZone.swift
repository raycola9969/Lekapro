import Foundation
import Network
import WebKit

struct IPTimeZone: Equatable {
    let exitIP: String
    let identifier: String

    init(ip: String, identifier: String) throws {
        guard Self.validIP(ip), TimeZone(identifier: identifier) != nil else {
            throw BrowserError.invalid("Dịch vụ chưa trả về IP và múi giờ hợp lệ.")
        }
        exitIP = ip; self.identifier = identifier
    }
    static func validIP(_ value: String) -> Bool {
        IPv4Address(value) != nil || IPv6Address(value) != nil
    }
    static func sameIP(_ first: String, _ second: String) -> Bool {
        if let a = IPv4Address(first), let b = IPv4Address(second) { return a == b }
        if let a = IPv6Address(first), let b = IPv6Address(second) { return a == b }
        return false
    }
    init(response: [String: Any], expectedIP: String) throws {
        guard response["success"] as? Bool == true,
              let ip = response["ip"] as? String, Self.sameIP(ip, expectedIP),
              let timezone = response["timezone"] as? [String: Any],
              let identifier = timezone["id"] as? String else {
            throw BrowserError.invalid("Chưa tra được múi giờ cho IP thoát. Kiểm tra mạng/proxy hoặc thử lại sau.")
        }
        try self.init(ip: ip, identifier: identifier)
    }
}

@MainActor
protocol IPTimeZoneResolving {
    func resolve(dataStore: WKWebsiteDataStore, proxy: ProxyRecord?, userAgent: String?) async throws -> IPTimeZone
    func cancel()
}

// Both requests use the profile's real WebKit store/proxy, never URLSession's
// device connection. Look up the exact IP observed by ipify, not the proxy host.
@MainActor
final class IPTimeZoneResolver: IPTimeZoneResolving {
    private var token: UUID?
    private var tab: BrowserTab?

    func cancel() { token = nil; tab?.close(); tab = nil }

    func resolve(dataStore: WKWebsiteDataStore, proxy: ProxyRecord?, userAgent: String?) async throws -> IPTimeZone {
        cancel()
        let current = UUID(); token = current
        let configuration = WKWebViewConfiguration(); configuration.websiteDataStore = dataStore
        let view = BrowserTab(configuration: configuration, proxy: proxy, userAgent: userAgent)
        view.webView.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        view.onNewTab = nil; tab = view
        defer { view.close(); if token == current { token = nil; tab = nil } }
        let nonce = UUID().uuidString
        let detected = try await json(URL(string: "https://api.ipify.org/?format=json&lekapro_timezone=\(nonce)")!, tab: view, token: current)
        guard let ip = detected["ip"] as? String, IPTimeZone.validIP(ip) else {
            throw BrowserError.invalid("Không đọc được IP thoát của hồ sơ.")
        }
        var components = URLComponents(string: "https://ipwho.is/")!
        components.path = "/" + ip
        components.queryItems = [URLQueryItem(name: "fields", value: "success,ip,timezone.id"),
                                 URLQueryItem(name: "lekapro_timezone", value: nonce)]
        let response = try await json(components.url!, tab: view, token: current)
        return try IPTimeZone(response: response, expectedIP: ip)
    }

    private func json(_ url: URL, tab: BrowserTab, token expected: UUID) async throws -> [String: Any] {
        tab.navigate(url)
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline {
            try Task.checkCancellation()
            guard token == expected else { throw CancellationError() }
            if let error = tab.navigationError { throw error }
            if !tab.webView.isLoading, let actual = tab.webView.url,
               actual.scheme == "https", actual.host == url.host, actual.path == url.path,
               let text = try await tab.webView.evaluateJavaScript("document.body.innerText") as? String,
               text.utf8.count < 32_768, let data = text.data(using: .utf8),
               let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return value
            }
            try await Task.sleep(for: .milliseconds(250))
        }
        throw BrowserError.invalid("Không xác định được múi giờ theo IP. Chưa mở website; hãy thử lại.")
    }
}
