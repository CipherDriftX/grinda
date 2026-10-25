import SwiftUI

/// Bo opens the vault: pick an amount and where it goes. Bank or PayPal,
/// from $25, up to $500 a day. Entry credit stays for entries.
struct CashOutSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var cents = 0
    @State private var method: CashOut.Method = .bank
    @State private var working = false
    @State private var done = false
    @State private var error: String?
    @State private var hop = 0

    private var maxCents: Int { min(model.profile.vaultCents, CashOut.dailyLimitCents) }
    private var canCash: Bool { maxCents >= CashOut.minimumCents }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    hero
                    if done {
                        sentCard
                    } else if canCash {
                        amount
                        methods
                        Button {
                            Task { await cashOut() }
                        } label: {
                            if working { ProgressView().tint(.white) } else { Text("Cash out \(Money(cents: cents, currency: model.currency).formatted)") }
                        }
                        .buttonStyle(.primary)
                        .disabled(working || cents < CashOut.minimumCents)
                        Text("Cash-outs are free. Limit \(Money(cents: CashOut.dailyLimitCents, currency: model.currency).formatted) a day. Entry credit can't be cashed out; it's for entries.")
                            .font(.caption)
                            .foregroundStyle(Palette.inkSecondary)
                            .multilineTextAlignment(.center)
                    } else {
                        notYet
                    }
                }
                .padding(20)
            }
            .background(Palette.ground)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .alert("Couldn't cash out", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: { Text(error ?? "") }
            .onAppear { cents = maxCents }
        }
    }

    private var hero: some View {
        ZStack {
            RaysBackground(color: Palette.volt, opacity: done ? 0.22 : 0.0)
                .frame(height: 210)
                .clipped()
            if done { CoinRain(count: 28) }
            VStack(spacing: 6) {
                CharacterView(who: .bo, mood: done ? .cheer : .happy, pose: done ? .cheer : .hold, hop: hop)
                    .frame(width: 140, height: 160)
                    .onTapGesture { hop += 1; Haptics.soft() }
                Text(done ? "On its way" : "Cash out")
                    .font(.system(size: 30, weight: .heavy))
                    .contentTransition(.opacity)
            }
        }
    }

    private var amount: some View {
        VStack(spacing: 12) {
            Text(Money(cents: cents, currency: model.currency).formatted)
                .font(BrandFont.numerals(64))
                .foregroundStyle(Palette.ink)
                .contentTransition(.numericText(value: Double(cents)))
                .animation(Motion.snap, value: cents)
            Text("of \(model.vault.formatted) ready")
                .font(.subheadline)
                .foregroundStyle(Palette.inkSecondary)
            if maxCents > CashOut.minimumCents {
                Slider(value: Binding(
                    get: { Double(cents) },
                    set: { v in
                        let snapped = Int(v / 100) * 100
                        let next = snapped >= maxCents - 99 ? maxCents : max(snapped, CashOut.minimumCents)
                        if next / 500 != cents / 500 { Haptics.tick() }
                        cents = next
                    }
                ), in: Double(CashOut.minimumCents)...Double(maxCents))
                .tint(Palette.cobalt)
                .accessibilityLabel("Amount")
                .accessibilityValue(Money(cents: cents, currency: model.currency).formatted)
                HStack(spacing: 8) {
                    chip(CashOut.minimumCents)
                    if maxCents >= 5_000 { chip(5_000) }
                    chip(maxCents, title: "All")
                }
            }
        }
        .padding(18)
        .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func chip(_ value: Int, title: String? = nil) -> some View {
        Button {
            Haptics.tick()
            cents = value
        } label: {
            Text(title ?? Money(cents: value, currency: model.currency).formatted)
                .font(.system(.subheadline, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(cents == value ? Palette.cobalt : Palette.ground, in: Capsule())
                .foregroundStyle(cents == value ? .white : Palette.ink)
        }
        .buttonStyle(.pressable)
    }

    private var methods: some View {
        VStack(spacing: 10) {
            ForEach(CashOut.Method.allCases) { m in
                Button {
                    Haptics.tick()
                    withAnimation(Motion.snap) { method = m }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: m.symbol)
                            .font(.title3)
                            .frame(width: 30)
                            .foregroundStyle(Palette.cobalt)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.title).font(.system(.headline, weight: .semibold))
                            Text(m.timing).font(.footnote).foregroundStyle(Palette.inkSecondary)
                        }
                        Spacer()
                        Image(systemName: method == m ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(method == m ? Palette.cobalt : Palette.hairline)
                    }
                    .foregroundStyle(Palette.ink)
                    .padding(14)
                    .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(method == m ? Palette.cobalt : .clear, lineWidth: 2)
                    }
                }
                .buttonStyle(.pressable)
                .accessibilityAddTraits(method == m ? .isSelected : [])
            }
        }
    }

    private var sentCard: some View {
        VStack(spacing: 10) {
            Text(Money(cents: cents, currency: model.currency).formatted)
                .font(BrandFont.numerals(56))
            Text("to your \(method.title.lowercased()). \(method.timing).")
                .font(.body)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
            Text("It's in your Vault history with a reference number. If it hasn't landed by then, write to us and a person will chase it.")
                .font(.footnote)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
            Button("Done") { dismiss() }
                .buttonStyle(.primary)
                .padding(.top, 8)
        }
        .padding(18)
        .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    private var notYet: some View {
        VStack(spacing: 10) {
            Text("You can cash out from \(Money(cents: CashOut.minimumCents, currency: model.currency).formatted)")
                .font(.system(.headline, weight: .bold))
            Text("You have \(model.vault.formatted) ready. Split winnings and invite bonuses land here. Until then, they work as entry money for your next purse.")
                .font(.subheadline)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
            Button("See purses") {
                dismiss()
                model.racesMode = .purses
                model.tab = .races
            }
            .buttonStyle(.primary)
            .padding(.top, 6)
        }
        .padding(18)
        .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func cashOut() async {
        working = true
        defer { working = false }
        do {
            try await model.cashOut(cents: cents, method: method)
            withAnimation(Motion.snap) { done = true }
            hop += 1
        } catch {
            self.error = error.localizedDescription
        }
    }
}
