import SwiftUI
import StoreKit

/// Steppie Pro. Native SubscriptionStoreView with our own marketing header.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model

    var body: some View {
        SubscriptionStoreView(groupID: StoreService.groupID) {
            VStack(alignment: .leading, spacing: 22) {
                ZStack(alignment: .bottom) {
                    CharacterView(who: .shelly, mood: .cheer, pose: .cheer).frame(width: 80, height: 92).offset(x: -110)
                    CharacterView(who: .bo, mood: .happy, pose: .wave).frame(width: 80, height: 92).offset(x: 110)
                    SteppieView(mood: .roar, pose: .flex, mane: 3, shoes: ShoeStyle.find("gold"))
                        .frame(height: 170)
                }
                .frame(maxWidth: .infinity)
                Text("Steppie Pro")
                    .font(.system(size: 40, weight: .heavy))
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 14) {
                    ProLine(symbol: "percent", text: "No service fee when your balance pays, lower fee by card")
                    ProLine(symbol: "square.stack.3d.up", text: "Run up to 5 races and purses at once")
                    ProLine(symbol: "megaphone", text: "Host one public purse a month free, and earn 5% of entries")
                    ProLine(symbol: "slider.horizontal.3", text: "Build your own solo races: any goal, any length")
                    ProLine(symbol: "chart.xyaxis.line", text: "Pace, best hours and weight projection")
                    ProLine(symbol: "crown", text: "The gold mane badge and the Stride S app icon")
                }
                Text("Pro never touches purse money. Finishers still split all of it, Pro or not.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.onFieldSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !model.profile.paidRacesAvailable {
                    // Said before the purchase, not after: the fee and host perks need paid races.
                    Text("Paid races aren't open to you where you live, so the fee and host perks won't apply. Insights, the badge and the icon still do.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .containerBackground(Palette.field.gradient, for: .subscriptionStoreFullHeight)
        }
        .subscriptionStoreControlStyle(.picker)
        .subscriptionStoreButtonLabel(.multiline)
        .storeButton(.visible, for: .restorePurchases)
        .storeButton(.visible, for: .cancellation)
        .tint(Palette.cobalt)
        // The account rides along so the server can tie the subscription to it.
        .inAppPurchaseOptions { [token = model.accountToken] _ in
            token.map { [.appAccountToken($0)] } ?? []
        }
        .onInAppPurchaseCompletion { _, result in
            guard case .success(.success(let verification)) = result else { return }
            if case .verified(let t) = verification {
                await model.checkPro(transaction: t)
                await t.finish()
            }
            dismiss()
        }
    }
}

private struct ProLine: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: 26)
            Text(text).font(.system(.body, weight: .medium))
        }
        .foregroundStyle(.white)
    }
}
