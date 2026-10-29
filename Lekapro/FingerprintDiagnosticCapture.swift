#if DEBUG
import Foundation
import CryptoKit
import WebKit

// Opt-in, own-candidate QA only. Read APIs, never rewrite fingerprint signals.
@MainActor
enum FingerprintDiagnosticCapture {
    static func hash(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func redactStorage(_ values: [String: Any]) -> [String: Any] {
        var result = values
        for key in ["localValues", "sessionValues"] {
            guard let entries = result.removeValue(forKey: key) as? [String: String] else { continue }
            result[key == "localValues" ? "localStorageDigests" : "sessionStorageDigests"] =
                entries.mapValues { hash($0) }
        }
        if let cookies = result.removeValue(forKey: "cookieText") as? String {
            result["scriptCookieDigests"] = cookies.split(separator: ";").compactMap { chunk -> [String: String]? in
                let parts = chunk.trimmingCharacters(in: .whitespaces).split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                guard parts.count == 2, !parts[0].isEmpty else { return nil }
                return ["name": String(parts[0]), "valueDigest": hash(String(parts[1]))]
            }
        }
        return result
    }

    static func cookies(_ store: WKWebsiteDataStore) async -> [[String: Any]] {
        let all = await CookieService.all(in: store)
        return all.filter { $0.domain == "fingerprint.com" || $0.domain.hasSuffix(".fingerprint.com") }
            .map { ["name": $0.name, "domain": $0.domain, "path": $0.path,
                    "httpOnly": $0.isHTTPOnly, "secure": $0.isSecure,
                    "valueDigest": hash($0.value)] }
            .sorted { ($0["name"] as? String ?? "") < ($1["name"] as? String ?? "") }
    }

    static func capture(tab: BrowserTab, page: [String: Any], store: WKWebsiteDataStore) async -> [String: Any] {
        var result = page
        do {
            let value = try await tab.webView.callAsyncJavaScript(#"""
            const attempt = (fn) => { try { return fn(); } catch (e) { return {error:String(e)}; } };
            const bounded = async (fn) => await Promise.race([
              Promise.resolve().then(fn).catch(e=>({error:String(e)})),
              new Promise(resolve=>setTimeout(()=>resolve({error:'Diagnostic timeout'}),3000))]);
            const entries = store => Object.fromEntries(Object.keys(store).sort().map(k=>[k,store.getItem(k)]));
            const state = {
              url:location.href,timeOrigin:performance.timeOrigin,secureContext:isSecureContext,
              userAgent:navigator.userAgent,timeZone:Intl.DateTimeFormat().resolvedOptions().timeZone,
              currentOffset:new Date().getTimezoneOffset(),
              januaryOffset:new Date('2026-01-15T12:00:00Z').getTimezoneOffset(),
              language:navigator.language,languages:navigator.languages,
              localValues:attempt(()=>entries(localStorage)),sessionValues:attempt(()=>entries(sessionStorage)),
              cookieText:attempt(()=>document.cookie),
              estimateSupported:typeof navigator.storage?.estimate==='function'
            };
            if (state.estimateSupported) state.storageEstimate=await bounded(()=>navigator.storage.estimate());
            state.indexedDBDatabasesSupported=typeof globalThis.indexedDB?.databases==='function';
            if (state.indexedDBDatabasesSupported) state.indexedDBDatabases=await bounded(()=>indexedDB.databases());
            if (typeof globalThis.caches?.keys==='function') state.cacheNames=await bounded(()=>caches.keys());
            state.worker=await bounded(()=>new Promise(resolve=>{
              let worker,url;const finish=value=>{worker?.terminate();if(url)URL.revokeObjectURL(url);resolve(value)};
              try {
                const code="postMessage({timeZone:Intl.DateTimeFormat().resolvedOptions().timeZone,currentOffset:new Date().getTimezoneOffset(),januaryOffset:new Date('2026-01-15T12:00:00Z').getTimezoneOffset(),userAgent:navigator.userAgent,language:navigator.language})";
                url=URL.createObjectURL(new Blob([code],{type:'text/javascript'}));worker=new Worker(url);
                const timer=setTimeout(()=>finish({error:'Worker timeout'}),2500);
                worker.onmessage=e=>{clearTimeout(timer);finish(e.data)};
                worker.onerror=e=>{clearTimeout(timer);finish({error:String(e.message)})};
              } catch(e){finish({error:String(e)})}
            }));
            return state;
            """#, arguments: [:], in: nil, contentWorld: .page)
            if let context = value as? [String: Any] {
                result["diagnosticContext"] = redactStorage(context)
                result["diagnosticContextMatchesObservedPage"] =
                    context["url"] as? String == page["url"] as? String &&
                    context["timeOrigin"] as? Double == page["timeOrigin"] as? Double
            }
        } catch { result["diagnosticContextError"] = error.localizedDescription }
        result["fingerprintCookies"] = await cookies(store)
        return result
    }
}
#endif
