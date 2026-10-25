import SwiftUI
import Charts

struct ProgressScreen: View {
    @Environment(AppModel.self) private var model
    @State private var loggingWeight = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    ManeCard().arrive(0)
                    DistanceStory().arrive(1)
                    ShoeCloset().arrive(2)
                    TrophyCase().arrive(2)
                    WeightSection(loggingWeight: $loggingWeight).arrive(3)
                    StepsMonth().arrive(4)
                    StreakCalendar().arrive(5)
                    Text("Calories and fat are estimates from steps and body weight (about 0.04 kcal per step at 75 kg; 7,700 kcal ≈ 1 kg of fat). Steppie isn't medical advice.")
                        .font(.caption)
                        .foregroundStyle(Palette.inkSecondary)
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(Palette.ground)
            .navigationTitle("Progress")
            .sheet(isPresented: $loggingWeight) { LogWeightSheet() }
        }
    }
}

/// Distance told as a journey, not a KPI tile.
private struct DistanceStory: View {
    @Environment(AppModel.self) private var model

    private var totalSteps: Int { model.history.map(\.steps).reduce(0, +) }
    private var km: Double { Estimate.km(steps: totalSteps) }

    private static let journeys: [(km: Double, text: String)] = [
        (21.1, "a half marathon"), (42.2, "a full marathon"), (100, "Amsterdam to Rotterdam, and back"),
        (160, "Berlin to Leipzig"), (225, "London to Paris, as the crow flies"), (344, "the length of Switzerland"),
        (400, "New York to Washington, D.C."), (600, "Munich to Berlin"),
    ]

    private var journey: String {
        Self.journeys.last(where: { $0.km <= km })?.text ?? "your first few kilometres"
    }

    var body: some View {
        let kcal = Estimate.kcal(steps: totalSteps, weightKg: model.profile.weightKg)
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 5 weeks")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(Palette.onFieldSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(model.profile.usesMetric ? km.formatted(.number.precision(.fractionLength(0))) : (km * 0.621).formatted(.number.precision(.fractionLength(0))))
                    .font(BrandFont.numerals(80))
                    .foregroundStyle(.white)
                Text(model.profile.usesMetric ? "km" : "mi")
                    .font(BrandFont.numerals(32))
                    .foregroundStyle(Palette.onFieldSecondary)
            }
            Text("That's further than \(journey). About \(kcal.formatted()) kcal, or \(Estimate.fatKg(kcal: kcal).formatted(.number.precision(.fractionLength(1)))) kg of fat, walked off.")
                .font(.body)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                Palette.field
                TrackShape(inset: 0)
                    .stroke(.white.opacity(0.07), lineWidth: 22)
                    .frame(width: 360, height: 200)
                    .offset(x: 150, y: -40)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

private struct WeightSection: View {
    @Environment(AppModel.self) private var model
    @Binding var loggingWeight: Bool

    private var metric: Bool { model.profile.usesMetric }
    private func display(_ kg: Double) -> Double { metric ? kg : kg / 0.453_592 }
    private var unit: String { metric ? "kg" : "lb" }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Weight").font(.system(.title3, weight: .bold))
                Spacer()
                Button("Log weight") { loggingWeight = true }
                    .font(.system(.subheadline, weight: .semibold))
            }
            if let first = model.weights.first, let last = model.weights.last, model.weights.count > 1 {
                let change = display(last.kg) - display(first.kg)
                Text(change < 0
                     ? "Down \(abs(change).formatted(.number.precision(.fractionLength(1)))) \(unit) since \(first.date.formatted(.dateTime.month(.wide).day()))."
                     : "Holding steady since \(first.date.formatted(.dateTime.month(.wide).day())). Walking still counts.")
                    .font(.body)
                    .foregroundStyle(Palette.inkSecondary)
                Chart {
                    ForEach(model.weights) { w in
                        LineMark(x: .value("Date", w.date), y: .value(unit, display(w.kg)))
                            .interpolationMethod(.monotone)
                            .foregroundStyle(Palette.cobalt)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        PointMark(x: .value("Date", w.date), y: .value(unit, display(w.kg)))
                            .foregroundStyle(Palette.cobalt)
                            .symbolSize(18)
                    }
                    if let goal = model.profile.goalWeightKg {
                        RuleMark(y: .value("Goal", display(goal)))
                            .foregroundStyle(Palette.inkSecondary)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .annotation(position: .top, alignment: .leading) {
                                Text("Goal \(display(goal).formatted(.number.precision(.fractionLength(0)))) \(unit)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Palette.inkSecondary)
                            }
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 200)
                .accessibilityLabel("Weight trend")
            } else {
                Text("Log your weight once a week. Steppie also reads it from Apple Health and smart scales.")
                    .font(.body)
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
    }
}

private struct StepsMonth: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let days = Array(model.history.suffix(30))
        VStack(alignment: .leading, spacing: 14) {
            Text("Steps, last 30 days").font(.system(.title3, weight: .bold))
            Chart {
                ForEach(days) { d in
                    BarMark(x: .value("Day", d.date, unit: .day), y: .value("Steps", d.steps))
                        .foregroundStyle(d.steps >= model.profile.dailyGoal ? Palette.cobalt : Palette.cobalt.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }
                RuleMark(y: .value("Goal", model.profile.dailyGoal))
                    .foregroundStyle(Palette.ink.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
            .chartXAxis { AxisMarks(values: .stride(by: .day, count: 7)) { _ in AxisValueLabel(format: .dateTime.day().month(.abbreviated)) } }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine().foregroundStyle(Palette.hairline)
                    AxisValueLabel()
                }
            }
            .frame(height: 180)
            let hit = days.filter { $0.steps >= model.profile.dailyGoal }.count
            Text("You hit your goal on \(hit) of \(days.count) days.")
                .font(.subheadline)
                .foregroundStyle(Palette.inkSecondary)
        }
    }
}

/// Every goal day punched, like a race card that fills up.
private struct StreakCalendar: View {
    @Environment(AppModel.self) private var model
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        let days = Array(model.history.suffix(28))
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Punch card").font(.system(.title3, weight: .bold))
                Spacer()
                if model.streak > 0 {
                    Label("\(model.streak) days", systemImage: "flame.fill")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(Palette.cobalt)
                }
            }
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(days) { d in
                    let hit = d.steps >= model.profile.dailyGoal
                    let today = Calendar.current.isDateInToday(d.date)
                    ZStack {
                        Circle().fill(hit ? Palette.field : Color.clear)
                        Circle().strokeBorder(hit ? Color.clear : Palette.hairline, lineWidth: 1.5)
                        if today && !hit { Circle().strokeBorder(Palette.cobalt, lineWidth: 2) }
                        Text(d.date.formatted(.dateTime.day()))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(hit ? .white : Palette.inkSecondary)
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .accessibilityLabel("\(d.date.formatted(date: .abbreviated, time: .omitted)): \(d.steps.formatted()) steps\(hit ? ", goal hit" : "")")
                }
            }
            .padding(16)
            .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

private struct LogWeightSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var value: Double = 80

    private var metric: Bool { model.profile.usesMetric }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("\(value.formatted(.number.precision(.fractionLength(1)))) \(metric ? "kg" : "lb")")
                    .font(BrandFont.numerals(64))
                    .contentTransition(.numericText(value: value))
                Slider(value: $value, in: metric ? 40...200 : 90...440, step: 0.1)
                Spacer()
                Button("Save") {
                    let kg = metric ? value : value * 0.453_592
                    Task { await model.logWeight(kg); dismiss() }
                }
                .buttonStyle(.primary)
            }
            .padding(20)
            .navigationTitle("Log weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .presentationDetents([.medium])
        .onAppear {
            let kg = model.profile.weightKg ?? 80
            value = metric ? (kg * 10).rounded() / 10 : (kg / 0.453_592 * 10).rounded() / 10
        }
    }
}

/// Steppie grows with you: his mane reflects your goal days over the last two weeks.
/// It never resets overnight; a missed day just stops it growing for a while.
private struct ManeCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let level = model.maneLevel
        let n = model.goalDays14
        let next = level < 3 ? Coach.maneThresholds[level + 1] : nil
        HStack(alignment: .center, spacing: 16) {
            SteppieView(mood: level >= 2 ? .proud : .happy, mane: level, shoes: model.wearing)
                .frame(width: 110, height: 126)
            VStack(alignment: .leading, spacing: 8) {
                Text(Coach.maneNames[level])
                    .font(.system(.title3, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Text(next.map { "Goal hit \(n) of the last 14 days. \($0 - n) more and Steppie's mane grows." } ?? "Goal hit \(n) of the last 14 days. Steppie has never looked better.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 4) {
                    ForEach(0..<14, id: \.self) { i in
                        Capsule()
                            .fill(i < n ? Palette.cobalt : Palette.hairline)
                            .frame(height: 6)
                    }
                }
                .accessibilityHidden(true)
            }
        }
        .padding(16)
        .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Every pair Steppie has earned. Tap one to wear it.
private struct ShoeCloset: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Shoe closet").font(.system(.title3, weight: .bold))
                Spacer()
                Text("\(model.shoesOwned.count) of \(ShoeStyle.all.count)")
                    .font(.footnote.weight(.semibold)).foregroundStyle(Palette.inkSecondary)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                ForEach(ShoeStyle.all) { shoe in
                    let owned = model.shoesOwned.contains(shoe.id)
                    let on = model.wearing.id == shoe.id
                    Button { if owned { model.wear(shoe) } } label: {
                        VStack(spacing: 4) {
                            ShoeSwatch(shoe: shoe, owned: owned)
                                .frame(height: 40)
                            Circle().fill(owned ? shoe.rarity.color : Palette.hairline).frame(width: 6, height: 6)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(on ? Palette.volt.opacity(0.4) : Palette.tyvek, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel(owned ? "\(shoe.name), \(shoe.rarity.title)\(on ? ", wearing" : "")" : "Locked shoe")
                }
            }
            if model.profile.unopenedBoxes > 0 {
                Button { model.showingShoeBox = true } label: {
                    Label("Open \(model.profile.unopenedBoxes) Shoe Box\(model.profile.unopenedBoxes == 1 ? "" : "es")", systemImage: "shippingbox.fill")
                }
                .buttonStyle(.primary)
                .shimmer()
            } else {
                Text("Finish races to earn Shoe Boxes. Longer races, better odds.")
                    .font(.footnote).foregroundStyle(Palette.inkSecondary)
            }
        }
    }
}

/// A trainer, side on, in a colourway. Silhouette only when not owned yet.
struct ShoeSwatch: View {
    let shoe: ShoeStyle
    var owned = true

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack(alignment: .bottom) {
                Capsule().fill(Color(hex: owned ? shoe.sole : 0xCDD2DB)).frame(width: w, height: h * 0.2)
                Capsule().fill(Color(hex: owned ? shoe.midsole : 0xDDE1E8)).frame(width: w * 0.96, height: h * 0.24).offset(y: -h * 0.14)
                UnevenRoundedRectangle(topLeadingRadius: h * 0.5, bottomLeadingRadius: 4, bottomTrailingRadius: 4, topTrailingRadius: h * 0.2)
                    .fill(Color(hex: owned ? shoe.upper : 0xE4E7EC))
                    .frame(width: w * 0.86, height: h * 0.55)
                    .offset(x: w * 0.04, y: -h * 0.3)
                if owned {
                    HStack(spacing: 2) {
                        ForEach(0..<2, id: \.self) { _ in
                            Rectangle().fill(Color(hex: shoe.stripe)).frame(width: w * 0.07, height: h * 0.34).rotationEffect(.degrees(28))
                        }
                    }
                    .offset(y: -h * 0.38)
                }
            }
            .frame(width: w, height: h, alignment: .bottom)
        }
        .accessibilityHidden(true)
    }
}
