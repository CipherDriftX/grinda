import SwiftUI

/// Bo opens the vault: pick an amount, Whop pays it. From 5, up to 500 a
/// day. Entry credit stays for entries.
struct CashOutSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var cents = 0
    @State private var working = false
    @State private var receipt: CashOut.Receipt?
    @State private var error: String?
    @State private var hop = 0

    private var done: Bool { receipt != nil }

    private var maxCents: Int { min(model.profile.vaultCents, CashOut.dailyLimitCents) }
    private var canCash: Bool { maxCents >= CashOut.minimumCents }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    hero
                    if let receipt {
                        sentCard(receipt)
                    } else if canCash {
                        amount
                        howItsPaid
                        Button {
                            Task { await cashOut() }
                        } label: {
                            if working { ProgressView().tint(.white) } else { Text("Cash out \(Money(cents: cents, currency: model.currency).formatted)") }
                        }
                        .buttonStyle(.primary)
                        .disabled(working || cents < CashOut.minimumCents)
                        Text("Steppie takes no fee on cash-outs. Limit \(Money(cents: CashOut.dailyLimitCents, currency: model.currency).formatted) a day. Entry credit can't be cashed out; it's for entries.")
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

    private var howItsPaid: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "arrow.up.forward.app.fill")
                .font(.title3)
                .frame(width: 30)
                .foregroundStyle(Palette.cobalt)
            VStack(alignment: .leading, spacing: 4) {
                Text("Paid through Whop").font(.system(.headline, weight: .semibold))
                Text("It goes to the Whop account you paid an entry with. From Whop you withdraw it to your bank. Haven't paid by card yet? You get a link to claim it on Whop.")
                    .font(.footnote)
                    .foregroundStyle(Palette.inkSecondary)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(Palette.ink)
        .padding(14)
        .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func sentCard(_ r: CashOut.Receipt) -> some View {
        VStack(spacing: 10) {
            Text(r.amount.formatted)
                .font(BrandFont.numerals(56))
            Text(note(r))
            .font(.body)
            .foregroundStyle(Palette.inkSecondary)
            .multilineTextAlignment(.center)
            if let url = r.claimURL, !r.delayed {
                Link(destination: url) {
                    Text("Claim it on Whop").frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary)
                .padding(.top, 8)
            }
            Text("It's in your Vault history. If something looks wrong, write to support and a person will chase it.")
                .font(.footnote)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
            if r.claimURL == nil || r.delayed {
                Button("Done") { dismiss() }
                    .buttonStyle(.primary)
                    .padding(.top, 8)
            } else {
                Button("Done") { dismiss() }
                    .font(.headline)
                    .padding(.top, 8)
            }
        }
        .padding(18)
        .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    private func note(_ r: CashOut.Receipt) -> String {
        if r.delayed {
            return "Whop didn't answer just now. The money has left your Vault and we keep trying for about a day. If it still fails, it comes back to your Vault."
        }
        guard r.method == .claimLink else { return "Sent to your Whop account. Withdraw it from Whop to your bank." }
        let until = r.claimExpiresAt.map { " It works until \($0.formatted(date: .abbreviated, time: .shortened))." } ?? ""
        return "Open the link and sign in to Whop to claim it.\(until) Unclaimed, it comes back to your Vault."
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
            let r = try await model.cashOut(cents: cents)
            withAnimation(Motion.snap) { receipt = r }
            hop += 1
        } catch {
            self.error = error.localizedDescription
        }
    }
}
