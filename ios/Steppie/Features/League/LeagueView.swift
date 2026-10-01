import SwiftUI

/// The weekly league. Grit comes only from walking on race days (more at
/// bigger tables), and the top 7 move up on Sunday night.
struct LeagueView: View {
    @Environment(AppModel.self) private var model
    private static let medals: [UInt32] = [0xFFB020, 0x9AA3B2, 0xC77B3A]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    if model.leagueBoard.isEmpty {
                        empty
                    } else {
                        board
                    }
                    Text("Grit: one point per 100 steps on race days, times your table: Rookie 1.5×, Pacer 2×, Racer 2.5×, Champion 3×, Legend 4×. Practice laps count 1×. Finishing a race adds 100 per day.")
                        .font(.caption)
                        .foregroundStyle(Palette.inkSecondary)
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(Palette.ground)
            .navigationTitle("League")
            .task { await model.loadLeague() }
            .refreshable { await model.loadLeague() }
        }
    }

    private var header: some View {
        let league = model.profile.league
        return HStack(spacing: 16) {
            LeagueBadge(league: league)
                .frame(width: 92, height: 104)
            VStack(alignment: .leading, spacing: 6) {
                Text("\(league.title) League")
                    .font(.system(.title, weight: .heavy))
                    .foregroundStyle(.white)
                Text(endsText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.onFieldSecondary)
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill").foregroundStyle(Palette.volt)
                    Text("\(model.weekGrit.formatted()) Grit this week")
                        .font(BrandFont.numerals(18))
                        .foregroundStyle(.white)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background {
            ZStack {
                Palette.field
                RaysBackground(opacity: 0.06)
                SparkleField(count: 8)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .overlay(alignment: .bottomTrailing) {
            CharacterView(who: .dash, mood: .wink, pose: .point)
                .frame(width: 64, height: 74)
                .offset(x: -8, y: 18)
        }
    }

    private var endsText: String {
        let cal = Calendar(identifier: .iso8601)
        let end = cal.dateInterval(of: .weekOfYear, for: .now)?.end ?? .now
        let days = max(cal.dateComponents([.day], from: .now, to: end).day ?? 0, 0)
        return days == 0 ? "Ends tonight · top 7 move up" : "Ends in \(days) day\(days == 1 ? "" : "s") · top 7 move up"
    }

    private var board: some View {
        VStack(spacing: 0) {
            ForEach(model.leagueBoard, id: \.self) { row in
                if row.rank == 8 { zoneLine("PROMOTION ZONE ↑", color: Color(hex: 0x22B37A)) }
                HStack(spacing: 12) {
                    Text("\(row.rank)")
                        .font(BrandFont.numerals(20))
                        .foregroundStyle(row.rank <= 3 ? Color(hex: Self.medals[row.rank - 1]) : Palette.inkSecondary)
                        .frame(width: 30)
                    Circle()
                        .fill(row.isMe ? Palette.cobalt : Color(hex: avatarColor(row.name)))
                        .frame(width: 34, height: 34)
                        .overlay(Text(String(row.name.prefix(1))).font(.system(.subheadline, weight: .bold)).foregroundStyle(.white))
                    Text(row.isMe ? "\(row.name) (you)" : row.name)
                        .font(.system(.body, weight: row.isMe ? .bold : .medium))
                        .foregroundStyle(Palette.ink)
                    Spacer()
                    Text("\(row.grit.formatted())")
                        .font(BrandFont.numerals(18))
                        .foregroundStyle(Palette.ink)
                        .monospacedDigit()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(row.isMe ? Palette.volt.opacity(0.35) : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(8)
        .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func zoneLine(_ text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Rectangle().fill(color).frame(height: 1.5)
            Text(text).font(BrandFont.label(11)).foregroundStyle(color).fixedSize()
            Rectangle().fill(color).frame(height: 1.5)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
    }

    private func avatarColor(_ name: String) -> UInt32 {
        let palette: [UInt32] = [0x7C5CFF, 0x22B37A, 0xFF9A3C, 0x3D8BFF, 0xE0457B, 0x0E9AA7, 0xA86F42]
        return palette[name.unicodeScalars.reduce(0) { $0 + Int($1.value) } % palette.count]
    }

    private var empty: some View {
        VStack(spacing: 14) {
            CharacterView(who: .dash, mood: .happy, pose: .wave)
                .frame(width: 120, height: 138)
            Text("The league fills up as walkers race")
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(Palette.ink)
            Text("Pin a bib to start earning Grit. Every step on a race day counts, and bigger tables count more.")
                .font(.subheadline)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
            Button("See the races") { model.tab = .races }
                .buttonStyle(.primary)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// A shield-shaped crest in the league's colour with the Stride S.
struct LeagueBadge: View {
    let league: League

    var body: some View {
        ZStack {
            CrestShape().fill(Color(hex: league.color))
            CrestShape().inset(by: 6).fill(.white.opacity(0.18))
            CrestShape().stroke(.white.opacity(0.9), lineWidth: 3)
            StrideShape().fill(.white).frame(width: 30, height: 50).offset(y: -4)
        }
        .shadow(color: Color(hex: league.color).opacity(0.6), radius: 12, y: 4)
        .accessibilityLabel("\(league.title) league")
    }
}

struct CrestShape: InsettableShape {
    var inset: CGFloat = 0

    func path(in r: CGRect) -> Path {
        let r = r.insetBy(dx: inset, dy: inset)
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.14),
                   control1: CGPoint(x: r.midX + r.width * 0.2, y: r.minY + r.height * 0.08),
                   control2: CGPoint(x: r.maxX - r.width * 0.12, y: r.minY + r.height * 0.14))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.5))
        p.addCurve(to: CGPoint(x: r.midX, y: r.maxY),
                   control1: CGPoint(x: r.maxX, y: r.minY + r.height * 0.78),
                   control2: CGPoint(x: r.midX + r.width * 0.2, y: r.maxY - r.height * 0.06))
        p.addCurve(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.5),
                   control1: CGPoint(x: r.midX - r.width * 0.2, y: r.maxY - r.height * 0.06),
                   control2: CGPoint(x: r.minX, y: r.minY + r.height * 0.78))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.14))
        p.addCurve(to: CGPoint(x: r.midX, y: r.minY),
                   control1: CGPoint(x: r.minX + r.width * 0.12, y: r.minY + r.height * 0.14),
                   control2: CGPoint(x: r.midX - r.width * 0.2, y: r.minY + r.height * 0.08))
        p.closeSubpath()
        return p
    }

    func inset(by amount: CGFloat) -> CrestShape { CrestShape(inset: inset + amount) }
}
