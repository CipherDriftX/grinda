import StoreKit

/// Grinda Pro, sold through StoreKit 2. Stakes never go through IAP: they are
/// real-money commitments handled by Stripe, not digital goods.
@MainActor
final class StoreService {
    static let groupID = "grinda.pro"
    static let productIDs = ["grinda.pro.monthly", "grinda.pro.yearly"]

    private var updates: Task<Void, Never>?

    /// Streams entitlement changes (renewals, refunds, Family Sharing) to `onChange`.
    func start(onChange: @escaping (Bool) -> Void) {
        updates?.cancel()
        updates = Task {
            onChange(await Self.hasPro())
            for await update in Transaction.updates {
                if case .verified(let t) = update { await t.finish() }
                onChange(await Self.hasPro())
            }
        }
    }

    static func hasPro() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, productIDs.contains(t.productID), t.revocationDate == nil {
                return true
            }
        }
        return false
    }
}
