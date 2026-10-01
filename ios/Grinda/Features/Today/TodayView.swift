import SwiftUI
import Charts

struct TodayView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    TodayField()
                    GrinRow()
                        .padding(.horizontal, 16)
                        .padding(.top, -40)
                    VStack(alignment: .leading, spacing: 28) {
                        if let race = model.primaryRace {
                            NavigationLink(value: race) {
                                BibCard(race: race)
                            }
                            .buttonStyle(.pressable)
                            .arrive(1)
                        } else {
                            EnterRaceCard().arrive(1)
                        }
                        HourlyChart(hourly: model.todayHourly).arrive(2)
                        CoachNote().arrive(3)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .background(Palette.ground)
            .ignoresSafeArea(edges: .top)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Race.self) { RaceDetailView(raceID: $0.id) }
            .refreshable { await model.refresh() }
        }
    }
}

/// The cobalt field: today's steps as laps on a track.
private struct TodayField: View {
    @Environment(AppModel.self) private var model

    private var remaining: Int { max(model.todayGoal - model.todaySteps, 0) }
    private var behindPacer: Int {
        Int(Double(model.todayGoal) * model.pacerFraction) - model.todaySteps
    }

    var body: some View {
        VStack(spacing: 20) {
            topBar
            ZStack {
                TrackView(steps: model.todaySteps, goal: model.todayGoal, pacer: model.pacerFraction)
                infield
            }
            .frame(height: 236)
            summary
        }
        .padding(.horizontal, 16)
        .padding(.top, 62)
        .padding(.bottom, 48)
        .background(Palette.field)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Image("GTrack")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 30)
                .foregroundStyle(.white)
                .accessibilityLabel("Grinda")
            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(Palette.onFieldSecondary)
            Spacer()
            Button { model.showingProfile = true } label: {
                Text(initials)
                    .font(.system(.footnote, weight: .bold))
                    .foregroundStyle(Palette.cobalt)
                    .frame(width: 36, height: 36)
                    .background(.white, in: Circle())
            }
            .buttonStyle(.pressable)
            .frame(width: 44, height: 44)
            .accessibilityLabel("Profile and settings")
        }
    }

    private var initials: String {
        let name = model.profile.displayName ?? ""
        return name.isEmpty ? "Me" : String(name.prefix(1)).uppercased()
    }

    private var infield: some View {
        VStack(spacing: 2) {
            Text(model.todaySteps.formatted())
                .font(BrandFont.numerals(84))
                .foregroundStyle(.white)
                .contentTransition(.numericText(value: Double(model.todaySteps)))
                .animation(Motion.standard, value: model.todaySteps)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(remaining == 0 ? "Goal hit. That's the lap." : "\(remaining.formatted()) to go · about \(Estimate.minutes(steps: remaining)) min")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(remaining == 0 ? Palette.volt : Palette.onFieldSecondary)
        }
        .padding(.horizontal, 70)
        .accessibilityHidden(true)
    }

    private var summary: some View {
        HStack(spacing: 0) {
            fact(String(format: model.profile.usesMetric ? "%.1f km" : "%.1f mi",
                        model.profile.usesMetric ? Estimate.km(steps: model.todaySteps) : Estimate.km(steps: model.todaySteps) * 0.621),
                 "walked")
            divider
            fact("\(Estimate.kcal(steps: model.todaySteps, weightKg: model.profile.weightKg))", "kcal burned")
            divider
            if remaining == 0 {
                fact("Done", "for today")
            } else if behindPacer > 0 {
                fact(behindPacer.formatted(), "behind pacer")
            } else {
                fact("On pace", "keep going")
            }
        }
    }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.18)).frame(width: 1, height: 30)
    }

    private func fact(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(BrandFont.numerals(24, relativeTo: .title3))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(Palette.onFieldSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// Shown when no race is running: the invitation, stated honestly.
private struct EnterRaceCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Put something on it.")
                .font(.system(.title2, weight: .bold))
                .foregroundStyle(Palette.ink)
            Text("Stake money on a walking goal. Finish and every cent comes back. People with money on the line hit their goal about three times in four.")
                .font(.body)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("See the races") { model.tab = .races }
                .buttonStyle(.primary)
        }
        .padding(20)
        .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct HourlyChart: View {
    let hourly: [Int]

    private func hourLabel(_ h: Int) -> String {
        h == 0 ? "12a" : h == 12 ? "12p" : h < 12 ? "\(h)a" : "\(h - 12)p"
    }
    private var currentHour: Int { Calendar.current.component(.hour, from: .now) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your day so far")
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(Palette.ink)
            Chart {
                ForEach(Array(hourly.enumerated()), id: \.offset) { h, steps in
                    BarMark(x: .value("Hour", h), y: .value("Steps", steps), width: .fixed(8))
                        .foregroundStyle(h == currentHour ? Palette.cobalt : Palette.cobalt.opacity(0.35))
                        .clipShape(Capsule())
                }
            }
            .chartXScale(domain: 0...23)
            .chartXAxis {
                AxisMarks(values: [0, 6, 12, 18]) { v in
                    AxisValueLabel { Text(hourLabel(v.as(Int.self) ?? 0)) }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine().foregroundStyle(Palette.hairline)
                    AxisValueLabel()
                }
            }
            .frame(height: 140)
            .accessibilityLabel("Steps by hour today")
        }
    }
}

/// The internal trigger: your own reason, reflected back with your own numbers.
private struct CoachNote: View {
    @Environment(AppModel.self) private var model

    private var weekSteps: Int { model.history.suffix(7).map(\.steps).reduce(0, +) }

    var body: some View {
        let kcal = Estimate.kcal(steps: weekSteps, weightKg: model.profile.weightKg)
        let fat = Estimate.fatKg(kcal: kcal)
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: model.streak > 1 ? "flame.fill" : "figure.walk")
                .font(.title2)
                .foregroundStyle(Palette.cobalt)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 6) {
                if model.streak > 1 {
                    Text("\(model.streak)-day streak")
                        .font(.system(.headline, weight: .bold))
                        .foregroundStyle(Palette.ink)
                }
                Text("This week you walked \(weekSteps.formatted()) steps, about \(kcal.formatted()) kcal. That's roughly \(fat.formatted(.number.precision(.fractionLength(1)))) kg of fat, from walking alone.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Grin, peeking over the edge of the track. Says something specific to your
/// day; tap him for a reaction (a small, honest variable reward).
private struct GrinRow: View {
    @Environment(AppModel.self) private var model
    @State private var tapLine: String?
    @State private var tapMood: GrinMood?
    @State private var hop = 0
    @State private var taps = 0

    var body: some View {
        let ctx = model.coachContext
        let mood = tapMood ?? GrinCoach.mood(ctx)
        HStack(alignment: .center, spacing: 14) {
            GrinView(mood: mood, pose: mood == .cheer ? .cheer : (mood == .roar ? .flex : .idle),
                     mane: model.maneLevel, hop: hop + model.grinHop)
                .frame(width: 96, height: 110)
                .contentShape(Rectangle())
                .onTapGesture(perform: react)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Tap Grin for a reaction")
            GrinBubble(text: tapLine ?? GrinCoach.line(ctx, seed: model.coachSeed))
                .padding(.top, 26)
            Spacer(minLength: 0)
        }
        .animation(Motion.standard, value: tapLine)
    }

    private func react() {
        taps += 1
        Haptics.soft()
        hop += 1
        let line = GrinCoach.tapLines[(model.coachSeed + taps) % GrinCoach.tapLines.count]
        tapLine = line
        tapMood = line.hasPrefix("Roo") ? .roar : .wink
        if line.hasPrefix("Roo") { Haptics.pin() }
        let mine = taps
        Task {
            try? await Task.sleep(for: .seconds(2.6))
            guard mine == taps else { return }
            tapLine = nil
            tapMood = nil
        }
    }
}
