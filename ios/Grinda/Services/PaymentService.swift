import SwiftUI
import UIKit
#if canImport(StripePaymentSheet)
import StripePaymentSheet
#endif

/// Presents Stripe PaymentSheet (Apple Pay first) for a stake.
/// Holds use `capture_method=manual` on the server; the sheet is identical.
@MainActor
final class PaymentService {
    enum Outcome {
        case paid
        case cancelled
    }

    static let merchantID = "merchant.com.cipherdriftx.grinda"

    func pay(_ reply: APIClient.CreateStakeReply, currency: String) async throws -> Outcome {
        #if canImport(StripePaymentSheet)
        STPAPIClient.shared.publishableKey = reply.publishableKey
        var config = PaymentSheet.Configuration()
        config.merchantDisplayName = "Grinda"
        config.customer = .init(id: reply.customerId, ephemeralKeySecret: reply.ephemeralKey)
        config.applePay = .init(merchantId: Self.merchantID, merchantCountryCode: currency == "USD" ? "US" : "DE")
        config.allowsDelayedPaymentMethods = false
        config.returnURL = "grinda://stripe-redirect"
        config.primaryButtonLabel = reply.captureMethod == "manual" ? "Place hold" : "Pay stake"

        var appearance = PaymentSheet.Appearance()
        appearance.colors.primary = UIColor(Palette.cobalt)
        appearance.cornerRadius = 12
        appearance.primaryButton.cornerRadius = 14
        config.appearance = appearance

        let sheet = PaymentSheet(paymentIntentClientSecret: reply.paymentIntentClientSecret, configuration: config)
        guard let presenter = UIApplication.shared.topViewController else { throw APIClient.APIError.server("Can't show payment sheet.") }
        return try await withCheckedThrowingContinuation { cont in
            sheet.present(from: presenter) { result in
                switch result {
                case .completed: cont.resume(returning: .paid)
                case .canceled: cont.resume(returning: .cancelled)
                case .failed(let error): cont.resume(throwing: error)
                }
            }
        }
        #else
        throw APIClient.APIError.notConfigured
        #endif
    }
}

extension UIApplication {
    var topViewController: UIViewController? {
        let scene = connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
            ?? connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
