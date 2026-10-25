import SwiftUI

// MARK: - Invite

/// Use a friend's code, or share yours. One code per account.
struct InviteSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var working = false
    @State private var error: String?
    @State private var shake = 0
    @State private var redeemed = false
    @FocusState private var focused: Bool

    private var bonus: Money { Money(cents: Invite.newMemberCreditCents, currency: model.currency) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    ZStack {
                        RaysBackground(color: Palette.cobalt, opacity: 0.1)
                            .frame(height: 200)
                            .clipped()
                        if redeemed { ConfettiBurst(count: 60) }
                        HStack(alignment: .bottom, spacing: -10) {
                            CharacterView(who: .dash, mood: .cheer, pose: redeemed ? .cheer : .wave, hop: redeemed ? 1 : 0)
                                .frame(width: 110, height: 128)
                            SteppieView(mood: redeemed ? .roar : .happy, pose: redeemed ? .flex : .wave, mane: model.maneLevel, shoes: model.wearing, hop: redeemed ? 1 : 0)
                                .frame(height: 180)
                        }
                    }
                    VStack(spacing: 6) {
                        Text(redeemed ? "\(bonus.formatted) is yours" : "Got a friend's code?")
                            .font(.system(size: 30, weight: .heavy))
                            .foregroundStyle(Palette.ink)
                            .contentTransition(.opacity)
                        Text(redeemed
                             ? "It's in your Vault as entry credit. Use it on any purse."
                             : "Enter it for \(bonus.formatted) of entry credit. Your friend gets \(bonus.formatted) when you join your first purse.")
                            .font(.body)
                            .foregroundStyle(Palette.inkSecondary)
                            .multilineTextAlignment(.center)
                    }

                    if let used = model.profile.invitedBy, !redeemed {
                        Label("You joined with code \(used)", systemImage: "checkmark.seal.fill")
                            .font(.system(.headline, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                            .padding(14)
                            .frame(maxWidth: .infinity)
                            .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    } else if !redeemed {
                        VStack(spacing: 12) {
                            TextField("SAM-4821", text: $code)
                                .font(BrandFont.numerals(30, relativeTo: .title))
                                .multilineTextAlignment(.center)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .focused($focused)
                                .submitLabel(.go)
                                .onSubmit { Task { await redeem() } }
                                .padding(.vertical, 14)
                                .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(error == nil ? Palette.hairline : Palette.risk, lineWidth: 1.5)
                                }
                                .modifier(Shake(animatableData: CGFloat(shake)))
                                .accessibilityLabel("Friend's code")
                            if let error {
                                Text(error)
                                    .font(.footnote)
                                    .foregroundStyle(Palette.risk)
                            }
                            Button {
                                Task { await redeem() }
                            } label: {
                                if working { ProgressView().tint(.white) } else { Text("Use code") }
                            }
                            .buttonStyle(.primary)
                            .disabled(code.count < 4 || working)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your code").font(.system(.headline, weight: .bold))
                        HStack {
                            Text(model.inviteCode)
                                .font(BrandFont.numerals(26, relativeTo: .title2))
                            Spacer()
                            ShareLink(item: "Walk with me on Steppie. Use my code \(model.inviteCode) and get \(bonus.formatted) to start.") {
                                Label("Share", systemImage: "square.and.arrow.up")
                                    .font(.system(.subheadline, weight: .bold))
                            }
                            .frame(minHeight: 44)
                        }
                        RuleLine(symbol: "gift", text: "Friends get \(bonus.formatted) of entry credit when they sign up with your code.")
                        RuleLine(symbol: "banknote", text: "You get \(Money(cents: Invite.inviterBonusCents, currency: model.currency).formatted) in your Vault after their first paid purse entry. No limit.")
                        RuleLine(symbol: "exclamationmark.shield", text: "One account per person. Codes used on your own second account are removed with the bonus.")
                    }
                    .padding(16)
                    .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(20)
            }
            .background(Palette.ground)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }

    private func redeem() async {
        working = true
        defer { working = false }
        do {
            try await model.redeemInvite(code)
            focused = false
            withAnimation(Motion.snap) { redeemed = true; error = nil }
        } catch {
            Haptics.warning()
            withAnimation(Motion.standard) { self.error = error.localizedDescription; shake += 1 }
        }
    }
}

// MARK: - Paid to Post

/// Post about your walk, send the link, get paid for real views.
struct PaidToPostSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var views = 25_000.0
    @State private var platform = "TikTok"
    @State private var link = ""
    @State private var working = false
    @State private var sent = false
    @State private var error: String?

    private static let platforms = ["TikTok", "Instagram", "YouTube", "X"]
    private static let stops: [Double] = [1_000, 5_000, 10_000, 25_000, 50_000, 100_000, 250_000, 600_000, 1_000_000]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    hero
                    calculator
                    rules
                    submit
                }
                .padding(20)
            }
            .background(Palette.ground)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            CharacterView(who: .pip, mood: .cheer, pose: .point, hop: sent ? 1 : 0)
                .frame(width: 130, height: 150)
            Text("Get paid to post")
                .font(.system(size: 30, weight: .heavy))
            Text("Film your walk, your bib, your split. Post it anywhere. We pay $1 for every 1,000 real views, up to $600 a post.")
                .font(.body)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var calculator: some View {
        let v = Int(views)
        let earned = PaidToPost.earnings(views: v)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(v.formatted(.number.notation(.compactName))) VIEWS")
                        .font(BrandFont.label(12))
                        .foregroundStyle(.white.opacity(0.75))
                        .contentTransition(.numericText())
                    CountingMoney(cents: Double(earned.cents), currency: earned.currency, font: BrandFont.numerals(56), color: .white)
                }
                Spacer()
                if earned.cents >= PaidToPost.capPerPostCents {
                    Text("MAX")
                        .font(BrandFont.label(12))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Palette.volt, in: Capsule())
                        .foregroundStyle(Palette.onVolt)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            Slider(value: Binding(
                get: { Double(Self.stops.firstIndex { $0 >= views } ?? 0) },
                set: { i in
                    let next = Self.stops[min(max(Int(i.rounded()), 0), Self.stops.count - 1)]
                    if next != views { Haptics.tick() }
                    withAnimation(Motion.standard) { views = next }
                }
            ), in: 0...Double(Self.stops.count - 1), step: 1)
            .tint(Palette.volt)
            .accessibilityLabel("Views")
            .accessibilityValue("\(v.formatted()) views pays \(earned.formatted)")
            Text("Slide to see what a post pays.")
                .font(.caption)
                .foregroundStyle(Palette.onFieldSecondary)
        }
        .padding(18)
        .background {
            ZStack {
                Palette.field
                RaysBackground(opacity: 0.05)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var rules: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How it works").font(.system(.title3, weight: .bold))
            RuleLine(symbol: "video", text: "Show Steppie on screen and tag #steppie. Your own walk, your own face or voice.")
            RuleLine(symbol: "clock", text: "Send the link within 7 days of posting. We count views 14 days after you post.")
            RuleLine(symbol: "person.fill.checkmark", text: "A person checks every post. Bought views and reposts of other people's videos don't count.")
            RuleLine(symbol: "banknote", text: "Money goes to your Vault. Cash it out from $25.")
        }
    }

    private var submit: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Send your post").font(.system(.title3, weight: .bold))
            Picker("Platform", selection: $platform) {
                ForEach(Self.platforms, id: \.self) { Text($0) }
            }
            .pickerStyle(.segmented)
            TextField("https://", text: $link)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(error == nil ? Palette.hairline : Palette.risk, lineWidth: 1)
                }
                .accessibilityLabel("Link to your post")
            if let error {
                Text(error).font(.footnote).foregroundStyle(Palette.risk)
            }
            if sent {
                Label("Sent. We'll count the views and pay your Vault.", systemImage: "checkmark.circle.fill")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x1F7A52))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            Button {
                Task { await send() }
            } label: {
                if working { ProgressView().tint(.white) } else { Text(sent ? "Send another" : "Send link") }
            }
            .buttonStyle(.primary)
            .disabled(link.count < 10 || working)
        }
    }

    private func send() async {
        working = true
        defer { working = false }
        do {
            try await model.submitPost(url: link, platform: platform)
            withAnimation(Motion.snap) { sent = true; error = nil; link = "" }
        } catch {
            Haptics.warning()
            withAnimation(Motion.standard) { self.error = error.localizedDescription }
        }
    }
}
