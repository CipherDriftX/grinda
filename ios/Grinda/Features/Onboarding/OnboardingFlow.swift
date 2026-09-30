import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case welcome, why, body, health, baseline, how, notifications
}

/// First run. Builds the internal trigger (your why), connects Health, sets a
/// goal from your real baseline, and explains the money before asking for any.
struct OnboardingFlow: View {
    var start: OnboardingStep = .welcome
    @Environment(AppModel.self) private var model
    @State private var step: OnboardingStep = .welcome
    @State private var forward = true

    var body: some View {
        ZStack {
            (step == .welcome ? Palette.field : Palette.ground).ignoresSafeArea()
            VStack(spacing: 0) {
                if step != .welcome {
                    OnboardingProgress(step: step)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .transition(.opacity)
                }
                Group {
                    switch step {
                    case .welcome: WelcomeStep { go(.why) }
                    case .why: WhyStep { go(.body) }
                    case .body: BodyStep { go(.health) }
                    case .health: HealthStep { go(.baseline) }
                    case .baseline: BaselineStep { go(.how) }
                    case .how: HowStep { go(.notifications) }
                    case .notifications: NotificationsStep { finish() }
                    }
                }
                .id(step)
                .transition(.asymmetric(
                    insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
                ))
            }
        }
        .animation(Motion.standard, value: step)
        .onAppear { step = start }
    }

    private func go(_ next: OnboardingStep) {
        forward = next.rawValue > step.rawValue
        step = next
    }

    private func finish() {
        model.completeOnboarding()
        model.tab = .races
    }
}

/// A tiny lane with the runner moving along it: where you are in setup.
private struct OnboardingProgress: View {
    let step: OnboardingStep

    private var fraction: CGFloat {
        CGFloat(step.rawValue) / CGFloat(OnboardingStep.allCases.count - 1)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.hairline).frame(height: 4)
                Capsule().fill(Palette.cobalt).frame(width: geo.size.width * fraction, height: 4)
                Circle().fill(Palette.cobalt).frame(width: 12, height: 12)
                    .offset(x: geo.size.width * fraction - 6)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 20)
        .animation(Motion.standard, value: step)
        .accessibilityLabel("Step \(step.rawValue) of \(OnboardingStep.allCases.count - 1)")
    }
}

/// Shared layout for the white onboarding steps.
struct StepScaffold<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    let cta: String
    var ctaEnabled = true
    var secondary: (label: String, action: () -> Void)? = nil
    let action: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(title)
                            .font(.system(.largeTitle, weight: .bold))
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        if let subtitle {
                            Text(subtitle)
                                .font(.body)
                                .foregroundStyle(Palette.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    content
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
            }
            VStack(spacing: 6) {
                Button(cta, action: action)
                    .buttonStyle(.primary)
                    .disabled(!ctaEnabled)
                if let secondary {
                    Button(secondary.label, action: secondary.action)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(Palette.inkSecondary)
                        .frame(minHeight: 44)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Steps

private struct WelcomeStep: View {
    let next: () -> Void
    @State private var shown = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            GTrackMark(color: .white, animated: true)
                .frame(width: 132)
                .padding(.bottom, 40)
            Text("Walk it off.\nKeep your money.")
                .font(.system(size: 44, weight: .heavy))
                .kerning(-0.8)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(shown ? 1 : 0)
                .offset(y: shown ? 0 : 10)
            Text("Put money on your daily walk. Hit your steps and every cent comes back. It's the push that finally makes the weight come off.")
                .font(.title3)
                .foregroundStyle(Palette.onFieldSecondary)
                .padding(.top, 16)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(shown ? 1 : 0)
            Spacer()
            Button("Get started", action: next)
                .buttonStyle(.onField)
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                Text("Payments by Stripe · Steps from Apple Health")
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(Palette.onFieldSecondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 14)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 24)
        .onAppear { withAnimation(Motion.standard.delay(0.9)) { shown = true } }
    }
}

private struct WhyStep: View {
    let next: () -> Void
    @Environment(AppModel.self) private var model

    var body: some View {
        StepScaffold(title: "What brings you here?", subtitle: "We'll remind you of this on the hard days.",
                     cta: "Continue", ctaEnabled: model.profile.why != nil, action: next) {
            VStack(spacing: 10) {
                ForEach(WalkingWhy.allCases) { why in
                    let selected = model.profile.why == why
                    Button {
                        model.profile.why = why
                        Haptics.tick()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: why.symbol)
                                .font(.title3)
                                .frame(width: 30)
                            Text(why.title)
                                .font(.system(.headline, weight: .semibold))
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                        }
                        .foregroundStyle(selected ? .white : Palette.ink)
                        .padding(18)
                        .background(selected ? Palette.cobalt : Palette.tyvek,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .animation(Motion.standard, value: model.profile.why)
        }
    }
}

private struct BodyStep: View {
    let next: () -> Void
    @Environment(AppModel.self) private var model
    @State private var weight: Int = 85
    @State private var goal: Int = 78

    private var metric: Bool { model.profile.usesMetric }
    private var unit: String { metric ? "kg" : "lb" }
    private var range: ClosedRange<Int> { metric ? 40...200 : 90...440 }

    var body: some View {
        StepScaffold(title: "Where are you starting?", subtitle: "Only you see this. It lets us turn steps into something that matters to you.",
                     cta: "Continue", secondary: ("Skip for now", next), action: save) {
            HStack(spacing: 12) {
                picker("Now", $weight)
                Image(systemName: "arrow.right").foregroundStyle(Palette.inkSecondary)
                picker("Goal", $goal)
            }
            if weight > goal {
                Text("\(weight - goal) \(unit) to go. At a steady 0.5 \(metric ? "kg" : "lb") a week, that's about \(weeks) weeks.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
        .onAppear {
            if !metric { weight = 187; goal = 172 }
        }
    }

    private var weeks: Int { Int((Double(weight - goal) / (metric ? 0.5 : 1.1)).rounded()) }

    private func picker(_ label: String, _ value: Binding<Int>) -> some View {
        VStack(spacing: 4) {
            Text(label.uppercased()).font(BrandFont.label(12)).foregroundStyle(Palette.inkSecondary)
            Picker(label, selection: value) {
                ForEach(range, id: \.self) { Text("\($0) \(unit)").tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(height: 150)
        }
        .frame(maxWidth: .infinity)
        .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func save() {
        let toKg = metric ? 1.0 : 0.453_592
        model.profile.weightKg = Double(weight) * toKg
        model.profile.goalWeightKg = Double(goal) * toKg
        model.persist()
        next()
    }
}

private struct HealthStep: View {
    let next: () -> Void
    @Environment(AppModel.self) private var model
    @State private var connecting = false

    private let sources = ["iPhone", "Apple Watch", "Garmin", "Fitbit", "Oura", "Withings", "Samsung"]

    var body: some View {
        StepScaffold(title: "Connect your steps",
                     subtitle: "Grinda reads steps from Apple Health, so anything that syncs to Health counts.",
                     cta: model.healthConnected ? "Continue" : "Connect Apple Health",
                     action: { model.healthConnected ? next() : connect() }) {
            FlowChips(items: sources)
            VStack(alignment: .leading, spacing: 12) {
                PrivacyLine(symbol: "hand.raised.fill", text: "We read steps, distance and weight. Nothing else.")
                PrivacyLine(symbol: "eye.slash.fill", text: "Your health data is never sold or used for ads.")
                PrivacyLine(symbol: "keyboard", text: "Steps typed in by hand don't count toward races.")
            }
            if connecting { ProgressView().frame(maxWidth: .infinity) }
        }
    }

    private func connect() {
        connecting = true
        Task {
            await model.connectHealth()
            connecting = false
            if model.healthConnected { next() }
        }
    }
}

struct PrivacyLine: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(Palette.cobalt).frame(width: 22)
            Text(text).font(.subheadline).foregroundStyle(Palette.ink)
        }
    }
}

struct FlowChips: View {
    let items: [String]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { chips(items) }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) { chips(Array(items.prefix(4))) }
                HStack(spacing: 8) { chips(Array(items.dropFirst(4))) }
            }
        }
    }

    private func chips(_ list: [String]) -> some View {
        ForEach(list, id: \.self) { s in
            Text(s)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Palette.tyvek, in: Capsule())
        }
    }
}

private struct BaselineStep: View {
    let next: () -> Void
    @Environment(AppModel.self) private var model
    @State private var goal = 8_000

    private var baseline: Int { model.profile.baseline ?? 0 }
    private var extra: Int { max(goal - baseline, 0) }

    var body: some View {
        StepScaffold(title: baseline > 0 ? "Here's your starting line" : "Pick a daily goal",
                     subtitle: baseline > 0 ? "Your average over the last two weeks:" : "Most adults do well between 7,000 and 10,000 steps a day.",
                     cta: "Set \(goal.formatted()) a day", action: save) {
            if baseline > 0 {
                Text(baseline.formatted())
                    .font(BrandFont.numerals(76))
                    .foregroundStyle(Palette.inkSecondary)
                    .padding(.top, -12)
            }
            VStack(spacing: 14) {
                Text("YOUR GOAL")
                    .font(BrandFont.label(13))
                    .foregroundStyle(Palette.inkSecondary)
                HStack {
                    RoundButton(symbol: "minus") { adjust(-500) }
                    Spacer()
                    Text(goal.formatted())
                        .font(BrandFont.numerals(72))
                        .foregroundStyle(Palette.cobalt)
                        .contentTransition(.numericText(value: Double(goal)))
                    Spacer()
                    RoundButton(symbol: "plus") { adjust(500) }
                }
                if extra > 0 {
                    let kcal = Estimate.kcal(steps: extra, weightKg: model.profile.weightKg)
                    Text("That's \(extra.formatted()) more steps a day: about \(kcal) kcal, or roughly \(Estimate.fatKg(kcal: kcal * 30).formatted(.number.precision(.fractionLength(1)))) kg of fat a month.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.inkSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
            .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .onAppear { goal = Estimate.suggestedGoal(baseline: model.profile.baseline) }
    }

    private func adjust(_ d: Int) {
        let new = min(max(goal + d, 3_000), 25_000)
        guard new != goal else { return }
        Haptics.tick()
        withAnimation(Motion.standard) { goal = new }
    }

    private func save() {
        model.profile.dailyGoal = goal
        model.persist()
        next()
    }
}

struct RoundButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3.weight(.bold))
                .foregroundStyle(Palette.cobalt)
                .frame(width: 52, height: 52)
                .background(Palette.cobalt.opacity(0.1), in: Circle())
        }
        .buttonStyle(.pressable)
    }
}

private struct HowStep: View {
    let next: () -> Void

    var body: some View {
        StepScaffold(title: "How it works", subtitle: "Three steps. No fine print.", cta: "Got it", action: next) {
            VStack(spacing: 12) {
                HowRow(n: "1", title: "Pin a bib", text: "Choose a race and a stake. Short races are only a hold on your card, never a charge if you finish.")
                HowRow(n: "2", title: "Walk your laps", text: "Your iPhone or watch counts. We nudge you once in the evening if you're behind, never more.")
                HowRow(n: "3", title: "Get it all back", text: "Finish and your money is back within minutes of settling. Every cent is visible in your Wallet.")
            }
            Text("Miss, and the stake is kept. That's the deal that makes it work, and why people with money on the line finish about three times in four.")
                .font(.footnote)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct HowRow: View {
    let n: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(n)
                .font(BrandFont.numerals(40))
                .foregroundStyle(Palette.cobalt)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(.headline, weight: .bold)).foregroundStyle(Palette.ink)
                Text(text).font(.subheadline).foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct NotificationsStep: View {
    let next: () -> Void
    @Environment(AppModel.self) private var model

    var body: some View {
        StepScaffold(title: "One nudge, only when it helps",
                     subtitle: "If you're behind in the evening, we'll tell you exactly how far to walk. That's it.",
                     cta: "Allow notifications", secondary: ("Not now", next), action: allow) {
            HStack(alignment: .top, spacing: 12) {
                Image("GTrack")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white)
                    .padding(7)
                    .frame(width: 38, height: 38)
                    .background(Palette.cobalt, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Keep your \(Money(units: 20).formatted)").font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("19:30").font(.caption).foregroundStyle(Palette.inkSecondary)
                    }
                    Text("About 1,840 steps left today. A 19-minute walk does it.")
                        .font(.subheadline)
                }
                .foregroundStyle(Palette.ink)
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Example notification")
        }
    }

    private func allow() {
        Task {
            model.profile.notificationsEnabled = await NotificationService.requestPermission()
            model.persist()
            next()
        }
    }
}
