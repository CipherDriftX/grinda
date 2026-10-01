import SwiftUI

/// The whole deal on one screen, in plain words, ending in hold-to-pin.
struct ContractView: View {
    let template: RaceTemplate
    var initialStake: Int? = nil
    var previewPins: Int = 0
    var autoplay = false
    var showEntered = false

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var stake: Int = 0
    @State private var startToday = Calendar.current.component(.hour, from: .now) < 14
    @State private var pins = 0
    @State private var attempt = 0
    @State private var working = false
    @State private var entered = false
    @State private var error: String?
    @State private var showGate = false
    @State private var shields = 0

    private var isPractice: Bool { template.kind == .practice }
    private var money: Money { Money(units: stake) }
    private var dates: [Date] { AppModel.schedule(for: template, startingToday: startToday) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                BibCard(template: template, stake: isPractice ? nil : stake, bibNumber: 2_417, pinned: pins, startingToday: startToday)
                    .padding(.top, 8)

                if template.isComeback, let lost = model.comebackOffer { comebackNote(lost) }
                if !isPractice { stakePicker }
                if !isPractice { shieldPicker }
                startPicker
                deal
                whatCounts
                commit
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .background(Palette.ground)
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if stake == 0 { stake = initialStake ?? model.suggestedStake(for: template) ?? template.suggestedStakes.first ?? 0 }
            if !isPractice && model.profile.shields > 0 && shields == 0 { shields = min(model.profile.shields, 1) }
            if previewPins > 0 { pins = previewPins }
            if showEntered { entered = true }
        }
        .alert("Couldn't start the race", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil; rearm() }
        } message: { Text(error ?? "") }
        .sheet(isPresented: $showGate, onDismiss: rearm) { AccountGate() }
        .fullScreenCover(isPresented: $entered) {
            EnteredOverlay(bib: model.races.first?.bibNumber ?? 2_417) {
                entered = false
                dismiss()
                model.tab = .today
            }
        }
    }

    // MARK: Sections

    private var stakePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your stake").font(.system(.title3, weight: .bold))
                Spacer()
                TierBadge(tier: StakeTier.tier(units: stake))
            }
            HStack(spacing: 10) {
                ForEach(template.suggestedStakes, id: \.self) { amount in
                    let tier = StakeTier.tier(units: amount)
                    let open = model.isUnlocked(tier)
                    Button {
                        guard open else { Haptics.warning(); return }
                        withAnimation(Motion.snap) { stake = amount }
                        Haptics.pin()
                    } label: {
                        StakeChip(amount: amount, selected: stake == amount, locked: !open, ladder: amount == ladderPick && stake != amount)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel(open ? Money(units: amount).formatted : "\(Money(units: amount).formatted), opens after \(tier.unlockAfter) finished races")
                    .accessibilityAddTraits(stake == amount ? .isSelected : [])
                }
            }
            Text(stakeHint)
                .font(.footnote)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
        }
    }

    private var ladderPick: Int? { model.suggestedStake(for: template) }

    private var stakeHint: String {
        let tier = StakeTier.tier(units: stake)
        let grit = Grit.finish(days: template.days, tier: tier)
        let base = "\(tier.title) table: every step earns \(tier.multiplier.formatted())× Grit, plus \(grit.formatted()) Grit for the finish."
        if model.finishedStakedCount == 0 { return base + " First race? Pick an amount you'd hate to lose but won't miss." }
        return base
    }

    /// Shelly's Shields: equip up to two, each covers one missed day; unused ones come back.
    private var shieldPicker: some View {
        HStack(spacing: 14) {
            CharacterView(who: .shelly, mood: shields > 0 ? .cheer : .happy, hop: shields)
                .frame(width: 58, height: 66)
            VStack(alignment: .leading, spacing: 3) {
                Text(shields == 0 ? "No Shields" : "\(shields) Shield\(shields == 1 ? "" : "s") equipped")
                    .font(.system(.headline, weight: .bold))
                Text(model.profile.shields == 0 ? "Each Shield covers one missed day." : "\(model.profile.shields) in your locker. Unused ones come back after the race.")
                    .font(.footnote)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if model.profile.shields == 0 {
                Button("Get") { model.showingShields = true }
                    .font(.system(.subheadline, weight: .bold))
                    .buttonStyle(.bordered)
                    .tint(Color(hex: 0x2E9E6B))
            } else {
                Stepper("", value: $shields, in: 0...min(model.profile.shields, 2))
                    .labelsHidden()
                    .onChange(of: shields) { Haptics.tick() }
            }
        }
        .padding(14)
        .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func comebackNote(_ lost: Race) -> some View {
        let back = Money(cents: (lost.stake?.cents ?? 0) / 2, currency: lost.stake?.currency ?? model.currency)
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.uturn.backward.circle.fill").font(.title2).foregroundStyle(Palette.cobalt)
            Text("Finish this and \(back.formatted) from your missed \(lost.name) comes back on top of your stake. One comeback per race, and it closes \(model.comebackDeadline(lost).formatted(.relative(presentation: .named))).")
                .font(.subheadline)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Palette.cobalt.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var startPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Starts").font(.system(.title3, weight: .bold))
            Picker("Starts", selection: $startToday) {
                Text("Today").tag(true)
                Text("Tomorrow").tag(false)
            }
            .pickerStyle(.segmented)
            if startToday {
                let left = max(24 - Calendar.current.component(.hour, from: .now), 0)
                Text(left <= 10 ? "Today counts as day 1, and it ends in about \(left) hours. Tomorrow is the safer start." : "Today counts as day 1.")
                    .font(.footnote)
                    .foregroundStyle(left <= 10 ? Palette.risk : Palette.inkSecondary)
            }
        }
    }

    private var deal: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("The deal").font(.system(.title3, weight: .bold))
            DealLine(symbol: "figure.walk", text: "Walk \(template.dailyGoal.formatted()) steps a day on \(dates.count) days, \(rangeText).")
            if isPractice {
                DealLine(symbol: "sparkles", text: "No money involved. Finish to see what a staked race feels like.")
            } else if template.usesHold {
                DealLine(symbol: "lock.shield", text: "We place a \(money.formatted) hold on your card. Finish, and the hold is released. Nothing is ever charged.")
            } else {
                DealLine(symbol: "arrow.uturn.backward.circle", text: "You pay \(money.formatted) now. Finish, and it's refunded in full, automatically, within minutes of settling.")
            }
            if template.graceDays > 0 {
                DealLine(symbol: "bandage", text: "\(template.graceDays) grace day\(template.graceDays > 1 ? "s" : "") included. Life happens.")
            }
            if !isPractice && shields > 0 {
                DealLine(symbol: "shield.lefthalf.filled", text: "\(shields) Shield\(shields == 1 ? "" : "s") equipped: \(shields == 1 ? "one more missed day is" : "two more missed days are") covered. Shields you don't need go back to your locker.")
            }
            DealLine(symbol: "moon.stars", text: "Each day closes at midnight your time. We settle 3 hours later, so late watch syncs still count.")
            if !isPractice {
                DealLine(symbol: "exclamationmark.circle", text: "Miss a day beyond your grace days and the \(money.formatted) is kept. That's what makes it work.")
            }
        }
    }

    private var rangeText: String {
        guard let first = dates.first, let last = dates.last else { return "" }
        let f = Date.FormatStyle().weekday(.abbreviated).day().month(.abbreviated)
        return "\(first.formatted(f)) to \(last.formatted(f))"
    }

    private var whatCounts: some View {
        DisclosureGroup {
            Text("Steps come from Apple Health, so iPhone, Apple Watch, Garmin, Fitbit, Oura, Withings and Samsung all count once they sync to Health. Steps typed in by hand don't count, and hours with impossible step rates are reviewed by a person, never auto-failed.")
                .font(.subheadline)
                .foregroundStyle(Palette.inkSecondary)
                .padding(.top, 8)
                .fixedSize(horizontal: false, vertical: true)
        } label: {
            Text("What counts as a step?").font(.system(.headline, weight: .semibold)).foregroundStyle(Palette.ink)
        }
        .tint(Palette.inkSecondary)
    }

    private var commit: some View {
        VStack(spacing: 12) {
            if case .alreadyRunning = model.canEnter(template) {
                VStack(spacing: 10) {
                    Text("You already have a staked race running. One at a time on the free plan, so you can give it everything.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.inkSecondary)
                        .multilineTextAlignment(.center)
                    Button("Run up to 3 with Steppie Pro") { model.showingPaywall = true }
                        .buttonStyle(.primary)
                }
            } else if working {
                ProgressView().controlSize(.large).frame(height: 60)
            } else {
                HoldToPinButton(title: isPractice ? "Hold to start" : "Hold to pin your bib", pins: $pins, autoplay: autoplay) {
                    Task { await enter() }
                }
                .id(attempt)
            }
            Text(isPractice ? "You can leave a practice lap any time." : "Pinning means you agree to the Race Rules. Payment is handled by Stripe.")
                .font(.caption)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: Actions

    private func rearm() {
        withAnimation(Motion.standard) { pins = 0 }
        attempt += 1
    }

    private func enter() async {
        if case .needsSignIn = model.canEnter(template) { showGate = true; return }
        if case .underage = model.canEnter(template) { showGate = true; return }
        if case .healthMissing = model.canEnter(template) { await model.connectHealth() }
        working = true
        defer { working = false }
        do {
            let ok = try await model.enter(template, stake: isPractice ? nil : stake, startingToday: startToday,
                                           shields: isPractice ? 0 : shields,
                                           comebackOf: template.isComeback ? model.comebackOffer?.id : nil)
            if ok {
                entered = true
            } else {
                rearm()
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct DealLine: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(Palette.cobalt)
                .frame(width: 24)
            Text(text)
                .font(.body)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Confirmation after pinning: the whole cast cheers, then back to the track.
private struct EnteredOverlay: View {
    let bib: Int
    let onDone: () -> Void
    @Environment(AppModel.self) private var model
    @State private var shown = false
    @State private var hop = 0

    var body: some View {
        ZStack {
            Palette.field.ignoresSafeArea()
            RaysBackground(opacity: 0.07)
            ConfettiBurst(count: 110)
            VStack(spacing: 14) {
                Spacer()
                ZStack(alignment: .bottom) {
                    CharacterView(who: .dash, mood: .worried, pose: .idle)
                        .frame(width: 92, height: 106)
                        .offset(x: -118, y: 6)
                        .opacity(shown ? 1 : 0)
                    CharacterView(who: .shelly, mood: .cheer, pose: .cheer, hop: hop)
                        .frame(width: 92, height: 106)
                        .offset(x: 118, y: 6)
                        .opacity(shown ? 1 : 0)
                    SteppieView(mood: .roar, pose: .flex, mane: model.maneLevel, shoes: model.wearing, hop: hop)
                        .frame(height: 220)
                }
                .scaleEffect(shown ? 1 : 0.6, anchor: .bottom)
                Text("You're in.")
                    .font(.system(size: 44, weight: .heavy))
                    .foregroundStyle(.white)
                Text("Bib Nº \(String(bib)) is pinned. Dash is already warming up. Your first lap starts on the track.")
                    .font(.body)
                    .foregroundStyle(Palette.onFieldSecondary)
                    .multilineTextAlignment(.center)
                Spacer()
                Button("Go to today", action: onDone)
                    .buttonStyle(.onField)
                    .shimmer()
            }
            .padding(28)
            .opacity(shown ? 1 : 0)
        }
        .task {
            withAnimation(Motion.snap) { shown = true }
            Haptics.success()
            try? await Task.sleep(for: .milliseconds(250))
            hop += 1
            Haptics.pin()
        }
    }
}

/// A poker chip for one stake amount: edge notches, an inner ring, the amount
/// in bib numerals. Selected chips sit on a little stack and glow volt.
struct StakeChip: View {
    let amount: Int
    var selected = false
    var locked = false
    var ladder = false

    private var tier: StakeTier { StakeTier.tier(units: amount) }

    var body: some View {
        ZStack {
            if selected {
                ForEach(0..<3, id: \.self) { i in
                    chipFace
                        .brightness(-0.18)
                        .offset(y: CGFloat(3 - i) * 4)
                }
                .transition(.scale(scale: 0.5).combined(with: .opacity))
            }
            chipFace
                .overlay {
                    if locked {
                        Circle().fill(.black.opacity(0.45))
                        Image(systemName: "lock.fill").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    }
                }
                .offset(y: selected ? -6 : 0)
                .shadow(color: selected ? Palette.volt.opacity(0.8) : .black.opacity(0.18), radius: selected ? 10 : 4, y: selected ? 0 : 3)
            if ladder {
                Text("LEVEL UP")
                    .font(BrandFont.label(9))
                    .foregroundStyle(Palette.onVolt)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Palette.volt, in: Capsule())
                    .offset(y: -34)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 78)
        .animation(Motion.snap, value: selected)
    }

    private var chipFace: some View {
        ZStack {
            Circle().fill(Color(hex: tier.color))
            Circle().strokeBorder(.white, style: StrokeStyle(lineWidth: 6, dash: [7, 9]))
            Circle().inset(by: 10).fill(Color(hex: tier.color))
            Circle().inset(by: 10).strokeBorder(.white.opacity(0.7), lineWidth: 1.5)
            Text(Money(units: amount).formatted)
                .font(BrandFont.numerals(18, relativeTo: .headline))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 12)
        }
        .frame(width: 66, height: 66)
    }
}

/// The stake table you're sitting at.
struct TierBadge: View {
    let tier: StakeTier

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(Color(hex: tier.color)).frame(width: 9, height: 9)
            Text("\(tier.title.uppercased()) TABLE")
                .font(BrandFont.label(12))
                .kerning(0.6)
        }
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Color(hex: tier.color).opacity(0.14), in: Capsule())
        .contentTransition(.opacity)
        .animation(Motion.standard, value: tier)
    }
}

/// Demo/marketing stage for the signature interaction: the bib and the
/// hold-to-pin button on one screen, no scrolling.
struct PinningStage: View {
    var previewPins = 0
    var autoplay = false
    @State private var pins = 0
    @State private var done = false

    var body: some View {
        VStack(spacing: 28) {
            HStack(alignment: .bottom) {
                Text(done ? "Pinned.\nYou're in." : "Hold to\ncommit")
                    .font(.system(.largeTitle, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.opacity)
                Spacer()
                SteppieView(mood: done ? .roar : (pins > 0 ? .focus : .happy), pose: done ? .flex : .hold, mane: 2, hop: done ? 1 : 0)
                    .frame(width: 118, height: 136)
            }
            BibCard(template: RaceTemplate.board[0], stake: 20, bibNumber: 2_417, pinned: pins)
            Text("Four pins, one for each corner. Let go early and nothing happens.")
                .font(.body)
                .foregroundStyle(Palette.inkSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
            HoldToPinButton(title: "Hold to pin your bib", pins: $pins, autoplay: autoplay) {
                withAnimation(Motion.standard) { done = true }
            }
        }
        .padding(20)
        .padding(.top, 24)
        .background(Palette.ground.ignoresSafeArea())
        .onAppear { pins = previewPins }
    }
}
