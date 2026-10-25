import SwiftUI

/// The purse board: big purses first, live ones you can watch, members'
/// purses, and your own. The purse total is always the biggest number.
struct PursesBoard: View {
    @Environment(AppModel.self) private var model
    @State private var code = ""
    @State private var codeMiss = 0

    private var mine: [Race] { model.liveRaces.filter(\.isPurse) }
    private var featured: [Purse] { Array(model.openPurses.filter { $0.kind == .house }.prefix(5)) }
    private var openRest: [Purse] { model.openPurses.filter { $0.kind == .house && !featured.contains($0) } }
    private var hosted: [Purse] { model.openPurses.filter { $0.kind != .house } }
    private var live: [Purse] { model.runningPurses.filter { p in !mine.contains { $0.purse?.purseID == p.id } } }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            PayoutTicker(events: model.payoutFeed).arrive(0)

            if !mine.isEmpty {
                section("Your purses") {
                    ForEach(mine) { race in
                        if let p = model.purse(race.purse?.purseID ?? "") {
                            NavigationLink(value: p) { YourPurseRow(race: race, purse: p) }
                                .buttonStyle(.pressable)
                        } else {
                            NavigationLink(value: race) { BibCard(race: race, compact: true) }
                                .buttonStyle(.pressable)
                        }
                    }
                }
            }

            if !featured.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Biggest purses").font(.system(.title3, weight: .bold))
                        Spacer()
                        Text("Finishers split 100%").font(.footnote.weight(.semibold)).foregroundStyle(Palette.inkSecondary)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            ForEach(featured) { p in
                                NavigationLink(value: p) { FeaturedPurse(purse: p) }
                                    .buttonStyle(.pressable)
                                    .containerRelativeFrame(.horizontal) { w, _ in w * 0.86 }
                                    .scrollTransition(.interactive, axis: .horizontal) { view, phase in
                                        view
                                            .scaleEffect(phase.isIdentity ? 1 : 0.92)
                                            .rotation3DEffect(.degrees(phase.value * -10), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                                            .opacity(phase.isIdentity ? 1 : 0.75)
                                    }
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .scrollClipDisabled()
                }
                .arrive(1)
            }

            if !live.isEmpty {
                section("Live now", trailing: "Watch the board") {
                    ForEach(live) { p in
                        NavigationLink(value: p) { LivePurseRow(purse: p) }.buttonStyle(.pressable)
                    }
                }
                .arrive(2)
            }

            if !openRest.isEmpty {
                section("Open for entries") {
                    VStack(spacing: 0) {
                        ForEach(Array(openRest.enumerated()), id: \.element.id) { i, p in
                            NavigationLink(value: p) { PurseRow(purse: p) }.buttonStyle(.pressable)
                            if i < openRest.count - 1 { Divider().overlay(Palette.hairline) }
                        }
                    }
                }
                .arrive(3)
            }

            section("Hosted by members", trailing: "Hosts earn 5%") {
                ForEach(hosted) { p in
                    NavigationLink(value: p) { PurseRow(purse: p) }.buttonStyle(.pressable)
                }
                codeField
            }

            StartPurseCard()
        }
    }

    private var codeField: some View {
        HStack(spacing: 10) {
            Image(systemName: "ticket").foregroundStyle(Palette.inkSecondary)
            TextField("Got a purse code?", text: $code)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .onSubmit(findCode)
            if !code.isEmpty {
                Button("Find", action: findCode)
                    .font(.system(.subheadline, weight: .bold))
                    .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
        .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shake(codeMiss)
    }

    private func findCode() {
        let c = code.trimmingCharacters(in: .whitespaces).uppercased()
        if let p = model.purses.first(where: { $0.code?.uppercased() == c }) {
            Haptics.success()
            code = ""
            model.racesPath.append(p)
        } else {
            Haptics.warning()
            withAnimation(.linear(duration: 0.4)) { codeMiss += 1 }
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, trailing: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.system(.title3, weight: .bold))
                Spacer()
                if let trailing {
                    Text(trailing).font(.footnote.weight(.semibold)).foregroundStyle(Palette.inkSecondary)
                }
            }
            content()
        }
    }
}

/// A big purse in the carousel: the note, the entry and when it starts.
private struct FeaturedPurse: View {
    let purse: Purse
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PurseNote(purse: purse)
            HStack(spacing: 10) {
                EntryChip(purse: purse)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(purse.payout(finishRate: 0.85).formatted) each")
                        .font(BrandFont.numerals(20, relativeTo: .headline))
                        .foregroundStyle(Palette.ink)
                    Text("if 85% finish").font(.caption.weight(.semibold)).foregroundStyle(Palette.inkSecondary)
                }
                Spacer()
                Countdown(to: purse.startsAt)
                    .foregroundStyle(Palette.inkSecondary)
            }
            .padding(14)
        }
        .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
    }
}

/// The entry, printed as a chip in the purse's ink.
struct EntryChip: View {
    let purse: Purse
    var size: CGFloat = 46

    var body: some View {
        ZStack {
            Circle().fill(Color(hex: purse.art.color))
            Circle().strokeBorder(.white, style: StrokeStyle(lineWidth: size * 0.08, dash: [size * 0.1, size * 0.13]))
            Circle().inset(by: size * 0.16).fill(Color(hex: purse.art.deep))
            Text(purse.entry.formatted)
                .font(BrandFont.numerals(size * 0.3, relativeTo: .subheadline))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, size * 0.18)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Entry \(purse.entry.formatted)")
    }
}

/// One open purse on the board.
struct PurseRow: View {
    let purse: Purse

    var body: some View {
        HStack(spacing: 14) {
            EntryChip(purse: purse)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(purse.name).font(.system(.headline, weight: .semibold)).foregroundStyle(Palette.ink)
                    if let w = purse.window { WindowBadge(window: w) }
                }
                Text(detail).font(.subheadline).foregroundStyle(Palette.inkSecondary).lineLimit(1)
                Countdown(to: purse.startsAt, font: .caption.weight(.semibold))
                    .foregroundStyle(Palette.inkSecondary)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 0) {
                CountUpMoney(money: purse.pot, font: BrandFont.numerals(24, relativeTo: .title3), color: Palette.ink)
                Text("PURSE").font(BrandFont.label(10)).foregroundStyle(Palette.inkSecondary)
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        let host = purse.hostName.map { " · by \($0)" } ?? ""
        return "\(purse.goalLabel) a day · \(purse.lengthLabel)\(host)"
    }
}

struct WindowBadge: View {
    let window: StepWindow

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "clock.fill")
            Text(window.label)
        }
        .font(BrandFont.label(10))
        .foregroundStyle(Palette.cobalt)
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(Palette.cobalt.opacity(0.1), in: Capsule())
    }
}

/// A running purse you can watch: purse, still in, live split.
private struct LivePurseRow: View {
    let purse: Purse

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: purse.art.symbol).foregroundStyle(Color(hex: purse.art.color))
                Text(purse.name).font(.system(.headline, weight: .bold)).foregroundStyle(Palette.ink)
                Spacer()
                LiveTag().foregroundStyle(Palette.ink)
            }
            HStack(spacing: 0) {
                PurseFact(value: purse.pot.formatted, label: "Purse")
                PurseFact(value: "\(purse.stillIn.formatted())/\(purse.entrants.formatted())", label: "Still in")
                PurseFact(value: purse.livePayout.formatted, label: "Split now", tint: Color(hex: 0x1F7A52))
            }
            StillInBar(entrants: purse.entrants, stillIn: purse.stillIn, onPace: purse.onPace, height: 8)
            if let d = purse.dayNumber {
                Text("Day \(d) of \(purse.days)").font(.caption.weight(.semibold)).foregroundStyle(Palette.inkSecondary)
            }
        }
        .padding(16)
        .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Your entry in a purse: today's progress against the goal and your live split.
private struct YourPurseRow: View {
    let race: Race
    let purse: Purse

    private var today: DayRecord? { race.today }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(purse.name.uppercased()).font(BrandFont.label(13)).kerning(0.8).foregroundStyle(.white.opacity(0.85))
                    Text(race.dayLabel).font(.system(.title3, weight: .heavy)).foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    CountUpMoney(money: purse.livePayout, font: BrandFont.numerals(30, relativeTo: .title2))
                    Text("YOUR SPLIT NOW").font(BrandFont.label(10)).foregroundStyle(.white.opacity(0.75))
                }
            }
            if let today {
                VStack(alignment: .leading, spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.18))
                            Capsule().fill(today.progress >= 1 ? Palette.volt : .white)
                                .frame(width: max(geo.size.width * today.progress, 10))
                        }
                    }
                    .frame(height: 10)
                    Text(today.progress >= 1 ? "Today's done. You're still in." : "\(max(today.goal - today.steps, 0).formatted()) to go today")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(today.progress >= 1 ? Palette.volt : .white.opacity(0.85))
                }
            }
            HStack {
                Text("\(purse.stillIn.formatted()) of \(purse.entrants.formatted()) still in")
                Spacer()
                Text("Purse \(purse.pot.formatted)")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.8))
        }
        .padding(16)
        .background(LinearGradient(colors: [Color(hex: purse.art.color), Color(hex: purse.art.deep)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Start your own purse: a crew purse for friends or a public one you host.
private struct StartPurseCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button { model.showingHostPurse = true } label: {
            HStack(spacing: 14) {
                CharacterView(who: .pip, mood: .happy, pose: .wave)
                    .frame(width: 58, height: 66)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Start a purse").font(.system(.headline, weight: .bold)).foregroundStyle(Palette.ink)
                    Text("Race your friends for a private purse, or host a public one and earn 5% of every entry.")
                        .font(.footnote).foregroundStyle(Palette.inkSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(Palette.cobalt)
            }
            .padding(14)
            .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.pressable)
    }
}
