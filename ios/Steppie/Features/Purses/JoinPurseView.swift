import SwiftUI

/// Joining a purse: the bib, the money in plain lines, Shields, then
/// hold-to-pin. Nothing is hidden below the button.
struct JoinPurseView: View {
    let purseID: String
    var previewPins = 0
    var showEntered = false

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var pins = 0
    @State private var attempt = 0
    @State private var working = false
    @State private var entered = false
    @State private var error: String?
    @State private var showGate = false
    @State private var shields = 0
    @State private var potBefore = 0

    private var purse: Purse? { model.purse(purseID) }

    var body: some View {
        ScrollView {
            if let p = purse {
                VStack(alignment: .leading, spacing: 26) {
                    bib(p).padding(.top, 8)
                    money(p)
                    shieldPicker
                    VStack(alignment: .leading, spacing: 12) {
                        RuleLine(symbol: "figure.walk", text: p.rule)
                        RuleLine(symbol: "calendar", text: "Starts \(p.startsAt.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))). Settles \(p.settlesAt.formatted(.dateTime.weekday(.wide).hour())), a day after the last day closes.")
                        RuleLine(symbol: "person.3", text: "Finish and you split the whole purse with every other finisher. Miss a day and your entry stays in the purse.")
                    }
                    commit(p)
                }
                .padding(16)
                .padding(.bottom, 24)
            }
        }
        .background(Palette.ground)
        .navigationTitle("Join \(purse?.name ?? "")")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if model.profile.shields > 0 && shields == 0 { shields = min(model.profile.shields, 1) }
            if previewPins > 0 { pins = previewPins }
            potBefore = purse?.potCents ?? 0
            if showEntered { entered = true }
        }
        .alert("Couldn't join", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil; rearm() }
        } message: { Text(error ?? "") }
        .sheet(isPresented: $showGate, onDismiss: rearm) { AccountGate() }
        .fullScreenCover(isPresented: $entered) {
            if let p = purse {
                PurseEnteredOverlay(purse: p, potBefore: potBefore, bib: model.entry(in: p)?.bibNumber ?? 3_318) {
                    entered = false
                    model.racesPath = NavigationPath()
                    model.tab = .today
                }
            }
        }
    }

    private func bib(_ p: Purse) -> some View {
        let dates = (0..<p.days).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: Calendar.current.startOfDay(for: p.startsAt)) }
        return BibCard(name: p.name, bibNumber: 3_318, dailyGoal: p.dailyGoal, dayLabel: p.lengthLabel, stake: p.entry, usesHold: false,
                       days: dates.map { DayRecord(date: $0, steps: 0, goal: p.dailyGoal, state: .upcoming) },
                       settles: p.settlesAt, pinned: pins,
                       purse: PurseTicket(purseID: p.id, entrants: p.entrants + 1, potCents: p.potCents + p.entryUnits * 100, feeCents: 0, window: p.window))
    }

    private func money(_ p: Purse) -> some View {
        let q = model.joinQuote(p)
        let serviceFee = PurseFee.serviceCents(entryCents: q.entry, isPro: model.isPro)
        let hostFee = PurseFee.hostCents(entryCents: q.entry, kind: p.kind)
        return VStack(alignment: .leading, spacing: 12) {
            Text("The money").font(.system(.title3, weight: .bold))
            VStack(spacing: 10) {
                LeaderLine(label: "Entry, into the purse", value: p.entry.formatted, emphasis: false)
                LeaderLine(label: model.isPro ? "Service fee (Pro: none)" : "Service fee", value: Money(cents: serviceFee, currency: p.currency).formatted, emphasis: false)
                if hostFee > 0 {
                    LeaderLine(label: "Host's 5%", value: Money(cents: hostFee, currency: p.currency).formatted, emphasis: false)
                }
                Divider().overlay(Palette.hairline)
                LeaderLine(label: "Total", value: Money(cents: q.entry + q.fee, currency: p.currency).formatted, emphasis: false)
                if q.fromVault > 0 {
                    LeaderLine(label: "From your Vault", value: Money(cents: q.fromVault, currency: p.currency).formatted, emphasis: true)
                    LeaderLine(label: "On your card", value: Money(cents: q.fromCard, currency: p.currency).formatted, emphasis: false)
                }
            }
            .padding(16)
            .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text("Steppie earns from the fee only. The fee is the same whether you finish or not, so we never need you to miss.")
                .font(.footnote)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if !model.isPro {
                Button { model.showingPaywall = true } label: {
                    Label("Pro members pay no fee", systemImage: "sparkles")
                        .font(.system(.subheadline, weight: .semibold))
                }
                .frame(minHeight: 44)
            }
        }
    }

    private var shieldPicker: some View {
        HStack(spacing: 14) {
            CharacterView(who: .shelly, mood: shields > 0 ? .cheer : .happy, hop: shields)
                .frame(width: 58, height: 66)
            VStack(alignment: .leading, spacing: 3) {
                Text(shields == 0 ? "No Shields" : "\(shields) Shield\(shields == 1 ? "" : "s") equipped")
                    .font(.system(.headline, weight: .bold))
                Text(model.profile.shields == 0 ? "A Shield covers one missed day, so a bad day doesn't knock you out." : "Each covers one missed day. Unused ones come back.")
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
                Stepper("Shields", value: $shields, in: 0...min(model.profile.shields, 2))
                    .labelsHidden()
                    .onChange(of: shields) { Haptics.tick() }
            }
        }
        .padding(14)
        .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func commit(_ p: Purse) -> some View {
        VStack(spacing: 12) {
            if case .alreadyRunning = model.canJoin(p) {
                VStack(spacing: 10) {
                    Text("You already have a race running. Free accounts run one at a time.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.inkSecondary)
                        .multilineTextAlignment(.center)
                    Button("Run up to 5 with Steppie Pro") { model.showingPaywall = true }
                        .buttonStyle(.primary)
                }
            } else if working {
                ProgressView().controlSize(.large).frame(height: 60)
            } else {
                HoldToPinButton(title: "Hold to pin your bib", pins: $pins) {
                    Task { await join(p) }
                }
                .id(attempt)
            }
            Text("Pinning means you agree to the Purse Rules. Card payments are handled by Stripe. 18+ only.")
                .font(.caption)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private func rearm() {
        withAnimation(Motion.standard) { pins = 0 }
        attempt += 1
    }

    private func join(_ p: Purse) async {
        switch model.canJoin(p) {
        case .needsSignIn, .underage: showGate = true; return
        case .healthMissing: await model.connectHealth()
        default: break
        }
        working = true
        defer { working = false }
        do {
            potBefore = p.potCents
            if try await model.join(p, shields: shields) {
                entered = true
            } else {
                rearm()
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// After joining: your entry drops into the purse, the total ticks up, the
/// cast cheers.
struct PurseEnteredOverlay: View {
    let purse: Purse
    let potBefore: Int
    let bib: Int
    let onDone: () -> Void
    @Environment(AppModel.self) private var model
    @State private var shown = false
    @State private var pot = 0
    @State private var hop = 0

    private var ink: Color { Color(hex: purse.art.color) }

    var body: some View {
        ZStack {
            LinearGradient(colors: [ink, Color(hex: purse.art.deep)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            RaysBackground(opacity: 0.08)
            ConfettiBurst(count: 90)
            CoinDrop(count: 18)
            VStack(spacing: 14) {
                Spacer()
                Text("THE PURSE")
                    .font(BrandFont.label(13)).kerning(1.4)
                    .foregroundStyle(.white.opacity(0.8))
                CountingMoney(cents: Double(pot), currency: purse.currency, font: BrandFont.numerals(76))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text("+\(purse.entry.formatted) from you")
                    .font(.system(.headline, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.white.opacity(0.18), in: Capsule())
                    .scaleEffect(shown ? 1 : 0.6)
                    .opacity(shown ? 1 : 0)
                ZStack(alignment: .bottom) {
                    CharacterView(who: purse.art.host == .steppie ? .dash : purse.art.host, mood: .cheer, pose: .cheer, hop: hop)
                        .frame(width: 92, height: 106)
                        .offset(x: -118, y: 6)
                    CharacterView(who: .bo, mood: .happy, pose: .wave, hop: hop)
                        .frame(width: 92, height: 106)
                        .offset(x: 118, y: 6)
                    SteppieView(mood: .roar, pose: .flex, mane: model.maneLevel, shoes: model.wearing, hop: hop)
                        .frame(height: 200)
                }
                .scaleEffect(shown ? 1 : 0.6, anchor: .bottom)
                .opacity(shown ? 1 : 0)
                Text("You're in.")
                    .font(.system(size: 44, weight: .heavy))
                    .foregroundStyle(.white)
                Text("Bib Nº \(String(bib)) is pinned for \(purse.name). Walk \(purse.dailyGoal.formatted()) a day and the purse is split with you.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.center)
                Spacer()
                ShareLink(item: "I just joined a \(purse.pot.formatted) walking purse on Steppie. Finish every day, split the purse. Code \(model.inviteCode) gets you $5.") {
                    Label("Bring a friend, both get $5", systemImage: "person.2.fill")
                }
                .buttonStyle(.onField)
                Button("Go to today", action: onDone)
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(minHeight: 44)
            }
            .padding(28)
        }
        .task {
            pot = potBefore
            withAnimation(Motion.snap) { shown = true }
            Haptics.success()
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 1.2)) { pot = potBefore + purse.entryUnits * 100 }
            hop += 1
            Haptics.pin()
        }
    }
}
