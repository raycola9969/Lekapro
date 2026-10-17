import SwiftUI
import UIKit

// A real, visible browser for DEBUG device measurements. Present only after the
// root view is attached; an early SwiftUI cover can be dropped on USB launch.
@MainActor
enum DeviceBrowserPresentation {
    private static var controller: UIViewController?

    static func show(_ session: BrowserSession, store: ProfileStore, workspace: BrowserWorkspace) async throws {
        await hide()
        let deadline = Date().addingTimeInterval(15)
        var presenter: UIViewController?
        while Date() < deadline {
            if UIApplication.shared.applicationState == .active,
               let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
               let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController,
               root.viewIfLoaded?.window != nil,
               root.presentedViewController == nil,
               root.transitionCoordinator == nil {
                presenter = root
                break
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        guard let presenter else { throw BrowserError.invalid("The app is not ready to present the QA browser.") }
        let browser = BrowserView(session: session).environmentObject(store).environmentObject(workspace)
        let host = UIHostingController(rootView: browser)
        host.modalPresentationStyle = .fullScreen
        controller = host
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            presenter.present(host, animated: false) { continuation.resume() }
        }
        guard host.viewIfLoaded?.window != nil else {
            await hide()
            throw BrowserError.invalid("QA browser presentation did not attach to a window.")
        }
    }

    static func hide() async {
        guard let current = controller else { return }
        controller = nil
        guard current.presentingViewController != nil else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            current.dismiss(animated: false) { continuation.resume() }
        }
    }
}
