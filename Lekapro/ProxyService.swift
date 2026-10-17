import Foundation
import Network
import WebKit

enum ProxyService {
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
    static func apply(_ proxy: ProxyRecord?, to store: WKWebsiteDataStore) throws {
        guard let proxy else { store.proxyConfigurations = []; return }
        store.proxyConfigurations = [try configuration(for: proxy, password: SecretStore.password(for: proxy.id))]
    }
}
