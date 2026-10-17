import Foundation
import WebKit

// One-shot, DEBUG-only device QA. The request lives in this app's Documents;
// credentials are consumed into Keychain, then the request file is removed.
@MainActor
enum DeviceNetworkDiagnostics {
    private struct Request: Decodable {
        var host: String
        var port: Int
        var username: String
        var password: String
        var kind: ProxyKind
        var directProfileID: UUID
        var proxyProfileID: UUID
        var proxyID: UUID
    }
    private struct IPResponse: Decodable { var ip: String }
    private static var started = false

    static func runIfRequested(store: ProfileStore, workspace: BrowserWorkspace) async {
        #if DEBUG
        guard !started else { return }; started = true
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let input = documents.appendingPathComponent("Lekapro-network-request.json")
        guard FileManager.default.fileExists(atPath: input.path) else { return }
        let output = documents.appendingPathComponent("Lekapro-network-check.json")
        var result: [String: Any] = ["completed": false, "status": "running",
            "timestamp": ISO8601DateFormatter().string(from: Date())]
        func saveReport() {
            if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) {
                try? data.write(to: output, options: [.atomic, .completeFileProtectionUnlessOpen])
            }
        }
        saveReport()
        do {
            let data = try Data(contentsOf: input)
            defer { try? FileManager.default.removeItem(at: input) }
            guard data.count < 32_768 else { throw BrowserError.invalid("Network test request is too large.") }
            let request = try JSONDecoder().decode(Request.self, from: data)
            try FileManager.default.removeItem(at: input)
            var proxy = ProxyRecord()
            proxy.id = request.proxyID; proxy.name = "Proxy kiểm thử"; proxy.kind = request.kind
            proxy.host = request.host; proxy.port = request.port; proxy.username = request.username
            try store.saveProxy(proxy, password: request.password)
            var direct = store.profile(request.directProfileID) ?? BrowserProfile()
            direct.id = request.directProfileID; direct.name = "Kiểm thử • Trực tiếp"; direct.proxyID = nil
            direct.homeURL = "https://api.ipify.org?format=json"; direct.color = "mint"; direct.tags = "kiểm thử"
            var proxied = store.profile(request.proxyProfileID) ?? BrowserProfile()
            proxied.id = request.proxyProfileID; proxied.name = "Kiểm thử • Proxy"; proxied.proxyID = proxy.id
            proxied.homeURL = direct.homeURL; proxied.color = "orange"; proxied.tags = "kiểm thử"
            workspace.close(direct.id); workspace.close(proxied.id)
            try store.save(direct); try store.save(proxied)
            result["directProfileID"] = direct.id.uuidString
            result["proxyProfileID"] = proxied.id.uuidString
            result["proxyKind"] = proxy.kind.rawValue
            let directSession = try workspace.session(for: direct, store: store)
            await directSession.start()
            guard let directTab = directSession.selectedTab else {
                throw BrowserError.invalid("No browser tab was created.")
            }
            let directIP = try await readIP(in: directTab)
            result["directIP"] = directIP; saveReport()
            let proxySession = try workspace.session(for: proxied, store: store)
            await proxySession.start()
            guard let proxyTab = proxySession.selectedTab else { throw BrowserError.invalid("No proxy tab was created.") }
            let proxyIP = try await readIP(in: proxyTab)
            result["proxyIP"] = proxyIP
            result["differentExitIPs"] = directIP != proxyIP; saveReport()

            let encoder = JSONEncoder()
            for (session, value) in [(directSession, "DIRECT"), (proxySession, "PROXY")] {
                let record = CookieRecord(name: "lekapro_network_profile", value: value, domain: "lekapro.invalid",
                    expirationDate: Date().addingTimeInterval(86400).timeIntervalSince1970)
                _ = try await CookieService.importData(encoder.encode([record]), into: session.dataStore)
                _ = try await session.selectedTab?.webView.evaluateJavaScript("localStorage.setItem('lekapro_network_profile','\(value)')")
            }
            let directCookies = await CookieService.all(in: directSession.dataStore)
            let proxyCookies = await CookieService.all(in: proxySession.dataStore)
            result["cookieIsolation"] = directCookies.first { $0.name == "lekapro_network_profile" }?.value == "DIRECT"
                && proxyCookies.first { $0.name == "lekapro_network_profile" }?.value == "PROXY"
            let localA = try await directTab.webView.evaluateJavaScript("localStorage.getItem('lekapro_network_profile')")
            let localB = try await proxyTab.webView.evaluateJavaScript("localStorage.getItem('lekapro_network_profile')")
            result["localStorageIsolation"] = localA as? String == "DIRECT" && localB as? String == "PROXY"
            directTab.navigate(probeURL())
            let directAfter = try await readIP(in: directTab)
            result["directAfterProxyIP"] = directAfter
            result["directConnectionUnchanged"] = directIP == directAfter; saveReport()

            // A private test store, not another user profile or system proxy.
            var unavailable = ProxyRecord(); unavailable.host = "127.0.0.1"; unavailable.port = 9
            let unavailableID = UUID()
            let configuration = WKWebViewConfiguration()
            configuration.websiteDataStore = try DataStoreFactory.make(id: unavailableID, proxy: unavailable)
            let blockedTab = BrowserTab(configuration: configuration, proxy: unavailable)
            blockedTab.navigate(probeURL())
            do {
                let unexpectedIP = try await readIP(in: blockedTab, timeout: 20)
                result["unavailableProxyBlocked"] = false
                result["unavailableProxyUnexpectedIP"] = unexpectedIP
            } catch {
                result["unavailableProxyBlocked"] = blockedTab.errorMessage != nil
                result["unavailableProxyError"] = error.localizedDescription
            }
            blockedTab.close(); DataStoreFactory.release(id: unavailableID)
            directSession.persist(); proxySession.persist()
            result["completed"] = true; result["status"] = "finished"
        } catch {
            result["status"] = "error"; result["error"] = error.localizedDescription
            let native = error as NSError
            result["errorCode"] = native.code; result["errorDomain"] = native.domain
            if let path = native.userInfo["_NSURLErrorNWPathKey"] { result["networkPath"] = String(describing: path) }
        }
        saveReport()
        #endif
    }

    private static func probeURL() -> URL {
        URL(string: "https://api.ipify.org?format=json&lekapro_probe=\(UUID().uuidString)")!
    }

    private static func readIP(in tab: BrowserTab, timeout: TimeInterval = 45) async throws -> String {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if let message = tab.errorMessage {
                if let error = tab.navigationError { throw error }
                throw BrowserError.invalid(message)
            }
            if !tab.webView.isLoading, tab.webView.url?.host == "api.ipify.org",
               let text = try? await tab.webView.evaluateJavaScript("document.body.innerText") as? String,
               let data = text.data(using: .utf8), let response = try? JSONDecoder().decode(IPResponse.self, from: data),
               !response.ip.isEmpty { return response.ip }
            try await Task.sleep(for: .milliseconds(250))
        }
        throw BrowserError.invalid("WebKit IP check timed out.")
    }
}
