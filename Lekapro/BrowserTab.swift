import SwiftUI
import WebKit

@MainActor
final class BrowserTab: NSObject, ObservableObject, Identifiable, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
    let id: UUID
    let webView: WKWebView
    @Published var title = "Tab mới"
    @Published var url: URL?
    @Published var progress = 0.0
    @Published var loading = false
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var errorMessage: String?
    private(set) var navigationError: NSError?
    @Published var dialogMessage: String?
    @Published var dialogKind = "alert"
    var onChange: (() -> Void)?
    var onVisit: ((String, URL) -> Void)?
    var onNewTab: ((URL?) -> Void)?
    var onDownload: ((URL) -> Void)?
    private var observations: [NSKeyValueObservation] = []
    private var downloads: [ObjectIdentifier: (WKDownload, URL)] = [:]
    private var dialogCompletion: ((Bool, String?) -> Void)?
    private var proxy: ProxyRecord?

    init(id: UUID = UUID(), configuration: WKWebViewConfiguration, proxy: ProxyRecord? = nil) {
        self.id = id
        self.proxy = proxy
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        if #available(iOS 16.4, *) { webView.isInspectable = false }
        observations = [
            webView.observe(\.title, options: [.new]) { [weak self] _, _ in Task { @MainActor in self?.refresh() } },
            webView.observe(\.url, options: [.new]) { [weak self] _, _ in Task { @MainActor in self?.refresh() } },
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] _, _ in Task { @MainActor in self?.refresh() } },
            webView.observe(\.isLoading, options: [.new]) { [weak self] _, _ in Task { @MainActor in self?.refresh() } }
        ]
    }
    private func refresh() {
        title = webView.title?.isEmpty == false ? webView.title! : webView.url?.host ?? "Tab mới"
        url = webView.url ?? url; progress = webView.estimatedProgress; loading = webView.isLoading
        canGoBack = webView.canGoBack; canGoForward = webView.canGoForward
        onChange?()
    }
    func navigate(_ url: URL) { errorMessage = nil; navigationError = nil; self.url = url; webView.load(URLRequest(url: url)) }
    func close() {
        resolveDialog(accepted: false)
        webView.stopLoading(); webView.navigationDelegate = nil; webView.uiDelegate = nil
        observations.removeAll(); onChange = nil; onVisit = nil; onNewTab = nil; onDownload = nil
        for entry in downloads.values { entry.0.cancel { _ in } }
        downloads.removeAll()
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        refresh()
        if let url = webView.url, ["http", "https"].contains(url.scheme ?? "") { onVisit?(title, url) }
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { failed(error) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { failed(error) }
    private func failed(_ error: Error) {
        if (error as NSError).code != NSURLErrorCancelled { navigationError = error as NSError; errorMessage = error.localizedDescription }
        refresh()
    }
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.isProxy(), let proxy, !proxy.username.isEmpty {
            guard challenge.previousFailureCount == 0, let password = try? SecretStore.password(for: proxy.id) else {
                completionHandler(.cancelAuthenticationChallenge, nil); return
            }
            completionHandler(.useCredential, URLCredential(user: proxy.username, password: password, persistence: .forSession))
        } else { completionHandler(.performDefaultHandling, nil) }
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        errorMessage = "Tiến trình trang web đã dừng. Bấm tải lại để tiếp tục."
    }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url, ["http", "https", "about", "blob", "data"].contains(url.scheme?.lowercased() ?? "") else {
            decisionHandler(.cancel); errorMessage = "Liên kết này dùng giao thức chưa hỗ trợ."; return
        }
        if action.shouldPerformDownload { decisionHandler(.download) }
        else { decisionHandler(.allow) }
    }
    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(response.canShowMIMEType ? .allow : .download)
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        onNewTab?(action.request.url); return nil
    }
    func webViewDidClose(_ webView: WKWebView) { webView.stopLoading() }
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        setDialog(message, kind: "alert") { _, _ in completionHandler() }
    }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        setDialog(message, kind: "confirm") { value, _ in completionHandler(value) }
    }
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        setDialog(prompt, kind: "prompt") { value, text in completionHandler(value ? text ?? defaultText ?? "" : nil) }
    }
    private func setDialog(_ message: String, kind: String, completion: @escaping (Bool, String?) -> Void) {
        resolveDialog(accepted: false); dialogKind = kind; dialogCompletion = completion; dialogMessage = message
    }
    func resolveDialog(accepted: Bool, text: String? = nil) {
        let completion = dialogCompletion; dialogCompletion = nil; dialogMessage = nil
        completion?(accepted, text)
    }
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) { download.delegate = self }
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) { download.delegate = self }
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Downloads", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let safeName = URL(fileURLWithPath: suggestedFilename).lastPathComponent
            let target = folder.appendingPathComponent(String(UUID().uuidString.prefix(8)) + "-" + (safeName.isEmpty ? "download" : safeName))
            downloads[ObjectIdentifier(download)] = (download, target)
            completionHandler(target)
        } catch { completionHandler(nil); errorMessage = error.localizedDescription }
    }
    func downloadDidFinish(_ download: WKDownload) {
        if let entry = downloads.removeValue(forKey: ObjectIdentifier(download)) { onDownload?(entry.1) }
    }
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        downloads.removeValue(forKey: ObjectIdentifier(download)); errorMessage = error.localizedDescription
    }
}

struct WebViewContainer: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ view: WKWebView, context: Context) {}
}
