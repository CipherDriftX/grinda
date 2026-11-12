import AuthenticationServices
import UIKit

/// Card payments go through Whop's hosted checkout, opened in Apple's secure
/// web sheet. After paying, Whop sends the buyer to the server's
/// WHOP_REDIRECT_URL (site/paid.html), which hands over to `steppie://paid`
/// and closes the sheet. The race or purse goes live when Whop's webhook
/// reaches the server, never because the phone says so.
@MainActor
final class PaymentService: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    /// Shows the checkout. True when Whop sent the buyer back (they paid),
    /// false when they closed the sheet.
    func open(_ url: URL) async throws -> Bool {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Bool, Error>) in
            let done: (URL?, Error?) -> Void = { callback, error in
                if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    cont.resume(returning: false)
                } else if let error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume(returning: callback?.host == "paid")
                }
            }
            let s: ASWebAuthenticationSession
            if #available(iOS 17.4, *) {
                s = ASWebAuthenticationSession(url: url, callback: .customScheme("steppie"), completionHandler: done)
            } else {
                s = ASWebAuthenticationSession(url: url, callbackURLScheme: "steppie", completionHandler: done)
            }
            s.presentationContextProvider = self
            // Keep Whop's sign-in between payments, so a returning buyer doesn't type it all again.
            s.prefersEphemeralWebBrowserSession = false
            session = s
            if !s.start() {
                session = nil
                cont.resume(throwing: APIClient.APIError.server("Couldn't open the checkout. Try again."))
            }
        }
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
            if let window = scene?.keyWindow ?? scene?.windows.first { return window }
            return scene.map { UIWindow(windowScene: $0) } ?? UIWindow()
        }
    }
}
