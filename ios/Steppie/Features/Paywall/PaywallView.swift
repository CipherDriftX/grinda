import SwiftUI
import StoreKit

/// Steppie Pro. Native SubscriptionStoreView with our own marketing header.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss

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
                    ProLine(symbol: "shield.lefthalf.filled", text: "2 Shields in your locker every month")
                    ProLine(symbol: "slider.horizontal.3", text: "Build your own races: any goal, any length")
                    ProLine(symbol: "square.stack.3d.up", text: "Run up to 3 races at once")
                    ProLine(symbol: "person.2", text: "Race friends, each on your own stake")
                    ProLine(symbol: "chart.xyaxis.line", text: "Pace, best hours and weight projection")
                    ProLine(symbol: "app.badge", text: "The Stride S icon for your home screen")
                }
                Text("Pro is more ways to finish. Every stake still comes back in full when you do.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.onFieldSecondary)
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
        .onInAppPurchaseCompletion { _, result in
            if case .success(.success) = result { dismiss() }
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
