import SwiftUI

/// Crew: the people side. The weekly league, bringing friends, getting paid
/// to post, who got paid lately, and the bench count (never names).
struct CrewView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    LeagueSection()
                        .arrive(0)
                    InviteCard()
                        .arrive(1)
                    PaidToPostCard()
                        .arrive(2)
                    if !model.payoutFeed.isEmpty {
                        PayoutsList(events: model.payoutFeed)
                            .arrive(3)
                    }
                    if model.benchTotal > 0 {
                        BenchNote(count: model.benchTotal)
                    }
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(Palette.ground)
            .navigationTitle("Crew")
            .task { if model.payoutFeed.isEmpty { await model.loadPurses() } }
            .refreshable {
                await model.loadLeague()
                await model.loadPurses()
            }
        }
    }
}

// MARK: - Invite

/// Your code printed like a bib, $5 each way.
struct InviteCard: View {
    @Environment(AppModel.self) private var model
    @State private var copied = false

    private var bonus: Money { Money(cents: Invite.inviterBonusCents, currency: model.currency) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("GIVE \(bonus.formatted), GET \(bonus.formatted)")
                        .font(BrandFont.label(12))
                        .kerning(1.2)
                        .foregroundStyle(Palette.cobalt)
                    Text("Walk with a friend")
                        .font(.system(.title2, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                    Text("They get \(bonus.formatted) of entry credit. You get \(bonus.formatted) when they join their first purse.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                CharacterView(who: .dash, mood: .wink, pose: .point, hop: copied ? 1 : 0)
                    .frame(width: 64, height: 74)
            }

            Button(action: copy) {
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("YOUR CODE")
                            .font(BrandFont.label(10))
                            .foregroundStyle(Palette.inkSecondary)
                        Text(model.inviteCode)
                            .font(BrandFont.numerals(34, relativeTo: .title))
                            .foregroundStyle(Palette.ink)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                    }
                    Spacer()
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(Palette.cobalt)
                        .contentTransition(.symbolEffect(.replace))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Palette.hairline, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                }
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Your code \(model.inviteCode). Copy")

            HStack(spacing: 10) {
                ShareLink(item: shareText) {
                    Label("Share code", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary)
                Button("Have a code?") { model.showingInvite = true }
                    .font(.system(.subheadline, weight: .semibold))
                    .frame(minHeight: 44)
                    .padding(.horizontal, 8)
            }

            if model.profile.invitesPaid > 0 {
                let earned = Money(cents: model.profile.invitesPaid * Invite.inviterBonusCents, currency: model.currency)
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(Palette.cobalt)
                    Text("\(model.profile.invitesPaid) friend\(model.profile.invitesPaid == 1 ? "" : "s") joined · \(earned.formatted) to your Vault")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                }
            }
        }
        .padding(18)
        .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(alignment: .topLeading) { SafetyPin().offset(x: 10, y: 10) }
        .overlay(alignment: .topTrailing) { SafetyPin().scaleEffect(x: -1).offset(x: -10, y: 10) }
    }

    private var shareText: String {
        "I walk for money on Steppie. Join a purse, walk every day, split it with everyone who finishes. Use my code \(model.inviteCode) and get \(bonus.formatted) to start."
    }

    private func copy() {
        UIPasteboard.general.string = model.inviteCode
        Haptics.tick()
        withAnimation(Motion.snap) { copied = true }
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(Motion.standard) { copied = false }
        }
    }
}

// MARK: - Paid to Post

struct PaidToPostCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button { model.showingPaidToPost = true } label: {
            HStack(spacing: 14) {
                CharacterView(who: .pip, mood: .cheer, pose: .point)
                    .frame(width: 70, height: 80)
                VStack(alignment: .leading, spacing: 4) {
                    Text("PAID TO POST")
                        .font(BrandFont.label(11))
                        .kerning(1.2)
                        .foregroundStyle(Palette.volt)
                    Text("Post your walk. Get paid for views.")
                        .font(.system(.headline, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                    Text("$1 for every 1,000 views, up to $600 a post.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.onFieldSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Palette.onFieldSecondary)
            }
            .padding(16)
            .background {
                ZStack {
                    Palette.field
                    RaysBackground(opacity: 0.05)
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .buttonStyle(.pressable)
    }
}

// MARK: - Payouts

/// Who got paid lately. First names only, real settled purses (sample in demo).
struct PayoutsList: View {
    let events: [PayoutEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Paid out lately")
                    .font(.system(.title3, weight: .bold))
                Spacer()
                LiveTag(color: Color(hex: 0x1F9E5B), label: "LIVE")
            }
            VStack(spacing: 0) {
                ForEach(Array(events.prefix(8).enumerated()), id: \.element.id) { i, e in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: avatar(e.name)))
                            .frame(width: 34, height: 34)
                            .overlay(Text(String(e.name.prefix(1))).font(.system(.subheadline, weight: .bold)).foregroundStyle(.white))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(e.name).font(.system(.body, weight: .semibold))
                            Text("\(e.purseName) · \(e.at.formatted(.relative(presentation: .named)))")
                                .font(.footnote)
                                .foregroundStyle(Palette.inkSecondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(e.amount.formatted)
                                .font(BrandFont.numerals(18, relativeTo: .body))
                                .foregroundStyle(Palette.ink)
                            Text("+\(e.profit.formatted) profit")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color(hex: 0x1F7A52))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .accessibilityElement(children: .combine)
                    if i < min(events.count, 8) - 1 {
                        Divider().overlay(Palette.hairline).padding(.leading, 58)
                    }
                }
            }
            .padding(.vertical, 4)
            .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func avatar(_ name: String) -> UInt32 {
        let palette: [UInt32] = [0x7C5CFF, 0x22B37A, 0xFF9A3C, 0x3D8BFF, 0xE0457B, 0x0E9AA7, 0xA86F42]
        return palette[name.unicodeScalars.reduce(0) { $0 + Int($1.value) } % palette.count]
    }
}

/// Accounts removed for fake steps. A number, never a list of names.
struct BenchNote: View {
    let count: Int

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "hand.raised.fill")
                .font(.title3)
                .foregroundStyle(Palette.inkSecondary)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(count.formatted()) on the bench")
                    .font(.system(.subheadline, weight: .bold))
                Text("Accounts removed for fake steps (shakers, step apps, borrowed phones). Their entries stay in the purse for the people who walked. We never post who.")
                    .font(.footnote)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.tyvek.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
