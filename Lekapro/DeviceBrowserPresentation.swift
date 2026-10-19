import SwiftUI
import UIKit

// A real, visible browser for DEBUG device measurements. Present only after the
// root view is attached; an early SwiftUI cover can be dropped on USB launch.
@MainActor
enum DeviceBrowserPresentation {
    private static var controller: UIViewController?

    static func show(_ session: BrowserSession, store: ProfileStore, workspace: BrowserWorkspace) async throws {
        try await showContent(BrowserView(session: session).environmentObject(store).environmentObject(workspace))
    }

    static func showReview(_ review: FingerprintReviewController, profileID: UUID,
                           store: ProfileStore, workspace: BrowserWorkspace) async throws {
        try await showContent(FingerprintReviewView(profileID: profileID, controller: review)
            .environmentObject(store).environmentObject(workspace))
    }

    private static func showContent<Content: View>(_ content: Content) async throws {
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
        let host = UIHostingController(rootView: content)
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
        // On iOS 16, asking a SwiftUI hosting controller to dismiss itself can
        // complete without detaching it. Dismiss from its actual presenter.
        let roots = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).compactMap(\.rootViewController)
        guard let presenter = current.presentingViewController ?? roots.first(where: { $0.presentedViewController === current }) else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            presenter.dismiss(animated: false) { continuation.resume() }
        }
    }
}
