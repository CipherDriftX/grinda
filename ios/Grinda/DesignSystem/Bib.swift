import SwiftUI

/// Fine security-print line work for money bands (banknote-grade precision
/// wherever money is shown).
struct Guilloche: Shape {
    var lines = 7
    var waves: Double = 5

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let steps = 160
        for l in 0..<lines {
            let phase = Double(l) / Double(lines) * .pi * 2
            let amp = rect.height * 0.36
            for i in 0...steps {
                let x = rect.minX + rect.width * CGFloat(i) / CGFloat(steps)
                let t = Double(i) / Double(steps) * .pi * 2 * waves
                let y = rect.midY + CGFloat(sin(t + phase) * cos(t * 0.5 + phase * 0.5)) * amp
                if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
            }
        }
        return p
    }
}

/// A steel safety pin, drawn small, pinned diagonally through a bib corner.
struct SafetyPin: View {
    var body: some View {
        ZStack {
            Capsule()
                .strokeBorder(
                    LinearGradient(colors: [Color(hex: 0xE6E9EE), Color(hex: 0x8A93A3), Color(hex: 0xD2D7DF)],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: 2
                )
                .frame(width: 26, height: 8)
            Circle()
                .fill(Color(hex: 0xB9C0CC))
                .frame(width: 7, height: 7)
                .offset(x: 12)
        }
        .rotationEffect(.degrees(-38))
        .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
        .accessibilityHidden(true)
    }
}

/// Punched day marks. A punched hole shows the track through the bib.
struct PunchRow: View {
    let days: [DayRecord]
    var size: CGFloat = 18

    var body: some View {
        HStack(spacing: days.count > 10 ? 4 : 8) {
            ForEach(Array(days.enumerated()), id: \.offset) { i, day in
                Punch(day: day, size: days.count > 10 ? min(size, 10) : size)
                    .accessibilityLabel(label(i, day))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func label(_ i: Int, _ d: DayRecord) -> String {
        let state: String = switch d.state {
        case .hit: "done"
        case .missed: "missed"
        case .graced: "grace day"
        case .today: "today, \(d.steps.formatted()) steps"
        case .review: "under review"
        case .upcoming: "upcoming"
        }
        return "Day \(i + 1): \(state)"
    }
}

private struct Punch: View {
    let day: DayRecord
    let size: CGFloat

    var body: some View {
        ZStack {
            switch day.state {
            case .hit:
                Circle().fill(Palette.field)
                    .overlay(Circle().stroke(.black.opacity(0.25), lineWidth: 1).blur(radius: 0.5).offset(y: 0.5).mask(Circle()))
            case .missed:
                Circle().strokeBorder(Palette.risk, lineWidth: 1.5)
                Image(systemName: "xmark").font(.system(size: size * 0.45, weight: .bold)).foregroundStyle(Palette.risk)
            case .graced:
                Circle().strokeBorder(Palette.inkSecondary, style: StrokeStyle(lineWidth: 1.5, dash: [2, 2]))
            case .today:
                Circle().strokeBorder(Palette.hairline, lineWidth: 2)
                Circle().trim(from: 0, to: day.progress)
                    .stroke(Palette.cobalt, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(1)
            case .review:
                Circle().strokeBorder(Palette.inkSecondary, lineWidth: 1.5)
                Image(systemName: "hourglass").font(.system(size: size * 0.45)).foregroundStyle(Palette.inkSecondary)
            case .upcoming:
                Circle().strokeBorder(Palette.hairline, lineWidth: 1.5)
            }
        }
        .frame(width: size, height: size)
    }
}

/// The race bib: every race in Grinda is a numbered bib printed on Tyvek,
/// pinned at four corners. A strict label grid rules every bib.
struct BibCard: View {
    let name: String
    let bibNumber: Int
    let dailyGoal: Int
    let dayLabel: String
    let stake: Money?
    let usesHold: Bool
    var days: [DayRecord] = []
    var settles: Date? = nil
    var pinned = 4 // how many of the four pins are in (0...4)
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(Palette.hairline)
            numeralRow
                .padding(.horizontal, 18)
                .padding(.top, compact ? 10 : 14)
                .padding(.bottom, compact ? 8 : 12)
            grid
            if !days.isEmpty {
                PunchRow(days: days)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            moneyBand
        }
        .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(pins)
        .shadow(color: .black.opacity(0.14), radius: 18, y: 10)
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack {
            Text(name.uppercased())
                .font(BrandFont.label(15, relativeTo: .subheadline))
                .foregroundStyle(Palette.ink)
            Spacer()
            Text("Nº \(String(bibNumber))")
                .font(BrandFont.label(15, relativeTo: .subheadline))
                .foregroundStyle(Palette.inkSecondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 12)
    }

    private var numeralRow: some View {
        HStack(alignment: .lastTextBaseline, spacing: 10) {
            Text(dailyGoal.formatted())
                .font(BrandFont.numerals(compact ? 52 : 72))
                .foregroundStyle(Palette.ink)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text("STEPS\nA DAY")
                .font(BrandFont.label(13))
                .foregroundStyle(Palette.inkSecondary)
                .lineSpacing(-2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(dailyGoal.formatted()) steps a day")
    }

    private var grid: some View {
        HStack(spacing: 0) {
            cell("Race", dayLabel)
            Rectangle().fill(Palette.hairline).frame(width: 1)
            cell("Stake", stake?.formatted ?? "Free")
            Rectangle().fill(Palette.hairline).frame(width: 1)
            cell("Settles", settles.map { $0.formatted(.dateTime.weekday(.abbreviated).hour().minute()) } ?? "3h after")
        }
        .fixedSize(horizontal: false, vertical: true)
        .overlay(alignment: .top) { Rectangle().fill(Palette.hairline).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.hairline).frame(height: 1) }
    }

    private func cell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(BrandFont.label(11))
                .foregroundStyle(Palette.inkSecondary)
            Text(value)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var moneyBand: some View {
        ZStack {
            Guilloche()
                .stroke(Palette.cobalt.opacity(0.22), lineWidth: 0.6)
            Text(bandText)
                .font(BrandFont.label(12))
                .kerning(0.6)
                .foregroundStyle(Palette.cobalt)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Palette.tyvek, in: Capsule())
        }
        .frame(height: 34)
        .frame(maxWidth: .infinity)
        .background(Palette.cobalt.opacity(0.06))
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 14, bottomTrailingRadius: 14, style: .continuous))
    }

    private var bandText: String {
        guard let stake else { return "PRACTICE · NO MONEY" }
        return usesHold ? "\(stake.formatted) HELD · NEVER CHARGED IF YOU FINISH" : "\(stake.formatted) · BACK IN FULL WHEN YOU FINISH"
    }

    private var pins: some View {
        GeometryReader { geo in
            let spots = [CGPoint(x: 16, y: 16), CGPoint(x: geo.size.width - 16, y: 16),
                         CGPoint(x: 16, y: geo.size.height - 16), CGPoint(x: geo.size.width - 16, y: geo.size.height - 16)]
            ForEach(0..<4, id: \.self) { i in
                ZStack {
                    Circle().fill(Palette.ground).frame(width: 6, height: 6)
                    if i < pinned {
                        SafetyPin()
                            .transition(.asymmetric(insertion: .scale(scale: 1.6).combined(with: .opacity), removal: .opacity))
                    }
                }
                .position(spots[i])
            }
        }
        .animation(Motion.snap, value: pinned)
    }
}

extension BibCard {
    init(race: Race, compact: Bool = false) {
        self.init(name: race.name, bibNumber: race.bibNumber, dailyGoal: race.dailyGoal, dayLabel: race.dayLabel,
                  stake: race.stake, usesHold: race.usesHold, days: race.days, settles: race.settlesAt, compact: compact)
    }

    init(template t: RaceTemplate, stake: Int?, bibNumber: Int = 0, pinned: Int = 4, startingToday: Bool = true) {
        let dates = AppModel.schedule(for: t, startingToday: startingToday)
        let settles = Calendar.current.date(byAdding: .hour, value: 27, to: dates.last ?? .now)
        self.init(name: t.name, bibNumber: bibNumber, dailyGoal: t.dailyGoal, dayLabel: "\(t.days) days",
                  stake: stake.map { Money(units: $0) }, usesHold: t.usesHold,
                  days: dates.map { DayRecord(date: $0, steps: 0, goal: t.dailyGoal, state: .upcoming) },
                  settles: settles, pinned: pinned)
    }
}
