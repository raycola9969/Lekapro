import Foundation
import UIKit
import WebKit

// DEBUG only: dedicated stores inside Lekapro's sandbox, with local HTML.
@MainActor
enum DeviceDiagnostics {
    private static var hasRun = false
    static func runOnce() async {
        guard !hasRun else { return }; hasRun = true
        #if DEBUG
        var result: [String: Any] = ["osVersion": UIDevice.current.systemVersion,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "appVersion": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            "legacyCapabilities": LegacyWebKitBridge.capabilities()]
        do {
            let idA = UUID(uuidString: "4D93CDB1-1636-4FBE-8C22-C28D1660DA01")!
            let idB = UUID(uuidString: "4D93CDB1-1636-4FBE-8C22-C28D1660DA02")!
            let storeA = try DataStoreFactory.make(id: idA, forceLegacy: true)
            let storeB = try DataStoreFactory.make(id: idB, forceLegacy: true)
            result["sameProfileSharesStore"] = try DataStoreFactory.make(id: idA, forceLegacy: true) === storeA
            result["persistentStores"] = storeA.isPersistent && storeB.isPersistent
            let navA = DiagnosticNavigation(), navB = DiagnosticNavigation()
            let configA = WKWebViewConfiguration(); configA.websiteDataStore = storeA
            let configB = WKWebViewConfiguration(); configB.websiteDataStore = storeB
            let viewA = WKWebView(frame: CGRect(x: 0, y: 0, width: 320, height: 480), configuration: configA)
            let viewB = WKWebView(frame: CGRect(x: 0, y: 0, width: 320, height: 480), configuration: configB)
            try await navA.load(viewA); try await navB.load(viewB)
            // Start the store's WebKit session before asking for persisted cookies.
            let previous = await CookieService.all(in: storeB)
            result["cookiePersistedFromPreviousLaunch"] = previous.contains { $0.name == "lekapro_diagnostic" && $0.value == "B" }
            let expires = Date().addingTimeInterval(86400).timeIntervalSince1970
            let encoder = JSONEncoder()
            _ = try await CookieService.importData(encoder.encode([CookieRecord(name: "lekapro_diagnostic", value: "A", domain: "lekapro.invalid", expirationDate: expires)]), into: storeA)
            _ = try await CookieService.importData(encoder.encode([CookieRecord(name: "lekapro_diagnostic", value: "B", domain: "lekapro.invalid", expirationDate: expires)]), into: storeB)
            let a = await CookieService.all(in: storeA), b = await CookieService.all(in: storeB)
            result["cookieIsolation"] = a.contains { $0.name == "lekapro_diagnostic" && $0.value == "A" } && b.contains { $0.name == "lekapro_diagnostic" && $0.value == "B" }
            let oldStorage = try await viewB.evaluateJavaScript("localStorage.getItem('lekapro_diagnostic')")
            result["localStoragePersistedFromPreviousLaunch"] = oldStorage as? String == "B"
            _ = try await viewA.evaluateJavaScript("localStorage.setItem('lekapro_diagnostic','A')")
            _ = try await viewB.evaluateJavaScript("localStorage.setItem('lekapro_diagnostic','B')")
            let storageA = try await viewA.evaluateJavaScript("localStorage.getItem('lekapro_diagnostic')")
            let storageB = try await viewB.evaluateJavaScript("localStorage.getItem('lekapro_diagnostic')")
            result["localStorageIsolation"] = storageA as? String == "A" && storageB as? String == "B"
            let databaseScript = """
            const db = await new Promise((resolve, reject) => {
              const request = indexedDB.open('LekaproDiagnostic', 1);
              request.onupgradeneeded = () => request.result.createObjectStore('values');
              request.onsuccess = () => resolve(request.result);
              request.onerror = () => reject(request.error);
            });
            const previous = await new Promise((resolve, reject) => {
              const request = db.transaction('values').objectStore('values').get('profile');
              request.onsuccess = () => resolve(request.result ?? null);
              request.onerror = () => reject(request.error);
            });
            await new Promise((resolve, reject) => {
              const transaction = db.transaction('values', 'readwrite');
              transaction.objectStore('values').put(value, 'profile');
              transaction.oncomplete = () => resolve();
              transaction.onerror = () => reject(transaction.error);
            });
            db.close();
            return previous;
            """
            _ = try await execute(databaseScript, value: "A", in: viewA)
            let oldB = try await execute(databaseScript, value: "B", in: viewB)
            result["indexedDBPersistedFromPreviousLaunch"] = oldB as? String == "B"
            let valueA = try await execute(databaseScript, value: "A", in: viewA)
            let valueB = try await execute(databaseScript, value: "B", in: viewB)
            result["indexedDBIsolation"] = valueA as? String == "A" && valueB as? String == "B"
            result["indexedDBReadBack"] = ["A": String(describing: valueA), "B": String(describing: valueB)]
            viewA.stopLoading(); viewB.stopLoading()
            result["completed"] = true
        } catch { result["error"] = error.localizedDescription; result["completed"] = false }
        let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Lekapro-device-check.json")
        do { try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]).write(to: path, options: .atomic) }
        catch { NSLog("Lekapro diagnostic report could not be saved: %@", error.localizedDescription) }
        #endif
    }

    static func execute(_ script: String, value: String, in view: WKWebView) async throws -> Any {
        // The SDK's optional completion overload returns Void; explicitly await
        // its Result so an unfinished IndexedDB transaction cannot look complete.
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Any, Error>) in
            view.callAsyncJavaScript(script, arguments: ["value": value], in: nil, in: .page) { result in
                continuation.resume(with: result)
            }
        }
    }
}

@MainActor
private final class DiagnosticNavigation: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Error>?
    func load(_ webView: WKWebView) async throws {
        webView.navigationDelegate = self
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            webView.loadHTMLString("<!doctype html><title>Lekapro local storage check</title>", baseURL: URL(string: "https://lekapro.invalid"))
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(15))
                self?.finish(BrowserError.invalid("Local diagnostic page timed out."))
            }
        }
    }
    private func finish(_ error: Error? = nil) {
        guard let continuation else { return }; self.continuation = nil
        if let error { continuation.resume(throwing: error) } else { continuation.resume() }
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { finish() }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish(error) }
}
