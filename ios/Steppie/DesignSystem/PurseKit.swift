import SwiftUI

// Purse components. A purse is printed like a banknote: guilloche line work,
// a serial number, the total in bib numerals. Each purse has its own ink
// (PurseArt), so the board reads like a wallet of different notes.

// MARK: - Counting numbers

/// Counts a money amount up from its previous value, digit by digit, like a
/// payout counter. Use for purse totals and splits.
struct CountingMoney: View, Animatable {
    var cents: Double
    var currency: String
    var font: Font
    var color: Color = .white

    var animatableData: Double {
        get { cents }
        set { cents = newValue }
    }

    var body: some View {
        Text(Money(cents: Int(cents.rounded()), currency: currency).formatted)
            .font(font)
            .foregroundStyle(color)
            .monospacedDigit()
    }
}

/// Counts from zero to `value` once, on appear. Reduce Motion shows it at once.
struct CountUpMoney: View {
    let money: Money
    var font: Font
    var color: Color = .white
    var duration: Double = 1.4
    var delay: Double = 0
    @State private var shown: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        CountingMoney(cents: shown, currency: money.currency, font: font, color: color)
            .accessibilityLabel(money.formatted)
            .onAppear {
                guard !reduceMotion else { shown = Double(money.cents); return }
                withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: duration).delay(delay)) { shown = Double(money.cents) }
            }
            .onChange(of: money.cents) { _, new in
                withAnimation(reduceMotion ? nil : .timingCurve(0.16, 1, 0.3, 1, duration: 0.9)) { shown = Double(new) }
            }
    }
}

// MARK: - Live

/// A small breathing dot with "LIVE".
struct LiveTag: View {
    var color: Color = Color(hex: 0xFF5A4E)
    var label = "LIVE"
    @State private var on = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 5) {
            ZStack {
                Circle().fill(color.opacity(0.35)).frame(width: 12, height: 12)
                    .scaleEffect(on ? 1.5 : 0.6).opacity(on ? 0 : 1)
                Circle().fill(color).frame(width: 7, height: 7)
            }
            Text(label).font(BrandFont.label(11)).kerning(0.8)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.3).repeatForever(autoreverses: false)) { on = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label.capitalized)
    }
}

/// "Starts in 14h 22m" / "Closes in 3h 05m", ticking every second.
struct Countdown: View {
    let to: Date
    var prefix = "Starts in"
    var font: Font = .system(.footnote, weight: .bold)

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { tl in
            Text("\(prefix) \(Self.format(to.timeIntervalSince(tl.date)))")
                .font(font)
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
        }
    }

    static func format(_ s: TimeInterval) -> String {
        let t = max(Int(s), 0)
        let d = t / 86_400, h = (t % 86_400) / 3_600, m = (t % 3_600) / 60, sec = t % 60
        if d > 0 { return "\(d)d \(h)h" }
        if h > 0 { return String(format: "%dh %02dm", h, m) }
        return String(format: "%dm %02ds", m, sec)
    }
}

// MARK: - Banknote

/// Rosette line work for the corner of a purse note.
struct Rosette: Shape {
    var petals = 12
    var rings = 5

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        for ring in 0..<rings {
            let base = r * (0.45 + 0.55 * CGFloat(ring) / CGFloat(max(rings - 1, 1)))
            let steps = 220
            for i in 0...steps {
                let a = Double(i) / Double(steps) * 2 * .pi
                let wobble = 1 + 0.12 * sin(a * Double(petals) + Double(ring) * 0.7)
                let pt = CGPoint(x: c.x + base * CGFloat(wobble * cos(a)), y: c.y + base * CGFloat(wobble * sin(a)))
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
        }
        return p
    }
}

/// The face of a purse: a banknote in the purse's ink with the total front and
/// centre. Used on the board, on the detail hero and on the finish.
struct PurseNote: View {
    let purse: Purse
    var compact = false
    /// Your share, shown instead of "per finisher" once you're in.
    var showLive = true

    private var ink: Color { Color(hex: purse.art.color) }
    private var deep: Color { Color(hex: purse.art.deep) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [ink, deep], startPoint: .topLeading, endPoint: .bottomTrailing)
            Guilloche(lines: 11, waves: 3.5)
                .stroke(.white.opacity(0.16), lineWidth: 0.6)
                .frame(height: compact ? 70 : 110)
                .frame(maxHeight: .infinity, alignment: .bottom)
            Rosette()
                .stroke(.white.opacity(0.14), lineWidth: 0.6)
                .frame(width: compact ? 120 : 170, height: compact ? 120 : 170)
                .offset(x: compact ? 210 : 220, y: compact ? -26 : -30)
            VStack(alignment: .leading, spacing: compact ? 4 : 8) {
                HStack(spacing: 8) {
                    Image(systemName: purse.art.symbol).font(.system(size: compact ? 13 : 15, weight: .bold))
                    Text(purse.name.uppercased()).font(BrandFont.label(compact ? 13 : 15, relativeTo: .subheadline)).kerning(0.8)
                    Spacer(minLength: 4)
                    if purse.hasStarted && !purse.isOver { LiveTag(color: .white) }
                    else if purse.kind == .crew { tag("CREW") }
                    else if purse.kind == .host { tag("HOSTED") }
                }
                .foregroundStyle(.white)
                Text("THE PURSE")
                    .font(BrandFont.label(11))
                    .kerning(1.2)
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.top, compact ? 2 : 6)
                CountUpMoney(money: purse.pot, font: BrandFont.numerals(compact ? 46 : 68), duration: compact ? 1.1 : 1.6)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(purse.rule)
                    .font(.system(compact ? .footnote : .subheadline, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                HStack(alignment: .bottom) {
                    EntrantsStack(count: purse.entrants, seed: purse.id)
                    Spacer()
                    Text("Nº \(serial)")
                        .font(BrandFont.label(10))
                        .foregroundStyle(.white.opacity(0.6))
                        .monospacedDigit()
                }
            }
            .padding(compact ? 16 : 20)
        }
        .frame(height: compact ? 210 : 270)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.18), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(purse.name). Purse \(purse.pot.formatted), \(purse.entrants) in. \(purse.rule)")
    }

    private var serial: String {
        let n = purse.id.unicodeScalars.reduce(UInt32(17)) { $0 &* 31 &+ $1.value } % 9_000_000 + 1_000_000
        return "\(n)"
    }

    private func tag(_ s: String) -> some View {
        Text(s).font(BrandFont.label(10)).kerning(0.8)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(.white.opacity(0.2), in: Capsule())
    }
}

// MARK: - People

/// Overlapping initials for the people in a purse, plus the count.
struct EntrantsStack: View {
    let count: Int
    var seed: String = ""
    var light = true

    private static let letters = Array("ALMJSKTPBDRCENOHVZ")
    private static let tints: [UInt32] = [0xFFB020, 0x22B37A, 0x7C5CFF, 0xFF7A3D, 0x3AA8E0, 0xD9418C, 0x0F9E9A]

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: -9) {
                ForEach(0..<min(max(count, 0), 4), id: \.self) { i in
                    let k = (seed.unicodeScalars.reduce(0) { $0 + Int($1.value) } + i * 7)
                    Text(String(Self.letters[k % Self.letters.count]))
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Color(hex: Self.tints[k % Self.tints.count]), in: Circle())
                        .overlay(Circle().strokeBorder(light ? .white : Palette.tyvek, lineWidth: 2))
                }
            }
            Text(count == 0 ? "Be the first in" : "\(count.formatted()) in")
                .font(.system(.footnote, weight: .bold))
                .foregroundStyle(light ? .white : Palette.ink)
                .contentTransition(.numericText(value: Double(count)))
                .animation(Motion.standard, value: count)
        }
        .accessibilityHidden(true)
    }
}

/// Who's still in: finished or on pace, behind, and out, as one bar.
struct StillInBar: View {
    let entrants: Int
    let stillIn: Int
    let onPace: Int
    var height: CGFloat = 12
    @State private var drawn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let total = Double(max(entrants, 1))
        let pace = Double(onPace) / total
        let behind = Double(max(stillIn - onPace, 0)) / total
        GeometryReader { geo in
            HStack(spacing: 2) {
                Capsule().fill(Palette.volt).frame(width: max(geo.size.width * pace * (drawn ? 1 : 0), 0))
                Capsule().fill(Color(hex: 0xFFB020)).frame(width: max(geo.size.width * behind * (drawn ? 1 : 0), 0))
                Capsule().fill(Palette.hairline)
            }
        }
        .frame(height: height)
        .onAppear { withAnimation(reduceMotion ? nil : Motion.draw.delay(0.15)) { drawn = true } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stillIn) of \(entrants) still in, \(onPace) on pace")
    }
}

// MARK: - Payouts ticker

/// Recent purse splits sliding past, like a departures board for money.
struct PayoutTicker: View {
    let events: [PayoutEvent]
    var onField = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var width: CGFloat = 1

    var body: some View {
        if events.isEmpty {
            EmptyView()
        } else {
            HStack(spacing: 10) {
                LiveTag(color: onField ? Palette.volt : Color(hex: 0x1F9E5B), label: "PAID")
                    .foregroundStyle(onField ? .white : Palette.ink)
                GeometryReader { geo in
                    TimelineView(.animation(minimumInterval: 1 / 60, paused: reduceMotion)) { tl in
                        let speed = 34.0
                        let t = tl.date.timeIntervalSinceReferenceDate
                        let x = reduceMotion ? 0 : -CGFloat((t * speed).truncatingRemainder(dividingBy: Double(width)))
                        HStack(spacing: 0) {
                            row.background(GeometryReader { g in Color.clear.onAppear { width = max(g.size.width, 1) } })
                            row
                        }
                        .offset(x: x)
                        .frame(width: geo.size.width, alignment: .leading)
                    }
                    .clipped()
                    .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.06),
                                                 .init(color: .black, location: 0.94), .init(color: .clear, location: 1)],
                                         startPoint: .leading, endPoint: .trailing))
                }
                .frame(height: 22)
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(onField ? AnyShapeStyle(.white.opacity(0.12)) : AnyShapeStyle(Palette.tyvek), in: Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Recent payouts: " + events.prefix(3).map { "\($0.name) got \($0.amount.formatted) from \($0.purseName)" }.joined(separator: ", "))
        }
    }

    private var row: some View {
        HStack(spacing: 22) {
            ForEach(events) { e in
                HStack(spacing: 6) {
                    Text(e.name).font(.system(.footnote, weight: .bold))
                    Text("+\(e.profit.formatted)")
                        .font(BrandFont.numerals(15, relativeTo: .footnote))
                        .foregroundStyle(onField ? Palette.volt : Color(hex: 0x1F7A52))
                    Text(e.purseName).font(.footnote).opacity(0.7)
                }
                .foregroundStyle(onField ? .white : Palette.ink)
                .fixedSize()
            }
        }
        .padding(.trailing, 22)
    }
}

// MARK: - Stats

/// One fact in the purse stats grid: number in bib numerals, label under it.
struct PurseFact: View {
    let value: String
    let label: String
    var tint: Color = Palette.ink

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(BrandFont.numerals(26, relativeTo: .title3))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label.uppercased())
                .font(BrandFont.label(10))
                .foregroundStyle(Palette.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Coins into the purse

/// Coins arc from the bottom into the purse note when you join: your entry
/// going in. One-shot.
struct CoinDrop: View {
    var count = 14
    @State private var start = Date.now
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            Color.clear
        } else {
            CoinRain(count: count, duration: 1.2, from: UnitPoint(x: 0.5, y: 1.1), to: UnitPoint(x: 0.5, y: 0.22))
        }
    }
}
