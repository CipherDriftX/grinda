import SwiftUI

struct RaceDetailView: View {
    let raceID: UUID
    @Environment(AppModel.self) private var model
    @State private var disputing: DayRecord?

    private var race: Race? { model.races.first { $0.id == raceID } }

    var body: some View {
        ScrollView {
            if let race {
                VStack(alignment: .leading, spacing: 28) {
                    BibCard(race: race).padding(.top, 8)
                    if let ticket = race.purse, let p = model.purse(ticket.purseID) {
                        NavigationLink(value: p) {
                            HStack {
                                Label("See \(p.name) live", systemImage: "chart.bar.xaxis")
                                    .font(.system(.headline, weight: .semibold))
                                Spacer()
                                Text(p.pot.formatted).font(BrandFont.numerals(18, relativeTo: .body))
                                Image(systemName: "chevron.right").font(.footnote.weight(.bold))
                            }
                            .foregroundStyle(Palette.ink)
                            .padding(14)
                            .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.pressable)
                    }
                    daysList(race)
                    moneyStatus(race)
                    ShareLink(item: ShareCardRenderer.image(for: race, stepsToday: model.todaySteps),
                              preview: SharePreview("\(race.name) on Steppie", image: ShareCardRenderer.image(for: race, stepsToday: model.todaySteps))) {
                        Label("Share your bib", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.primary)
                }
                .padding(16)
                .padding(.bottom, 24)
            }
        }
        .background(Palette.ground)
        .navigationTitle(race?.name ?? "Race")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $disputing) { day in
            if let race { DisputeSheet(race: race, day: day) }
        }
    }

    private func daysList(_ race: Race) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Day by day").font(.system(.title3, weight: .bold)).padding(.bottom, 8)
            ForEach(Array(race.days.enumerated()), id: \.offset) { i, day in
                HStack {
                    Text("Day \(i + 1)").font(.headline).frame(width: 64, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(day.date.formatted(.dateTime.weekday(.abbreviated).day()))
                            .font(.subheadline).foregroundStyle(Palette.inkSecondary)
                        if !race.isPractice, day.state != .upcoming, let at = day.syncedAt {
                            Text("Synced \(at.formatted(date: .omitted, time: .shortened))")
                                .font(.caption2).foregroundStyle(Palette.inkSecondary)
                        }
                    }
                    Spacer()
                    Text(day.state == .upcoming ? "–" : day.steps.formatted())
                        .font(BrandFont.numerals(22, relativeTo: .body))
                        .monospacedDigit()
                    stateIcon(day.state).frame(width: 28)
                }
                .padding(.vertical, 12)
                .accessibilityElement(children: .combine)
                if day.state == .missed && race.settledAt == nil {
                    Button { disputing = day } label: {
                        Label("Walked it but it didn't sync? Send proof", systemImage: "camera.viewfinder")
                            .font(.system(.footnote, weight: .semibold))
                    }
                    .frame(minHeight: 44, alignment: .leading)
                    .padding(.top, -6)
                }
                if day.state == .review {
                    Text("A person is checking your screenshot. You stay in until they answer, usually within a few hours.")
                        .font(.footnote)
                        .foregroundStyle(Palette.inkSecondary)
                        .padding(.bottom, 10)
                        .padding(.top, -6)
                }
                if i < race.days.count - 1 { Divider().overlay(Palette.hairline) }
            }
        }
    }

    @ViewBuilder private func stateIcon(_ s: DayState) -> some View {
        switch s {
        case .hit: Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.cobalt)
        case .missed: Image(systemName: "xmark.circle").foregroundStyle(Palette.risk)
        case .graced: Image(systemName: "bandage").foregroundStyle(Palette.inkSecondary)
        case .today: Image(systemName: "circle.dotted").foregroundStyle(Palette.cobalt)
        case .review: Image(systemName: "hourglass").foregroundStyle(Palette.inkSecondary)
        case .upcoming: Image(systemName: "circle").foregroundStyle(Palette.hairline)
        }
    }

    private func moneyStatus(_ race: Race) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your money").font(.system(.title3, weight: .bold))
            Text(moneyText(race))
                .font(.body)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func moneyText(_ race: Race) -> String {
        guard let stake = race.stake else { return "This is a practice lap. No money involved." }
        if let ticket = race.purse {
            if let payout = ticket.payoutCents {
                let m = Money(cents: payout, currency: stake.currency)
                return payout > 0
                    ? "You finished. Your split of \(m.formatted) went to your Vault. \(ticket.finishers.map { "\($0.formatted()) people finished." } ?? "")"
                    : "You missed a day, so your \(stake.formatted) entry stayed in the purse for the finishers."
            }
            return "Your \(stake.formatted) entry is in the purse. Finish every day and you split the whole purse with every other finisher. It settles \(race.settlesAt.formatted(.dateTime.weekday(.wide).hour())), a day after the last day closes."
        }
        switch race.stakeState {
        case .held: return "\(stake.formatted) is held on your card. It has not been charged."
        case .charged: return "\(stake.formatted) is paid. Finish and all of it comes back when the race settles, \(race.settlesAt.formatted(.dateTime.weekday(.wide).hour().minute())): the card part to your card, the Vault part to your Vault."
        case .released: return "The \(stake.formatted) hold was released. Nothing was ever charged."
        case .refunded: return "\(stake.formatted) was refunded to your card."
        case .returned: return "\(stake.formatted) came back: card payments to your card, the rest to your Vault."
        case .kept: return "\(stake.formatted) was kept for this race. Every missed stake is shown in your Vault."
        case .none: return race.status == .pendingPayment ? "Waiting for your payment to land." : ""
        }
    }
}
