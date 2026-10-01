import SwiftUI
import Charts

struct TodayView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    TodayField()
                    SteppieRow()
                        .padding(.horizontal, 16)
                        .padding(.top, -46)
                    VStack(alignment: .leading, spacing: 24) {
                        if let lost = model.comebackOffer {
                            ComebackCard(lost: lost).arrive(1)
                        }
                        if let race = model.primaryRace {
                            NavigationLink(value: race) {
                                BibCard(race: race)
                            }
                            .buttonStyle(.pressable)
                            .arrive(1)
                            if !race.isPractice { ShieldStrip(race: race).arrive(2) }
                        } else {
                            ShadowRaceCard().arrive(1)
                        }
                        if model.profile.unopenedBoxes > 0 {
                            ShoeBoxTeaser().arrive(2)
                        }
                        HourlyChart(hourly: model.todayHourly).arrive(3)
                        CoachNote().arrive(4)
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
            .navigationDestination(for: RaceTemplate.self) { ContractView(template: $0) }
            .refreshable { await model.refresh() }
        }
    }
}

/// The cobalt field: today's steps as laps on a track, Steppie running them,
/// Dash pacing where a steady walker would be by now.
private struct TodayField: View {
    @Environment(AppModel.self) private var model

    private var remaining: Int { max(model.todayGoal - model.todaySteps, 0) }
    private var behindPacer: Int {
        Int(Double(model.todayGoal) * model.pacerFraction) - model.todaySteps
    }

    var body: some View {
        VStack(spacing: 18) {
            topBar
            ZStack {
                SparkleField(count: 8, color: .white.opacity(0.6))
                TrackView(steps: model.todaySteps, goal: model.todayGoal, pacer: model.pacerFraction,
                          shoes: model.wearing, mane: model.maneLevel)
                infield
            }
            .frame(height: 246)
            summary
        }
        .padding(.horizontal, 16)
        .padding(.top, 60)
        .padding(.bottom, 54)
        .background {
            ZStack {
                Palette.field
                RadialGradient(colors: [.white.opacity(0.16), .clear], center: .top, startRadius: 0, endRadius: 420)
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            StrideMark(color: .white)
                .frame(height: 30)
                .accessibilityLabel("Steppie")
            Spacer()
            StatChip(symbol: "flame.fill", value: "\(model.streak)", tint: Color(hex: 0xFF9A3C))
                .accessibilityLabel("\(model.streak)-day streak")
            Button { model.showingShields = true } label: {
                StatChip(symbol: "shield.lefthalf.filled", value: "\(model.profile.shields)", tint: Color(hex: 0x45B983))
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("\(model.profile.shields) Shields. Open the Shield locker")
            Button { model.tab = .league } label: {
                StatChip(symbol: "bolt.fill", value: model.weekGrit.formatted(.number.notation(.compactName)), tint: Palette.volt)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("\(model.weekGrit) Grit this week. Open the league")
            Button { model.showingProfile = true } label: {
                Text(initials)
                    .font(.system(.footnote, weight: .bold))
                    .foregroundStyle(Palette.cobalt)
                    .frame(width: 34, height: 34)
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
            Text(Date.now.formatted(.dateTime.weekday(.wide)).uppercased())
                .font(BrandFont.label(13))
                .kerning(1.5)
                .foregroundStyle(Palette.onFieldSecondary)
            Text(model.todaySteps.formatted())
                .font(BrandFont.numerals(80))
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
                fact("Done", "Dash beaten")
            } else if behindPacer > 0 {
                fact(behindPacer.formatted(), "behind Dash")
            } else {
                fact("Ahead", "of Dash")
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

/// Small glossy counter on the field: streak, Shields, Grit.
struct StatChip: View {
    let symbol: String
    let value: String
    var tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
            Text(value)
                .font(BrandFont.numerals(16))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .monospacedDigit()
        }
        .padding(.horizontal, 9)
        .frame(height: 30)
        .background(.white.opacity(0.14), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
    }
}

/// For anyone with nothing staked: their own last week, replayed as if money
/// had been on it. Honest numbers, then one tap to the Sprint.
private struct ShadowRaceCard: View {
    @Environment(AppModel.self) private var model
    @State private var hop = 0

    private var stake: Money { Money(units: model.suggestedStake(for: RaceTemplate.board[0]) ?? 10) }

    var body: some View {
        let shadow = model.shadowWeek
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                CharacterView(who: .pip, mood: shadow.hits >= 4 ? .cheer : .happy, pose: .wave, hop: hop)
                    .frame(width: 70, height: 80)
                    .onTapGesture { hop += 1; Haptics.soft() }
                VStack(alignment: .leading, spacing: 6) {
                    Text("PIP HAS YOUR SHADOW WEEK")
                        .font(BrandFont.label(12))
                        .kerning(0.8)
                        .foregroundStyle(Palette.cobalt)
                    Text(headline(shadow))
                        .font(.system(.title3, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            ShadowDots(days: Array(model.history.dropLast().suffix(7)), goal: model.profile.dailyGoal)
            Text("People who put money on their walk hit their goal about 3 times in 4. Short races are only a hold on your card: finish, and nothing is ever charged.")
                .font(.subheadline)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            NavigationLink(value: RaceTemplate.board[0]) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                    Text("Back yourself with \(stake.formatted)")
                }
            }
            .buttonStyle(.primary)
            .shimmer()
            if model.profile.shields > 0 {
                Label("Your first Shield is waiting: one bad day covered.", systemImage: "shield.lefthalf.filled")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(hex: 0x1F7A52))
            }
        }
        .padding(18)
        .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, y: 8)
    }

    private func headline(_ s: (hits: Int, days: Int)) -> String {
        guard s.days >= 3 else { return "Your first race is one hold away." }
        if s.hits == s.days { return "\(s.hits) for \(s.days). With \(stake.formatted) on it, you'd have kept every cent." }
        if s.hits * 2 >= s.days { return "You hit your goal \(s.hits) of the last \(s.days) days. Money on it closes the gap." }
        return "\(s.hits) of \(s.days) days. A stake is the push that changes that."
    }
}

/// Seven dots: the last week against your goal.
private struct ShadowDots: View {
    let days: [DaySteps]
    let goal: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(days) { d in
                let hit = d.steps >= goal
                VStack(spacing: 4) {
                    ZStack {
                        Circle().fill(hit ? Palette.cobalt : Palette.hairline.opacity(0.6))
                        Image(systemName: hit ? "checkmark" : "xmark")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(hit ? .white : Palette.inkSecondary)
                    }
                    .frame(width: 30, height: 30)
                    Text(d.date.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Palette.inkSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Goal hit on \(days.filter { $0.steps >= goal }.count) of the last \(days.count) days")
    }
}

/// A missed race's one second chance, with its real deadline.
struct ComebackCard: View {
    let lost: Race
    @Environment(AppModel.self) private var model

    var body: some View {
        let back = Money(cents: (lost.stake?.cents ?? 0) / 2, currency: lost.stake?.currency ?? model.currency)
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                SteppieView(mood: .focus, pose: .flex, mane: model.maneLevel, shoes: model.wearing)
                    .frame(width: 70, height: 80)
                VStack(alignment: .leading, spacing: 4) {
                    Text("COMEBACK OPEN")
                        .font(BrandFont.label(12)).kerning(0.8)
                        .foregroundStyle(Palette.volt)
                    Text("Win back \(back.formatted) of your \(lost.stake?.formatted ?? "") stake.")
                        .font(.system(.title3, weight: .heavy))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text("Five days at \(lost.dailyGoal.formatted()) steps. Finish and you get your new stake back plus half of the missed one. One comeback per race.")
                .font(.subheadline)
                .foregroundStyle(Palette.onFieldSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Label {
                    Text(model.comebackDeadline(lost), style: .relative) + Text(" left")
                } icon: { Image(systemName: "timer") }
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                NavigationLink(value: RaceTemplate.comeback(for: lost)) {
                    Text("Take the comeback")
                        .font(.system(.subheadline, weight: .bold))
                        .foregroundStyle(Palette.onVolt)
                        .padding(.horizontal, 16)
                        .frame(height: 44)
                        .background(Palette.volt, in: Capsule())
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(18)
        .background {
            ZStack {
                LinearGradient(colors: [Color(hex: 0x16307F), Palette.field], startPoint: .topLeading, endPoint: .bottomTrailing)
                SparkleField(count: 6)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

/// What covers a bad day on the live race: grace days and equipped Shields.
private struct ShieldStrip: View {
    let race: Race
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 12) {
            CharacterView(who: .shelly, mood: race.coverLeft > 0 ? .happy : .worried)
                .frame(width: 46, height: 53)
            VStack(alignment: .leading, spacing: 2) {
                Text(race.coverLeft > 0 ? "\(race.coverLeft) bad day\(race.coverLeft == 1 ? "" : "s") covered" : "No cover left")
                    .font(.system(.headline, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            HStack(spacing: 3) {
                ForEach(0..<max(race.graceAllowed + race.shieldsEquipped, 1), id: \.self) { i in
                    Image(systemName: i < race.coverLeft ? "shield.fill" : "shield")
                        .foregroundStyle(i < race.coverLeft ? Color(hex: 0x2E9E6B) : Palette.hairline)
                }
            }
            .font(.title3)
        }
        .padding(14)
        .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var detail: String {
        let shields = race.shieldsEquipped
        let grace = race.graceAllowed
        var parts: [String] = []
        if grace > 0 { parts.append("\(grace) grace day\(grace == 1 ? "" : "s")") }
        if shields > 0 { parts.append("\(shields) Shield\(shields == 1 ? "" : "s") from Shelly") }
        return parts.isEmpty ? "Every day counts on this one." : parts.joined(separator: " + ") + ". Unused Shields go back to your locker."
    }
}

/// An unopened Shoe Box, shaking a little to be opened.
private struct ShoeBoxTeaser: View {
    @Environment(AppModel.self) private var model
    @State private var wiggle = 0

    var body: some View {
        Button { model.showingShoeBox = true } label: {
            HStack(spacing: 14) {
                ShoeBoxArt(open: false)
                    .frame(width: 64, height: 56)
                    .shake(wiggle)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Shoe Box ready")
                        .font(.system(.headline, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Text("You finished a race. Open it for a new pair for Steppie.")
                        .font(.footnote)
                        .foregroundStyle(Palette.inkSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Palette.inkSecondary)
            }
            .padding(14)
            .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .pulseHalo(Color(hex: 0xFFB020), cornerRadius: 14)
        }
        .buttonStyle(.pressable)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.6))
                withAnimation(.linear(duration: 0.5)) { wiggle += 1 }
            }
        }
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
                .foregroundStyle(model.streak > 1 ? Color(hex: 0xFF9A3C) : Palette.cobalt)
                .symbolEffect(.bounce, value: model.streak)
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

/// Steppie, peeking over the edge of the track. Says something specific to
/// your day; tap him for a reaction (a small, honest variable reward).
private struct SteppieRow: View {
    @Environment(AppModel.self) private var model
    @State private var tapLine: String?
    @State private var tapMood: SteppieMood?
    @State private var hop = 0
    @State private var taps = 0

    var body: some View {
        let ctx = model.coachContext
        let mood = tapMood ?? Coach.mood(ctx)
        HStack(alignment: .center, spacing: 12) {
            SteppieView(mood: mood, pose: mood == .cheer ? .cheer : (mood == .roar ? .flex : (mood == .focus ? .point : .idle)),
                        mane: model.maneLevel, shoes: model.wearing, hop: hop + model.steppieHop)
                .frame(width: 104, height: 120)
                .contentShape(Rectangle())
                .onTapGesture(perform: react)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Tap Steppie for a reaction")
            SpeechBubble(text: tapLine ?? Coach.line(ctx, seed: model.coachSeed))
                .padding(.top, 30)
            Spacer(minLength: 0)
        }
        .animation(Motion.standard, value: tapLine)
    }

    private func react() {
        taps += 1
        Haptics.soft()
        hop += 1
        let line = Coach.tapLines[(model.coachSeed + taps) % Coach.tapLines.count]
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
