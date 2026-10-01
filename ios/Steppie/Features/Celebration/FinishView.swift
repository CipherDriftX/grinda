import SwiftUI

/// The biggest designed moment in the app: breaking the tape and getting the
/// money back. Variable reward, delivered honestly.
struct FinishView: View {
    let race: Race
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var broken = false
    @State private var shownAmount = 0
    @State private var revealed = false
    @State private var gritShown = 0

    /// The ladder: after a finish, the next race suggests one rung up.
    private var nextLabel: String {
        guard let s = stake else { return "Now put something on it" }
        let next = Money(units: StakeLadder.next(after: s.units), currency: s.currency)
        return "Level up: race for \(next.formatted)"
    }

    private var stake: Money? { race.stake }

    var body: some View {
        ZStack {
            Palette.field.ignoresSafeArea()
            RaysBackground(opacity: broken ? 0.09 : 0)
                .animation(.easeOut(duration: 0.8), value: broken)
            if broken { ConfettiBurst(count: 120) }
            if broken && stake != nil { CoinRain(count: 30) }
            VStack(spacing: 0) {
                Spacer(minLength: 24)
                FinishTape(broken: broken)
                    .frame(height: 64)
                    .padding(.bottom, 8)
                ZStack(alignment: .bottom) {
                    CharacterView(who: .bo, mood: broken ? .cheer : .happy, pose: broken ? .wave : .idle)
                        .frame(width: 84, height: 96)
                        .offset(x: -116)
                        .opacity(revealed && stake != nil ? 1 : 0)
                    CharacterView(who: .dash, mood: .wink, pose: .wave)
                        .frame(width: 80, height: 92)
                        .offset(x: 116)
                        .opacity(revealed ? 1 : 0)
                    SteppieView(mood: broken ? .cheer : .proud, pose: broken ? .cheer : .idle, mane: model.maneLevel, shoes: model.wearing, hop: broken ? 1 : 0)
                        .frame(height: 180)
                }
                .padding(.bottom, 8)
                amount
                Text(detail)
                    .font(.body)
                    .foregroundStyle(Palette.onFieldSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 10)
                    .opacity(revealed ? 1 : 0)
                statsLine
                    .padding(.top, 24)
                    .opacity(revealed ? 1 : 0)
                gritLine
                    .padding(.top, 16)
                    .opacity(revealed ? 1 : 0)
                Spacer()
                actions
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .opacity(revealed ? 1 : 0)
                    .offset(y: revealed ? 0 : 16)
            }
        }
        .task { await play() }
    }

    private var amount: some View {
        VStack(spacing: 0) {
            if let stake {
                Text(Money(cents: shownAmount, currency: stake.currency).formatted)
                    .font(BrandFont.numerals(96))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(value: Double(shownAmount)))
                    .monospacedDigit()
                Text("BACK TO YOU")
                    .font(BrandFont.label(18))
                    .kerning(2)
                    .foregroundStyle(Palette.volt)
            } else {
                Text("Finished")
                    .font(.system(size: 56, weight: .heavy))
                    .foregroundStyle(.white)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        guard let stake else { return "Practice lap done. Imagine that with something on the line." }
        let card = race.cardLast4.map { " ending \($0)" } ?? ""
        return race.usesHold
            ? "The \(stake.formatted) hold on your card\(card) is released. Nothing was charged."
            : "\(stake.formatted) is on its way back to your card\(card). You earned that."
    }

    private var statsLine: some View {
        HStack(spacing: 18) {
            stat("\(race.hitCount)/\(race.days.count)", "days")
            stat(race.totalSteps.formatted(), "steps")
            stat(Estimate.km(steps: race.totalSteps).formatted(.number.precision(.fractionLength(1))), "km")
        }
    }

    private func stat(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(BrandFont.numerals(26, relativeTo: .title3)).foregroundStyle(.white)
            Text(l).font(.caption.weight(.medium)).foregroundStyle(Palette.onFieldSecondary)
        }
    }

    private var grit: Int { Grit.finish(days: race.days.count, tier: race.tier) }

    private var gritLine: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill").foregroundStyle(Palette.volt)
            Text("+\(gritShown.formatted()) Grit")
                .font(BrandFont.numerals(22))
                .foregroundStyle(.white)
                .contentTransition(.numericText(value: Double(gritShown)))
            if let tier = race.tier {
                Text("\(tier.title) table · \(tier.multiplier.formatted())×")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.onFieldSecondary)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(.white.opacity(0.12), in: Capsule())
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                dismiss()
                Task { try? await Task.sleep(for: .milliseconds(450)); model.showingShoeBox = true }
            } label: {
                Label("Open your Shoe Box", systemImage: "shippingbox.fill")
            }
            .buttonStyle(.onField)
            .shimmer()
            ShareLink(item: ShareCardRenderer.image(for: race, stepsToday: 0),
                      preview: SharePreview("I finished \(race.name) on Steppie", image: ShareCardRenderer.image(for: race, stepsToday: 0))) {
                Label("Share the finish", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.volt)
            Button(nextLabel) {
                model.tab = .races
                dismiss()
            }
            .font(.system(.headline, weight: .semibold))
            .foregroundStyle(.white)
            .frame(minHeight: 44)
            Button("Done") { dismiss() }
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(.white)
                .frame(minHeight: 44)
        }
    }

    private func play() async {
        try? await Task.sleep(for: .milliseconds(600))
        Haptics.success()
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : Motion.snap) { broken = true }
        guard let stake else {
            withAnimation(Motion.standard.delay(0.2)) { revealed = true }
            await countGrit()
            return
        }
        try? await Task.sleep(for: .milliseconds(250))
        if reduceMotion {
            shownAmount = stake.cents
        } else {
            let steps = 14
            for i in 1...steps {
                withAnimation(.snappy(duration: 0.12)) { shownAmount = stake.cents * i / steps }
                try? await Task.sleep(for: .milliseconds(45))
            }
            Haptics.pin()
        }
        withAnimation(Motion.standard) { revealed = true }
        await countGrit()
    }

    private func countGrit() async {
        let steps = 16
        for i in 1...steps {
            withAnimation(.snappy(duration: 0.1)) { gritShown = grit * i / steps }
            try? await Task.sleep(for: .milliseconds(35))
        }
        Haptics.tick()
    }
}

/// Volt finish tape that snaps in two.
private struct FinishTape: View {
    let broken: Bool

    var body: some View {
        GeometryReader { geo in
            let half = geo.size.width / 2
            HStack(spacing: 0) {
                tapeHalf(width: half)
                    .rotationEffect(.degrees(broken ? -38 : 0), anchor: .leading)
                    .offset(x: broken ? -half * 0.35 : 0, y: broken ? 140 : 0)
                tapeHalf(width: half)
                    .rotationEffect(.degrees(broken ? 38 : 0), anchor: .trailing)
                    .offset(x: broken ? half * 0.35 : 0, y: broken ? 140 : 0)
            }
            .opacity(broken ? 0 : 1)
            .animation(.easeIn(duration: 0.5).delay(0.15), value: broken)
        }
        .accessibilityHidden(true)
    }

    private func tapeHalf(width: CGFloat) -> some View {
        ZStack {
            Rectangle().fill(Palette.volt)
            HStack(spacing: 18) {
                ForEach(0..<3, id: \.self) { _ in
                    Text("FINISH").font(BrandFont.label(20)).kerning(3).foregroundStyle(Palette.onVolt)
                }
            }
            .fixedSize()
        }
        .frame(width: width, height: 40)
        .clipped()
    }
}
