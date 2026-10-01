import SwiftUI
import StoreKit

/// Shelly's locker. A Shield covers one missed day in a staked race; up to two
/// per race (Duolingo found two streak freezes beat one, and three beat two by
/// nothing). Unused Shields come back after the race, so a Shield is only ever
/// spent on a day it actually saved.
struct ShieldShopView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var products: [Product] = []
    @State private var buying: String?
    @State private var hop = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    ZStack {
                        RaysBackground(color: Color(hex: 0x45B983), opacity: 0.12)
                            .frame(height: 220)
                            .clipped()
                        CharacterView(who: .shelly, mood: .cheer, pose: .cheer, hop: hop)
                            .frame(height: 210)
                    }
                    VStack(spacing: 6) {
                        Text("Shelly's Shields")
                            .font(.system(size: 32, weight: .heavy))
                            .foregroundStyle(Palette.ink)
                        Text("Slow and steady. One Shield covers one missed day in a staked race.")
                            .font(.body)
                            .foregroundStyle(Palette.inkSecondary)
                            .multilineTextAlignment(.center)
                    }
                    locker
                    VStack(spacing: 12) {
                        if products.isEmpty {
                            offer(id: "steppie.shield.1", title: "1 Shield", price: model.isDemo ? "€1.99" : "…", badge: nil)
                            offer(id: "steppie.shield.3", title: "3 Shields", price: model.isDemo ? "€4.99" : "…", badge: "SAVE 16%")
                        } else {
                            ForEach(products, id: \.id) { p in
                                offer(id: p.id, title: p.displayName, price: p.displayPrice, badge: p.id.hasSuffix(".3") ? "BEST VALUE" : nil)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        PrivacyLine(symbol: "shield.lefthalf.filled", text: "Equip up to 2 on any staked race when you pin your bib.")
                        PrivacyLine(symbol: "arrow.uturn.backward", text: "Didn't need it? It goes back to your locker.")
                        PrivacyLine(symbol: "checkmark.seal", text: "Shields never change your stake. They only cover a missed day.")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
            }
            .background(Palette.ground)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .task { products = await StoreService.shieldProducts() }
        }
    }

    private var locker: some View {
        HStack(spacing: 14) {
            ForEach(0..<max(model.profile.shields, 3), id: \.self) { i in
                Image(systemName: i < model.profile.shields ? "shield.lefthalf.filled" : "shield")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(i < model.profile.shields ? Color(hex: 0x2E9E6B) : Palette.hairline)
                    .symbolEffect(.bounce, value: model.profile.shields)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .topLeading) {
            Text("IN YOUR LOCKER: \(model.profile.shields)")
                .font(BrandFont.label(11)).kerning(0.6)
                .foregroundStyle(Palette.inkSecondary)
                .padding(10)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(model.profile.shields) Shields in your locker")
    }

    private func offer(id: String, title: String, price: String, badge: String?) -> some View {
        Button {
            guard let p = products.first(where: { $0.id == id }) else { return }
            buying = id
            Task {
                await model.buyShields(p)
                buying = nil
                hop += 1
            }
        } label: {
            HStack(spacing: 14) {
                HStack(spacing: -10) {
                    ForEach(0..<(id.hasSuffix(".3") ? 3 : 1), id: \.self) { _ in
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Color(hex: 0x2E9E6B))
                            .background(Circle().fill(Palette.tyvek).frame(width: 34, height: 34))
                    }
                }
                .frame(width: 70, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(.headline, weight: .bold)).foregroundStyle(Palette.ink)
                    if let badge {
                        Text(badge).font(BrandFont.label(11)).foregroundStyle(Palette.onVolt)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Palette.volt, in: Capsule())
                    }
                }
                Spacer()
                if buying == id {
                    ProgressView()
                } else {
                    Text(price)
                        .font(.system(.headline, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16).frame(height: 40)
                        .background(Color(hex: 0x2E9E6B), in: Capsule())
                }
            }
            .padding(14)
            .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.pressable)
        .disabled(buying != nil)
    }
}
