import SwiftUI

/// The whole deal on one screen, in plain words, ending in hold-to-pin.
struct ContractView: View {
    let template: RaceTemplate
    var initialStake: Int? = nil
    var previewPins: Int = 0
    var autoplay = false

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var stake: Int = 0
    @State private var startToday = true
    @State private var pins = 0
    @State private var attempt = 0
    @State private var working = false
    @State private var entered = false
    @State private var error: String?
    @State private var showGate = false

    private var isPractice: Bool { template.kind == .practice }
    private var money: Money { Money(units: stake) }
    private var dates: [Date] { AppModel.schedule(for: template, startingToday: startToday) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                BibCard(template: template, stake: isPractice ? nil : stake, bibNumber: 2_417, pinned: pins, startingToday: startToday)
                    .padding(.top, 8)

                if !isPractice { stakePicker }
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
            if stake == 0 { stake = initialStake ?? template.suggestedStakes.dropFirst().first ?? template.suggestedStakes.first ?? 0 }
            if previewPins > 0 { pins = previewPins }
        }
        .alert("Couldn't start the race", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil; rearm() }
        } message: { Text(error ?? "") }
        .sheet(isPresented: $showGate, onDismiss: rearm) { AccountGate() }
        .overlay { if entered { EnteredOverlay(bib: 2_417) { dismiss(); model.tab = .today } } }
    }

    // MARK: Sections

    private var stakePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your stake").font(.system(.title3, weight: .bold))
            HStack(spacing: 10) {
                ForEach(template.suggestedStakes, id: \.self) { amount in
                    Button {
                        stake = amount
                        Haptics.tick()
                    } label: {
                        Text(Money(units: amount).formatted)
                            .font(BrandFont.numerals(26, relativeTo: .title2))
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .foregroundStyle(stake == amount ? .white : Palette.ink)
                            .background(stake == amount ? Palette.cobalt : Palette.tyvek,
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityAddTraits(stake == amount ? .isSelected : [])
                }
            }
            .animation(Motion.standard, value: stake)
            Text("Pick an amount you'd hate to lose but won't miss. First race? Start small.")
                .font(.footnote)
                .foregroundStyle(Palette.inkSecondary)
        }
    }

    private var startPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Starts").font(.system(.title3, weight: .bold))
            Picker("Starts", selection: $startToday) {
                Text("Today").tag(true)
                Text("Tomorrow").tag(false)
            }
            .pickerStyle(.segmented)
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
            if working {
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
            let ok = try await model.enter(template, stake: isPractice ? nil : stake, startingToday: startToday)
            if ok {
                withAnimation(Motion.standard) { entered = true }
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

/// Confirmation after pinning: short, then back to the track.
private struct EnteredOverlay: View {
    let bib: Int
    let onDone: () -> Void
    @State private var shown = false

    var body: some View {
        ZStack {
            Palette.field.ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Palette.volt)
                    .symbolEffect(.bounce, value: shown)
                Text("You're in.")
                    .font(.system(.largeTitle, weight: .bold))
                    .foregroundStyle(.white)
                Text("Bib Nº \(String(bib)) is pinned. Your first lap starts on the track.")
                    .font(.body)
                    .foregroundStyle(Palette.onFieldSecondary)
                    .multilineTextAlignment(.center)
                Button("Go to today", action: onDone)
                    .buttonStyle(.onField)
                    .padding(.top, 12)
            }
            .padding(32)
            .scaleEffect(shown ? 1 : 0.94)
            .opacity(shown ? 1 : 0)
        }
        .onAppear {
            withAnimation(Motion.standard) { shown = true }
        }
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
            Text(done ? "Pinned. You're in." : "Hold to commit")
                .font(.system(.largeTitle, weight: .bold))
                .foregroundStyle(Palette.ink)
                .contentTransition(.opacity)
                .frame(maxWidth: .infinity, alignment: .leading)
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
