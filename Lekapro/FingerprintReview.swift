import SwiftUI
import WebKit
import UIKit

// Read the real HTTPS demo without modifying its agent, requests or responses.
enum FingerprintDemoReader {
    static let script = #"""
    (() => {
      const text = document.body?.innerText ?? '';
      function responseAfter(label) {
        const at = text.toUpperCase().indexOf(label);
        if (at < 0) return null;
        const start = text.indexOf('{', at + label.length);
        if (start < 0) return null;
        let depth = 0, quoted = false, escaped = false;
        for (let i = start; i < text.length; i++) {
          const ch = text[i];
          if (quoted) {
            if (escaped) escaped = false;
            else if (ch === '\\') escaped = true;
            else if (ch === '"') quoted = false;
          } else if (ch === '"') quoted = true;
          else if (ch === '{') depth++;
          else if (ch === '}' && --depth === 0) {
            try { return JSON.parse(text.slice(start, i + 1)); } catch (_) { return null; }
          }
        }
        return null;
      }
      const ids = [];
      const patterns = [
        /"visitorId"\s*:\s*"([a-zA-Z0-9]{16,64})"/g,
        /Your Device['’]s Visitor ID\s*\n\s*([a-zA-Z0-9]{16,64})/gi,
        /(?:Your Unique Visitor ID|VISITOR ID:)\s*\n?\s*([a-zA-Z0-9]{16,64})/gi
      ];
      for (const pattern of patterns) for (const match of text.matchAll(pattern)) ids.push(match[1]);
      const unique = [...new Set(ids)];
      return {visitorID:unique.length === 1 ? unique[0] : null,
        agentResponse:responseAfter('JAVASCRIPT AGENT RESPONSE'),
        serverResponse:responseAfter('SERVER API RESPONSE'),
        javascriptUserAgent:navigator.userAgent, timeOrigin:performance.timeOrigin, url:location.href};
    })()
    """#
}

@MainActor
final class FingerprintReviewController: ObservableObject {
    private static var checkingProfiles: Set<UUID> = []
    private static var awakeReviews = 0
    private static var previousIdleSetting = false
    @Published private(set) var session: BrowserSession?
    @Published private(set) var busy = false
    @Published private(set) var message = "Chuẩn bị kiểm tra…"
    @Published private(set) var approved = false
    @Published private(set) var deleted = false
    private(set) var didStart = false
    #if DEBUG
    private(set) var diagnosticProof: FingerprintProof?
    #endif
    private var runID: UUID?

    func close() {
        runID = nil; session?.close(); session = nil; busy = false
    }

    func run(profileID: UUID, store: ProfileStore, workspace: BrowserWorkspace) async {
        guard !busy else { return }
        didStart = true
        guard Self.checkingProfiles.insert(profileID).inserted else {
            message = "Hồ sơ vẫn đang hoàn tất lần kiểm tra trước. Hãy thử lại sau."; return
        }
        close(); let token = UUID(); runID = token
        if Self.awakeReviews == 0 { Self.previousIdleSetting = UIApplication.shared.isIdleTimerDisabled }
        Self.awakeReviews += 1
        UIApplication.shared.isIdleTimerDisabled = true
        busy = true; approved = false; deleted = false
        didStart = true
        #if DEBUG
        diagnosticProof = nil
        #endif
        var measuredSession: BrowserSession?
        defer {
            measuredSession?.close()
            if runID == token { close() }
            Self.checkingProfiles.remove(profileID)
            Self.awakeReviews -= 1
            if Self.awakeReviews == 0 { UIApplication.shared.isIdleTimerDisabled = Self.previousIdleSetting }
        }
        do {
            workspace.close(profileID)
            try store.beginFingerprintReview(profileID)
            guard let profile = store.profile(profileID) else { throw BrowserError.invalid("Không tìm thấy hồ sơ.") }
            let configuration = try FingerprintConfiguration.digest(profile, proxy: store.proxy(profile.proxyID))
            message = "Đang mở hồ sơ bằng kết nối đã cấu hình…"
            let browser = try BrowserSession(profile: profile, store: store, persistsBrowsingState: false)
            measuredSession = browser
            session = browser
            await browser.start()
            try ensureActive(token)
            if let error = browser.startupError { throw BrowserError.invalid(error) }
            session = browser // Publish again after the tab has been created.
            guard let tab = browser.selectedTab else { throw BrowserError.invalid("Không mở được tab kiểm tra.") }
            // Suppress links opening unmeasured tabs; the visible main page is
            // otherwise unmodified. Review never restores existing tabs/home.
            tab.onNewTab = nil
            let attached = Date().addingTimeInterval(15)
            while tab.webView.window == nil || tab.webView.bounds.width < 100 {
                try ensureActive(token)
                guard Date() < attached else { throw BrowserError.invalid("Màn hình kiểm tra chưa sẵn sàng.") }
                try await Task.sleep(for: .milliseconds(100))
            }
            message = "Đang kiểm tra IP qua kết nối của hồ sơ…"
            let exitIP = try await checkIP(tab: tab, token: token)
            if let zone = browser.ipTimeZone, !IPTimeZone.sameIP(zone.exitIP, exitIP) {
                throw BrowserError.invalid("IP đã đổi sau khi xác định múi giờ. Hãy thử lại bằng proxy có IP ổn định.")
            }
            message = "Đang đọc Visitor ID thật từ Fingerprint…"
            tab.navigate(URL(string: "https://fingerprint.com/demo/?lekapro_check=\(UUID().uuidString)")!)
            let first = try await observe(tab: tab, previous: nil, token: token)
            message = "Đang tải lại để xác nhận ID và IP ổn định…"
            tab.webView.reloadFromOrigin()
            let reload = try await observe(tab: tab, previous: first, token: token)
            let proof = try FingerprintProof(first: first, reload: reload,
                configurationDigest: configuration, checkedExitIP: exitIP)
            try ensureActive(token)
            #if DEBUG
            diagnosticProof = proof
            #endif
            switch try store.recordFingerprint(proof, for: profileID) {
            case .approved:
                approved = true
                message = "Đạt: ID không trùng lịch sử Lekapro tại thời điểm kiểm tra."
            case .duplicate(let autoDelete):
                if autoDelete {
                    // Close the measured WebView before clearing its store.
                    session?.close(); session = nil
                    try await workspace.deleteRejectedCandidate(profileID, configurationDigest: configuration, store: store)
                    deleted = true
                    message = "ID bị trùng. Đã xóa hồ sơ mới và xóa dữ liệu website qua WebKit."
                } else {
                    message = "ID bị trùng. Hồ sơ cũ được giữ lại và đánh dấu không đạt."
                }
            }
        } catch {
            if runID == token {
                message = "Chưa đạt: \(error.localizedDescription)"
                do { try store.recordFingerprintFailure(profileID, message: message) }
                catch { message += " Không lưu được trạng thái kiểm tra: \(error.localizedDescription)" }
            }
        }
    }

    private func ensureActive(_ token: UUID) throws {
        try Task.checkCancellation()
        guard runID == token else { throw CancellationError() }
    }
    private func checkIP(tab: BrowserTab, token: UUID) async throws -> String {
        tab.navigate(URL(string: "https://api.ipify.org/?format=json&lekapro_check=\(UUID().uuidString)")!)
        let end = Date().addingTimeInterval(40)
        while Date() < end {
            try ensureActive(token)
            if let error = tab.navigationError { throw error }
            if !tab.webView.isLoading, let url = tab.webView.url,
               url.scheme == "https", url.host == "api.ipify.org",
               let body = try await tab.webView.evaluateJavaScript("document.body.innerText") as? String,
               let data = body.data(using: .utf8),
               let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let ip = response["ip"] as? String, !ip.isEmpty {
                return ip
            }
            try await Task.sleep(for: .milliseconds(500))
        }
        throw BrowserError.invalid("Không đọc được IP của hồ sơ. Kiểm tra proxy và mạng.")
    }
    private func observe(tab: BrowserTab, previous: FingerprintObservation?, token: UUID) async throws -> FingerprintObservation {
        let end = Date().addingTimeInterval(75)
        while Date() < end {
            try ensureActive(token)
            if let error = tab.navigationError { throw error }
            if !tab.webView.isLoading, let url = tab.webView.url, FingerprintObservation.isDemo(url),
               let page = try await tab.webView.evaluateJavaScript(FingerprintDemoReader.script) as? [String: Any],
               let value = try? FingerprintObservation(page: page, actualURL: url),
               previous == nil || (value.timeOrigin != previous?.timeOrigin && value.eventID != previous?.eventID) {
                return value
            }
            try await Task.sleep(for: .milliseconds(500))
        }
        throw BrowserError.invalid("Chưa đọc được phản hồi mới của Fingerprint. Không xóa hoặc duyệt hồ sơ từ kết quả thiếu.")
    }
}

struct FingerprintReviewView: View {
    let profileID: UUID
    @EnvironmentObject private var store: ProfileStore
    @EnvironmentObject private var workspace: BrowserWorkspace
    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller = FingerprintReviewController()
    @State private var attempt = 0

    init(profileID: UUID) { self.profileID = profileID }
    init(profileID: UUID, controller: FingerprintReviewController) {
        self.profileID = profileID; _controller = StateObject(wrappedValue: controller)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if controller.busy { ProgressView() }
                Text(controller.message).font(.callout).padding(.horizontal)
                Text("Chỉ so với ID đã lưu trên thiết bị này. Kết quả có thể thay đổi về sau.")
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal)
                if let tab = controller.session?.selectedTab {
                    WebViewContainer(webView: tab.webView)
                } else { Spacer() }
                if !controller.busy && !controller.approved && !controller.deleted && store.profile(profileID) != nil {
                    Button("Thử kiểm tra lại") { attempt += 1 }.padding()
                }
            }
            .navigationTitle("Kiểm tra ID hồ sơ").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(controller.busy ? "Hủy" : "Đóng") { dismiss() } } }
        }
        .task(id: attempt) { await controller.run(profileID: profileID, store: store, workspace: workspace) }
        .onDisappear { controller.close() }
    }
}
