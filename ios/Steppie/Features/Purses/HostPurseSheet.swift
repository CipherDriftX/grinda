import SwiftUI

/// Start your own purse. Crew: private, code only, up to 12, free. Public:
/// anyone can join, you earn 5% on top of every entry. The note on top
/// redraws as you pick.
struct HostPurseSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var kind: PurseKind = .crew
    @State private var name = ""
    @State private var goal = 10_000
    @State private var days = 7
    @State private var entry = 10
    @State private var startNextMonday = false
    @State private var working = false
    @State private var made: Purse?
    @State private var error: String?
    @State private var showGate = false
    @FocusState private var naming: Bool

    private static let goals = [5_000, 7_500, 10_000, 12_500, 15_000]
    private static let lengths = [1, 3, 5, 7, 14, 21, 30]
    private static let entries = [5, 10, 20, 25, 50, 100]

    private var startsAt: Date {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: .now)) ?? .now
        guard startNextMonday else { return tomorrow }
        return cal.nextDate(after: .now, matching: DateComponents(weekday: 2), matchingPolicy: .nextTime) ?? tomorrow
    }

    private var preview: Purse {
        let host = model.profile.displayName ?? "You"
        return Purse(id: "preview", name: name.isEmpty ? (kind == .crew ? "\(host)'s Crew" : "\(host)'s Purse") : name,
                     tagline: "", kind: kind, art: kind == .crew ? .crew : .megaphone, dailyGoal: goal, days: days,
                     entryUnits: entry, currency: model.currency, startsAt: startsAt,
                     entrants: kind == .crew ? 6 : 40, stillIn: 0, onPace: 0, hostName: host, cap: kind == .crew ? 12 : nil)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let made {
                    MadePurse(purse: made) {
                        dismiss()
                        model.racesMode = .purses
                        model.tab = .races
                        model.racesPath.append(made)
                    }
                    .padding(20)
                } else {
                    form
                }
            }
            .background(Palette.ground)
            .navigationTitle(made == nil ? "Start a purse" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button(made == nil ? "Cancel" : "Done") { dismiss() } }
            }
            .alert("Couldn't start it", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: { Text(error ?? "") }
            .sheet(isPresented: $showGate) { AccountGate() }
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 24) {
            PurseNote(purse: preview, compact: true, showLive: false)
                .animation(Motion.standard, value: preview)
                .accessibilityLabel("Preview of your purse")

            Picker("Type", selection: $kind.animation(Motion.standard)) {
                Text("Crew (private)").tag(PurseKind.crew)
                Text("Public").tag(PurseKind.host)
            }
            .pickerStyle(.segmented)

            Text(kind == .crew
                 ? "Only people with your code can join, up to 12. Friends, family, the office. Free to start."
                 : "Anyone can find it and join. You earn 5% on top of every entry, paid when it settles.")
                .font(.subheadline)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                label("NAME")
                TextField(kind == .crew ? "Sunday Crew" : "Mia's 10K Club", text: $name)
                    .font(.system(.title3, weight: .semibold))
                    .focused($naming)
                    .submitLabel(.done)
                    .padding(14)
                    .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .onChange(of: name) { _, v in if v.count > 28 { name = String(v.prefix(28)) } }
            }

            choice("STEPS A DAY", Self.goals, selected: goal, text: { $0.formatted(.number.notation(.compactName)) }) { goal = $0 }
            choice("DAYS", Self.lengths, selected: days, text: { "\($0)" }) { days = $0 }
            choice("ENTRY", Self.entries, selected: entry, text: { Money(units: $0, currency: model.currency).formatted }) { entry = $0 }

            VStack(alignment: .leading, spacing: 8) {
                label("STARTS")
                Picker("Starts", selection: $startNextMonday) {
                    Text("Tomorrow").tag(false)
                    Text("Next Monday").tag(true)
                }
                .pickerStyle(.segmented)
                Text(startsAt.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.footnote)
                    .foregroundStyle(Palette.inkSecondary)
            }

            VStack(spacing: 10) {
                LeaderLine(label: kind == .crew ? "To start a crew purse" : "To start a public purse",
                           value: kind == .crew ? "Free" : (model.isPro ? "Free with Pro" : Money(cents: PurseFee.hostCreateCents, currency: model.currency).formatted),
                           emphasis: false)
                if kind == .host {
                    LeaderLine(label: "You earn per entry", value: Money(cents: PurseFee.hostCents(entryCents: entry * 100, kind: .host), currency: model.currency).formatted, emphasis: true)
                }
                LeaderLine(label: "You still pay your own entry", value: Money(units: entry, currency: model.currency).formatted, emphasis: false)
            }
            .padding(16)
            .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button {
                Task { await create() }
            } label: {
                if working { ProgressView().tint(.white) } else { Text(kind == .crew ? "Start crew purse" : "Start public purse") }
            }
            .buttonStyle(.primary)
            .disabled(working || name.trimmingCharacters(in: .whitespaces).count < 3)

            Text("Same rules as every purse: finish every day, split the whole purse with the other finishers. 18+ only.")
                .font(.caption)
                .foregroundStyle(Palette.inkSecondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
        .padding(20)
    }

    private func label(_ text: String) -> some View {
        Text(text).font(BrandFont.label(11)).kerning(1).foregroundStyle(Palette.inkSecondary)
    }

    private func choice(_ title: String, _ values: [Int], selected: Int, text: @escaping (Int) -> String, pick: @escaping (Int) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            label(title)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(values, id: \.self) { v in
                        Button {
                            Haptics.tick()
                            withAnimation(Motion.snap) { pick(v) }
                        } label: {
                            Text(text(v))
                                .font(BrandFont.numerals(17, relativeTo: .body))
                                .padding(.horizontal, 16)
                                .frame(minHeight: 44)
                                .background(v == selected ? Palette.cobalt : Palette.tyvek, in: Capsule())
                                .foregroundStyle(v == selected ? .white : Palette.ink)
                        }
                        .buttonStyle(.pressable)
                        .accessibilityAddTraits(v == selected ? .isSelected : [])
                    }
                }
            }
        }
    }

    private func create() async {
        naming = false
        if !model.profile.isSignedIn && !model.isDemo { showGate = true; return }
        working = true
        defer { working = false }
        do {
            if let p = try await model.hostPurse(name: name, kind: kind, dailyGoal: goal, days: days, entryUnits: entry, startsAt: startsAt) {
                withAnimation(Motion.snap) { made = p }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// The purse is made: show the code big, share it, go to it.
private struct MadePurse: View {
    let purse: Purse
    let open: () -> Void
    @Environment(AppModel.self) private var model
    @State private var copied = false

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                ConfettiBurst(count: 70)
                CharacterView(who: purse.kind == .crew ? .dash : .pip, mood: .cheer, pose: .cheer, hop: 1)
                    .frame(width: 130, height: 150)
            }
            Text("\(purse.name) is open")
                .font(.system(size: 28, weight: .heavy))
                .multilineTextAlignment(.center)
            Text("Send the code. Everyone who joins adds \(purse.entry.formatted) to the purse.")
                .font(.body)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
            if let code = purse.code {
                Button {
                    UIPasteboard.general.string = code
                    Haptics.tick()
                    withAnimation(Motion.snap) { copied = true }
                } label: {
                    VStack(spacing: 2) {
                        Text(copied ? "COPIED" : "PURSE CODE · TAP TO COPY")
                            .font(BrandFont.label(11))
                            .foregroundStyle(Palette.inkSecondary)
                        Text(code)
                            .font(BrandFont.numerals(40, relativeTo: .largeTitle))
                            .foregroundStyle(Palette.ink)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Palette.hairline, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    }
                }
                .buttonStyle(.pressable)
                ShareLink(item: "Join my walking purse \(purse.name) on Steppie: \(purse.dailyGoal.formatted()) steps a day for \(purse.days) days, \(purse.entry.formatted) entry, finishers split it all. Code \(code)") {
                    Label("Send the code", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.primary)
            }
            Button("Open the purse and join", action: open)
                .font(.system(.headline, weight: .semibold))
                .frame(minHeight: 44)
        }
    }
}
