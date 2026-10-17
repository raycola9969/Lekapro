import Foundation
import CFNetwork
import Network
import WebKit

enum ProxyService {
    @available(iOS 17.0, *)
    static func configuration(for proxy: ProxyRecord, password: String?) throws -> ProxyConfiguration {
        try proxy.validate()
        let endpoint = NWEndpoint.hostPort(host: .init(proxy.host), port: NWEndpoint.Port(rawValue: UInt16(proxy.port))!)
        var configuration: ProxyConfiguration
        switch proxy.kind {
        case .socks5: configuration = ProxyConfiguration(socksv5Proxy: endpoint)
        case .http: configuration = ProxyConfiguration(httpCONNECTProxy: endpoint, tlsOptions: nil)
        case .https: configuration = ProxyConfiguration(httpCONNECTProxy: endpoint, tlsOptions: NWProtocolTLS.Options())
        }
        configuration.allowFailover = false
        if !proxy.username.isEmpty {
            guard let password else { throw BrowserError.invalid("Nhập lại mật khẩu trong Kho proxy trước khi mở hồ sơ.") }
            configuration.applyCredential(username: proxy.username, password: password)
        }
        return configuration
    }
    @MainActor
    @available(iOS 17.0, *)
    static func apply(_ proxy: ProxyRecord?, to store: WKWebsiteDataStore) throws {
        guard let proxy else { store.proxyConfigurations = []; return }
        store.proxyConfigurations = [try configuration(for: proxy, password: SecretStore.password(for: proxy.id))]
    }

    static func legacyConfiguration(for proxy: ProxyRecord, password: String?) throws -> [String: Any] {
        try proxy.validate()
        if !proxy.username.isEmpty && password == nil {
            throw BrowserError.invalid("Nhập lại mật khẩu trong Kho proxy trước khi mở hồ sơ.")
        }
        var configuration: [String: Any] = ["ExceptionsList": [String](), "ExcludeSimpleHostnames": 0,
            "ProxyAutoConfigEnable": 0, "ProxyAutoDiscoveryEnable": 0]
        if proxy.kind == .socks5 {
            configuration["SOCKSEnable"] = 1
            configuration["SOCKSProxy"] = proxy.host
            configuration["SOCKSPort"] = proxy.port
            if !proxy.username.isEmpty {
                configuration["SOCKSUser"] = proxy.username
                configuration["SOCKSPassword"] = password
                configuration[kCFStreamPropertySOCKSUser as String] = proxy.username
                configuration[kCFStreamPropertySOCKSPassword as String] = password
            }
        } else {
            configuration["HTTPEnable"] = 1
            configuration["HTTPProxy"] = proxy.host
            configuration["HTTPPort"] = proxy.port
            configuration["HTTPSEnable"] = 1
            configuration["HTTPSProxy"] = proxy.host
            configuration["HTTPSPort"] = proxy.port
            if proxy.kind == .https {
                throw BrowserError.invalid("HTTPS CONNECT có TLS tới proxy chưa được hỗ trợ trên iOS 16. Dùng SOCKS5 hoặc HTTP CONNECT.")
            }
        }
        return configuration
    }
}
