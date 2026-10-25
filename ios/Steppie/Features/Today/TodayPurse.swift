import SwiftUI

/// Under your bib when it's a purse: the purse right now, who's still in,
/// where you stand, and the clock on today.
struct PurseLiveStrip: View {
    let race: Race
    @Environment(AppModel.self) private var model

    var body: some View {
        if let ticket = race.purse, let p = model.purse(ticket.purseID) {
            let me = model.purseBoards[p.id]?.first(where: \.isMe)
            let left = max((race.today?.goal ?? p.dailyGoal) - (race.today?.steps ?? 0), 0)
            NavigationLink(value: p) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        LiveTag(color: Palette.risk, label: "LIVE")
                            .foregroundStyle(Palette.ink)
                        Text("Day \(p.dayNumber ?? 1) of \(p.days)")
                            .font(BrandFont.label(12))
                            .foregroundStyle(Palette.inkSecondary)
                        Spacer()
                        Countdown(to: model.dayClosesAt, prefix: left > 0 ? "Day closes in" : "Done today ·",
                                  font: .system(.footnote, weight: .bold))
                            .foregroundStyle(left > 0 && model.dayClosesAt.timeIntervalSinceNow < 4 * 3600 ? Palette.risk : Palette.ink)
                    }
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("THE PURSE")
                                .font(BrandFont.label(10))
                                .foregroundStyle(Palette.inkSecondary)
                            Text(p.pot.formatted)
                                .font(BrandFont.numerals(34, relativeTo: .title))
                                .foregroundStyle(Palette.ink)
                                .contentTransition(.numericText())
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 0) {
                            Text("YOUR SPLIT NOW")
                                .font(BrandFont.label(10))
                                .foregroundStyle(Palette.inkSecondary)
                            Text(p.livePayout.formatted)
                                .font(BrandFont.numerals(24, relativeTo: .title3))
                                .foregroundStyle(Color(hex: 0x1F7A52))
                                .contentTransition(.numericText())
                        }
                    }
                    StillInBar(entrants: p.entrants, stillIn: p.stillIn, onPace: p.onPace, height: 10)
                    HStack {
                        Text("\(p.stillIn.formatted()) of \(p.entrants.formatted()) still in")
                        Spacer()
                        if let me { Text("You're #\(me.rank.formatted())") }
                    }
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(Palette.inkSecondary)
                    if left > 0 {
                        Text("\(left.formatted()) steps to stay in today.")
                            .font(.system(.subheadline, weight: .bold))
                            .foregroundStyle(Palette.ink)
                    }
                }
                .padding(16)
                .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .leading) {
                    UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 16)
                        .fill(Color(hex: p.art.color))
                        .frame(width: 6)
                }
            }
            .buttonStyle(.pressable)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens the live purse")
        }
    }
}

/// Pro runs up to five at once. The rest show here as slim rows.
struct AlsoRunning: View {
    let races: [Race]

    var body: some View {
        if !races.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Also running").font(.system(.headline, weight: .bold))
                ForEach(races) { r in
                    NavigationLink(value: r) {
                        HStack(spacing: 12) {
                            Image(systemName: r.isPurse ? "banknote.fill" : "figure.walk")
                                .foregroundStyle(Palette.cobalt)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.name).font(.system(.subheadline, weight: .semibold))
                                Text("\((r.today?.steps ?? 0).formatted()) of \(r.dailyGoal.formatted()) today")
                                    .font(.footnote)
                                    .foregroundStyle(Palette.inkSecondary)
                            }
                            Spacer()
                            ProgressRing(progress: r.today?.progress ?? 0)
                                .frame(width: 28, height: 28)
                        }
                        .foregroundStyle(Palette.ink)
                        .padding(12)
                        .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
    }
}

private struct ProgressRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle().stroke(Palette.hairline, lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(progress >= 1 ? Palette.volt : Palette.cobalt, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .accessibilityHidden(true)
    }
}

/// No purse yet: the biggest open one, as a banknote you can tap.
struct PurseTeaser: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let p = model.openPurses.first {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Biggest purse this week").font(.system(.headline, weight: .bold))
                    Spacer()
                    Button("All purses") {
                        model.racesMode = .purses
                        model.tab = .races
                    }
                    .font(.system(.subheadline, weight: .semibold))
                    .frame(minHeight: 44)
                }
                NavigationLink(value: p) {
                    PurseNote(purse: p, compact: true)
                }
                .buttonStyle(.pressable)
            }
        }
    }
}
