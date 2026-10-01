import SwiftUI

struct RacesView: View {
    @Environment(AppModel.self) private var model

    private var featured: RaceTemplate { RaceTemplate.board[0] }
    private var others: [RaceTemplate] { Array(RaceTemplate.board.dropFirst()) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if Walktober.isOn() { WalktoberBanner() }
                    if !model.liveRaces.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Running now").font(.system(.title3, weight: .bold))
                            ForEach(model.liveRaces) { race in
                                NavigationLink(value: race) { BibCard(race: race, compact: true) }
                                    .buttonStyle(.pressable)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Start here").font(.system(.title3, weight: .bold))
                        NavigationLink(value: featured) { FeaturedRace(template: featured) }
                            .buttonStyle(.pressable)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        Text("The board").font(.system(.title3, weight: .bold)).padding(.bottom, 8)
                        ForEach(Array(others.enumerated()), id: \.element.id) { i, t in
                            NavigationLink(value: t) { BoardRow(template: t) }
                                .buttonStyle(.pressable)
                            if i < others.count - 1 { Divider().overlay(Palette.hairline) }
                        }
                        Button { model.showingPaywall = true } label: {
                            BoardRow(template: nil)
                        }
                        .buttonStyle(.pressable)
                    }

                    if !model.finishedRaces.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Finished").font(.system(.title3, weight: .bold))
                            ForEach(model.finishedRaces) { race in FinishedRow(race: race) }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(Palette.ground)
            .navigationTitle("Races")
            .navigationDestination(for: RaceTemplate.self) { ContractView(template: $0) }
            .navigationDestination(for: Race.self) { RaceDetailView(raceID: $0.id) }
        }
    }
}

/// The 5-Day Sprint is the front door: a hold, never a charge, if you finish.
private struct FeaturedRace: View {
    let template: RaceTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(template.name)
                    .font(.system(.title, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Text(template.goalLabel)
                    .font(BrandFont.numerals(44))
                    .foregroundStyle(.white)
            }
            Text(template.tagline)
                .font(.body)
                .foregroundStyle(Palette.onFieldSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                Text("Card hold only. Released the moment you finish.")
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white.opacity(0.14), in: Capsule())
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                Palette.field
                TrackShape(inset: -40)
                    .stroke(.white.opacity(0.08), lineWidth: 26)
                    .offset(x: 120, y: 30)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .multilineTextAlignment(.leading)
    }
}

private struct BoardRow: View {
    let template: RaceTemplate?

    var body: some View {
        HStack(spacing: 16) {
            Text(template?.goalLabel ?? "+")
                .font(BrandFont.numerals(34))
                .foregroundStyle(template == nil ? Palette.cobalt : Palette.ink)
                .frame(width: 62, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(template?.name ?? "Build your own")
                        .font(.system(.headline, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                    if template == nil || template?.isPro == true { ProBadge() }
                }
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkSecondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.inkSecondary)
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private var detail: String {
        guard let t = template else { return "Any goal, any length, friends welcome." }
        let days = t.schedule == .weekends ? "\(t.days / 2) weekends" : "\(t.days) days"
        let money = t.kind == .practice ? "free" : "from \(Money(units: t.suggestedStakes.first ?? 5).formatted)"
        let grace = t.graceDays > 0 ? " · \(t.graceDays) grace day\(t.graceDays > 1 ? "s" : "")" : ""
        return "\(t.dailyGoal.formatted()) a day · \(days) · \(money)\(grace)"
    }
}

struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(BrandFont.label(11))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Palette.cobalt, in: RoundedRectangle(cornerRadius: 4))
    }
}

private struct FinishedRow: View {
    let race: Race

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: race.status == .won ? "flag.checkered" : "xmark.circle")
                .font(.title3)
                .foregroundStyle(race.status == .won ? Palette.cobalt : Palette.inkSecondary)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(race.name).font(.headline).foregroundStyle(Palette.ink)
                Text("\(race.hitCount)/\(race.days.count) days · \(race.totalSteps.formatted()) steps")
                    .font(.subheadline).foregroundStyle(Palette.inkSecondary)
            }
            Spacer()
            Text(outcome)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(race.status == .won ? Palette.ink : Palette.inkSecondary)
        }
        .padding(14)
        .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var outcome: String {
        guard let stake = race.stake else { return race.status == .won ? "Finished" : "Missed" }
        return race.status == .won ? "\(stake.formatted) back" : "\(stake.formatted) kept"
    }
}
