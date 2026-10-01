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

    private var stake: Money? { race.stake }

    var body: some View {
        ZStack {
            Palette.field.ignoresSafeArea()
            if broken { ConfettiBurst(count: 90) }
            VStack(spacing: 0) {
                Spacer(minLength: 24)
                FinishTape(broken: broken)
                    .frame(height: 64)
                    .padding(.bottom, 8)
                GrinView(mood: broken ? .cheer : .proud, pose: broken ? .cheer : .idle, mane: 3, hop: broken ? 1 : 0)
                    .frame(height: 170)
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
                    .padding(.top, 28)
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

    private var actions: some View {
        VStack(spacing: 10) {
            ShareLink(item: ShareCardRenderer.image(for: race, stepsToday: 0),
                      preview: SharePreview("I finished \(race.name) on Grinda", image: ShareCardRenderer.image(for: race, stepsToday: 0))) {
                Label("Share the finish", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.volt)
            Button("Run it back") {
                model.tab = .races
                dismiss()
            }
            .buttonStyle(.onField)
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
                    .rotationEffect(.degrees(broken ? -14 : 0), anchor: .leading)
                    .offset(x: broken ? -half * 0.55 : 0, y: broken ? 26 : 0)
                tapeHalf(width: half)
                    .rotationEffect(.degrees(broken ? 14 : 0), anchor: .trailing)
                    .offset(x: broken ? half * 0.55 : 0, y: broken ? 26 : 0)
            }
            .opacity(broken ? 0.9 : 1)
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
