import StoreKit

/// Steppie Pro (subscription) and Steppie Shields (consumable), sold through
/// StoreKit 2. Stakes never go through IAP: they are real-money commitments
/// handled by Stripe, not digital goods.
@MainActor
final class StoreService {
    static let groupID = "steppie.pro"
    static let productIDs = ["steppie.pro.monthly", "steppie.pro.yearly"]
    static let shieldIDs = ["steppie.shield.1", "steppie.shield.3"]

    private var updates: Task<Void, Never>?

    /// Streams entitlement changes (renewals, refunds, Family Sharing) to `onChange`,
    /// and hands consumables that finish in the background to `onShields`.
    func start(onChange: @escaping (Bool) -> Void, onShields: @escaping (Transaction) async -> Void) {
        updates?.cancel()
        updates = Task {
            onChange(await Self.hasPro())
            for await update in Transaction.updates {
                if case .verified(let t) = update {
                    if Self.shieldIDs.contains(t.productID) { await onShields(t) }
                    await t.finish()
                }
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

    static func shieldProducts() async -> [Product] {
        ((try? await Product.products(for: shieldIDs)) ?? []).sorted { $0.price < $1.price }
    }

    /// Buys Shields. The account id rides along as appAccountToken so the server
    /// can check the purchase belongs to this account. Returns the transaction to credit.
    static func buy(_ product: Product, account: UUID?) async throws -> Transaction? {
        var options: Set<Product.PurchaseOption> = []
        if let account { options.insert(.appAccountToken(account)) }
        switch try await product.purchase(options: options) {
        case .success(.verified(let t)): return t
        default: return nil
        }
    }
}
