import SwiftUI

/// Collectible medals earned from real walking. Celebrated once, kept forever.
struct Milestone: Identifiable, Hashable {
    enum Kind: Hashable { case km, streak, races, season }

    let id: String
    let title: String
    let detail: String
    let symbol: String
    let kind: Kind
    let threshold: Double

    /// What's struck on the medal face: the real number, in bib numerals.
    var face: (big: String, small: String) {
        switch kind {
        case .km: return (threshold >= 1000 ? "1K" : String(Int(threshold.rounded(.down))), "KM")
        case .streak: return (String(Int(threshold)), "DAYS")
        case .races: return (String(Int(threshold)), threshold == 1 ? "RACE" : "RACES")
        case .season: return ("OCT", "2026")
        }
    }

    static let all: [Milestone] = [
        .init(id: "km-21", title: "Half Marathon", detail: "Walk 21.1 km", symbol: "figure.walk", kind: .km, threshold: 21.1),
        .init(id: "km-42", title: "Marathon", detail: "Walk 42.2 km", symbol: "medal", kind: .km, threshold: 42.2),
        .init(id: "km-100", title: "Century", detail: "Walk 100 km", symbol: "100.circle", kind: .km, threshold: 100),
        .init(id: "km-250", title: "Road Tripper", detail: "Walk 250 km", symbol: "map", kind: .km, threshold: 250),
        .init(id: "km-500", title: "Long Haul", detail: "Walk 500 km", symbol: "mountain.2", kind: .km, threshold: 500),
        .init(id: "km-1000", title: "Thousand Club", detail: "Walk 1,000 km", symbol: "globe.europe.africa", kind: .km, threshold: 1000),
        .init(id: "streak-3", title: "Warm Up", detail: "3-day streak", symbol: "flame", kind: .streak, threshold: 3),
        .init(id: "streak-7", title: "Full Week", detail: "7-day streak", symbol: "flame.fill", kind: .streak, threshold: 7),
        .init(id: "streak-14", title: "Fortnight", detail: "14-day streak", symbol: "calendar", kind: .streak, threshold: 14),
        .init(id: "streak-30", title: "Iron Paws", detail: "30-day streak", symbol: "crown", kind: .streak, threshold: 30),
        .init(id: "races-1", title: "First Bib", detail: "Finish a race", symbol: "flag.checkered", kind: .races, threshold: 1),
        .init(id: "races-5", title: "Regular", detail: "Finish 5 races", symbol: "rosette", kind: .races, threshold: 5),
        .init(id: "walktober-2026", title: "Walktober 2026", detail: "Finish a race in October", symbol: "leaf", kind: .season, threshold: 1),
    ]
}

/// October launch campaign: finish any race (practice laps count) during
/// October for a limited medal. Cosmetic only, no money involved.
enum Walktober {
    static func isOn(_ date: Date = .now) -> Bool {
        let c = Calendar.current.dateComponents([.year, .month], from: date)
        return c.year == 2026 && c.month == 10
    }

    static func daysLeft(_ date: Date = .now) -> Int {
        let cal = Calendar.current
        guard let end = cal.date(from: DateComponents(year: 2026, month: 11, day: 1)) else { return 0 }
        return max(cal.dateComponents([.day], from: cal.startOfDay(for: date), to: end).day ?? 0, 0)
    }
}

// MARK: - Medal

struct MedalView: View {
    let milestone: Milestone
    let earned: Bool
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            Circle()
                .fill(earned ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFFD25A), Color(hex: 0xF0A21E)], startPoint: .top, endPoint: .bottom))
                             : AnyShapeStyle(Palette.tyvek))
            Circle()
                .strokeBorder(earned ? Color(hex: 0xD9861A) : Palette.hairline, lineWidth: size * 0.06)
            Circle()
                .strokeBorder(earned ? Color.white.opacity(0.5) : Color.clear, lineWidth: 1)
                .padding(size * 0.12)
            VStack(spacing: -size * 0.02) {
                Text(milestone.face.big)
                    .font(BrandFont.numerals(size * (milestone.face.big.count > 2 ? 0.3 : 0.38)))
                Text(milestone.face.small)
                    .font(BrandFont.label(size * 0.13))
                    .kerning(0.5)
            }
            .foregroundStyle(earned ? Color(hex: 0x7A3E00) : Palette.inkSecondary.opacity(0.55))
        }
        .frame(width: size, height: size)
        .shadow(color: earned ? Color(hex: 0xF0A21E).opacity(0.35) : .clear, radius: 8, y: 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(milestone.title), \(earned ? "earned" : "locked"). \(milestone.detail).")
    }
}

/// Trophy case for the Progress screen.
struct TrophyCase: View {
    @Environment(AppModel.self) private var model
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Trophy case").font(.system(.title3, weight: .bold))
                Spacer()
                Text("\(model.earnedMilestones.count) of \(Milestone.all.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.inkSecondary)
            }
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Milestone.all) { m in
                    let earned = model.earnedMilestones.contains(m.id)
                    VStack(spacing: 6) {
                        MedalView(milestone: m, earned: earned, size: 58)
                        Text(m.title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(earned ? Palette.ink : Palette.inkSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
            .padding(16)
            .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

/// Celebration when a medal is earned: medal drops in, Grin hops, confetti.
struct MilestoneSheet: View {
    let milestone: Milestone
    @Environment(\.dismiss) private var dismiss
    @State private var shown = false
    @State private var hop = 0

    var body: some View {
        ZStack {
            Palette.field.ignoresSafeArea()
            ConfettiBurst(count: 60)
            VStack(spacing: 18) {
                Spacer()
                MedalView(milestone: milestone, earned: true, size: 120)
                    .scaleEffect(shown ? 1 : 0.6)
                    .rotationEffect(.degrees(shown ? 0 : -25))
                    .opacity(shown ? 1 : 0)
                Text(milestone.title)
                    .font(.system(.largeTitle, weight: .heavy))
                    .foregroundStyle(.white)
                Text(milestone.detail + ". That's going in the trophy case.")
                    .font(.body)
                    .foregroundStyle(Palette.onFieldSecondary)
                    .multilineTextAlignment(.center)
                GrinView(mood: .proud, pose: .cheer, mane: 2, hop: hop)
                    .frame(height: 190)
                    .padding(.top, 8)
                Spacer()
                ShareLink(item: "I just earned the \(milestone.title) medal on Grinda. #WalkItOff") {
                    Label("Share it", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.volt)
                Button("Keep walking") { dismiss() }
                    .buttonStyle(.onField)
            }
            .padding(24)
        }
        .task {
            withAnimation(Motion.snap.delay(0.15)) { shown = true }
            try? await Task.sleep(for: .milliseconds(450))
            Haptics.success()
            hop += 1
        }
    }
}

/// Walktober banner for the Races board.
struct WalktoberBanner: View {
    var body: some View {
        HStack(spacing: 14) {
            MedalView(milestone: Milestone.all.last!, earned: true, size: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text("Walktober is on")
                    .font(.system(.headline, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Text("Finish any race this month, practice laps too, for a medal that only exists in October. \(Walktober.daysLeft()) days left.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color(hex: 0xF0A21E).opacity(0.5), lineWidth: 1.5))
    }
}
