import XCTest
import UIKit
@testable import Lekapro

@MainActor
final class DevicePresentationTests: XCTestCase {
    func testConsecutiveDiagnosticBrowsersAttachAndDismiss() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: { $0.isKeyWindow })
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("profiles.json")
        let store = ProfileStore(fileURL: file)
        let workspace = BrowserWorkspace()
        defer { workspace.closeAll(); window.isHidden = true; previous?.makeKeyAndVisible() }
        do {
            for _ in 0..<2 {
                var profile = BrowserProfile()
                profile.privacy.blockTrackers = false
                profile.tabs = [SavedTab(url: "about:blank", title: "Presentation fixture")]
                try store.save(profile)
                let session = try workspace.session(for: profile, store: store)
                await session.start()
                let tab = try XCTUnwrap(session.selectedTab)
                try await DeviceBrowserPresentation.show(session, store: store, workspace: workspace)
                let deadline = Date().addingTimeInterval(5)
                while tab.webView.window == nil || tab.webView.bounds.width < 100 {
                    guard Date() < deadline else { throw BrowserError.invalid("Presented browser has no visible WebView.") }
                    try await Task.sleep(for: .milliseconds(50))
                }
                XCTAssertNotNil(window.rootViewController?.presentedViewController)
                await DeviceBrowserPresentation.hide()
                XCTAssertNil(window.rootViewController?.presentedViewController)
                XCTAssertNil(tab.webView.window)
                workspace.close(profile.id)
            }
        } catch {
            await DeviceBrowserPresentation.hide()
            throw error
        }
    }
}
