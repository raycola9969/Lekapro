import Foundation

enum FingerprintHomepageReader {
    // Operate the website's existing developer tabs, then read their displayed
    // JSON. No fetch interception, SDK invocation, script rewriting or ID injection.
    static let source = #"""
    (() => {
      const text = document.body?.innerText ?? '';
      const found = [...text.matchAll(/Hello, visitor ID\s*([a-zA-Z0-9]{16,64})\b/gi)].map(m=>m[1]);
      const ids = [...new Set(found)];
      const result = {url:location.href, timeOrigin:performance.timeOrigin,
        javascriptUserAgent:navigator.userAgent, visitorID:ids.length === 1 ? ids[0] : null};
      for (const pre of document.querySelectorAll('pre')) {
        try {
          const data = JSON.parse(pre.textContent);
          if (data && typeof data === 'object') {
            if (data.identification && data.event_id) result.serverResponse = data;
            else if (data.visitor_id && data.event_id) result.agentResponse = data;
          }
        } catch (_) {}
      }
      const wanted = __WANTED_TAB__;
      if ((wanted === 'response.json' && result.agentResponse) ||
          (wanted === 'smartSignals.json' && result.serverResponse)) return result;
      const tabs = [...document.querySelectorAll('li')];
      const target = tabs.find(e=>e.textContent.trim() === wanted);
      if (target) {
        if (!target.className.includes('CodeWithSelectors-module--active--')) target.click();
      } else if (result.visitorID) {
        document.getElementById('toggle_homepage_developer_demo')?.click();
      }
      return result;
    })()
    """#

    static func script(wantedTab: String) -> String {
        source.replacingOccurrences(of: "__WANTED_TAB__", with: wantedTab == "response.json" ? "'response.json'" : "'smartSignals.json'")
    }
}

struct FingerprintHomepageEvidence {
    private var origin: Double?
    private var url: String?
    private var visitorID: String?
    private var agent: [String: Any]?
    private var server: [String: Any]?
    var wantedTab: String { agent == nil ? "response.json" : "smartSignals.json" }

    mutating func consume(_ page: [String: Any]) -> [String: Any]? {
        guard let nextOrigin = page["timeOrigin"] as? Double, nextOrigin.isFinite, nextOrigin > 0,
              let nextURL = page["url"] as? String,
              let actual = URL(string: nextURL), FingerprintObservation.isHomepage(actual) else { return nil }
        if origin != nextOrigin || url != nextURL {
            origin = nextOrigin; url = nextURL; visitorID = nil; agent = nil; server = nil
        }
        if let value = page["visitorID"] as? String, FingerprintObservation.validID(value) { visitorID = value }
        if let value = page["agentResponse"] as? [String: Any] { agent = value }
        if let value = page["serverResponse"] as? [String: Any] { server = value }
        guard let visitorID, let agent, let server else { return nil }
        return ["visitorID": visitorID, "agentResponse": agent, "serverResponse": server,
                "url": nextURL, "timeOrigin": nextOrigin,
                "javascriptUserAgent": page["javascriptUserAgent"] ?? ""]
    }
}
