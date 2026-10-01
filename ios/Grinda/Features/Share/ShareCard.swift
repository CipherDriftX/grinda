import SwiftUI

/// 1080 × 1350 share card for X and Discord. Uses only the person's own race data.
struct ShareCardView: View {
    let race: Race
    let stepsToday: Int

    private var finished: Bool { race.status == .won }
    private var progress: Double {
        guard !race.days.isEmpty else { return 0 }
        return Double(race.hitCount) / Double(race.days.count)
    }

    var body: some View {
        ZStack {
            Palette.field
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(race.name.uppercased()).font(BrandFont.label(20)).kerning(1.5)
                    Spacer()
                    Text("Nº \(String(race.bibNumber))").font(BrandFont.label(20))
                }
                .foregroundStyle(Palette.onFieldSecondary)

                ZStack {
                    TrackShape(inset: 22).stroke(Palette.lane, lineWidth: 34)
                    TrackShape(progress: progress, inset: 22)
                        .stroke(finished ? Palette.volt : .white, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    VStack(spacing: 0) {
                        Text(finished ? "FINISHED" : "DAY \(race.hitCount + 1) OF \(race.days.count)")
                            .font(BrandFont.label(18)).kerning(2)
                            .foregroundStyle(finished ? Palette.volt : Palette.onFieldSecondary)
                        Text(race.totalSteps.formatted())
                            .font(BrandFont.numerals(76))
                            .foregroundStyle(.white)
                        Text("steps").font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.onFieldSecondary)
                    }
                }
                .frame(height: 220)
                .padding(.top, 26)

                Spacer()

                Text(headline)
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.trailing, 96)
                Text("#WalkItOff")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.onFieldSecondary)
                    .padding(.top, 8)

                HStack {
                    Image("Lockup").resizable().scaledToFit().frame(height: 26)
                    Spacer()
                    Text("grinda.app").font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.onFieldSecondary)
                }
                .padding(.top, 26)
            }
            .padding(30)
        }
        .overlay(alignment: .bottomTrailing) {
            GrinView(mood: finished ? .cheer : .happy, pose: finished ? .cheer : .wave, mane: 2, animated: false)
                .frame(width: 104, height: 120)
                .padding(.trailing, 18)
                .padding(.bottom, 64)
        }
        .frame(width: 360, height: 450)
    }

    private var headline: String {
        if let stake = race.stake {
            return finished ? "\(stake.formatted) back. Every cent." : "\(stake.formatted) on the line. Not losing it."
        }
        return finished ? "Practice lap: done." : "Walking it off."
    }
}

@MainActor
enum ShareCardRenderer {
    static func image(for race: Race, stepsToday: Int) -> Image {
        let renderer = ImageRenderer(content: ShareCardView(race: race, stepsToday: stepsToday).environment(\.colorScheme, .light))
        renderer.scale = 3
        if let ui = renderer.uiImage { return Image(uiImage: ui) }
        return Image("Lockup")
    }
}
