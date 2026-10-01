import SwiftUI

struct RaceDetailView: View {
    let raceID: UUID
    @Environment(AppModel.self) private var model

    private var race: Race? { model.races.first { $0.id == raceID } }

    var body: some View {
        ScrollView {
            if let race {
                VStack(alignment: .leading, spacing: 28) {
                    BibCard(race: race).padding(.top, 8)
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
    }

    private func daysList(_ race: Race) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Day by day").font(.system(.title3, weight: .bold)).padding(.bottom, 8)
            ForEach(Array(race.days.enumerated()), id: \.offset) { i, day in
                HStack {
                    Text("Day \(i + 1)").font(.headline).frame(width: 64, alignment: .leading)
                    Text(day.date.formatted(.dateTime.weekday(.abbreviated).day()))
                        .font(.subheadline).foregroundStyle(Palette.inkSecondary)
                    Spacer()
                    Text(day.state == .upcoming ? "–" : day.steps.formatted())
                        .font(BrandFont.numerals(22, relativeTo: .body))
                        .monospacedDigit()
                    stateIcon(day.state).frame(width: 28)
                }
                .padding(.vertical, 12)
                .accessibilityElement(children: .combine)
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
        let card = race.cardLast4.map { " on the card ending \($0)" } ?? ""
        switch race.stakeState {
        case .held: return "\(stake.formatted) is held\(card). It has not been charged. Finish and the hold disappears."
        case .charged: return "\(stake.formatted) was paid\(card). Finish and it's refunded in full within minutes of settling at \(race.settlesAt.formatted(.dateTime.weekday(.wide).hour().minute()))."
        case .released: return "The \(stake.formatted) hold was released. Nothing was ever charged."
        case .refunded: return "\(stake.formatted) was refunded to your card."
        case .kept: return "\(stake.formatted) was kept for this race. Every missed stake is shown in your Wallet."
        case .none: return ""
        }
    }
}
