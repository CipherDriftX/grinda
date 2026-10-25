import SwiftUI

/// Pushes the join screen for a purse.
struct PurseJoin: Hashable {
    let purseID: String
}

/// One purse: the note, the math, the board. Before the start it sells the
/// purse with true numbers; once it runs it's a live board.
struct PurseDetailView: View {
    let purseID: String
    @Environment(AppModel.self) private var model

    private var purse: Purse? { model.purse(purseID) }

    var body: some View {
        ScrollView {
            if let p = purse {
                VStack(alignment: .leading, spacing: 26) {
                    PurseNote(purse: p).padding(.top, 8).arrive(0)
                    if let mine = model.entry(in: p) {
                        YoureIn(race: mine, purse: p).arrive(1)
                    }
                    if p.hasStarted {
                        LiveSection(purse: p).arrive(1)
                    } else {
                        OpenSection(purse: p).arrive(1)
                    }
                    RulesSection(purse: p).arrive(2)
                }
                .padding(16)
                .padding(.bottom, 24)
            }
        }
        .background(Palette.ground)
        .navigationTitle(purse?.name ?? "Purse")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: PurseJoin.self) { JoinPurseView(purseID: $0.purseID) }
        .safeAreaInset(edge: .bottom) {
            if let p = purse, p.isOpen, model.entry(in: p) == nil { JoinBar(purse: p) }
        }
        .task {
            guard let p = purse else { return }
            await model.loadBoard(for: p)
        }
    }
}

// MARK: - Open purse

private struct OpenSection: View {
    let purse: Purse
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(spacing: 0) {
                PurseFact(value: purse.entry.formatted, label: "Entry")
                PurseFact(value: purse.goalLabel, label: "Steps a day")
                PurseFact(value: purse.lengthLabel, label: "Length")
                PurseFact(value: purse.entrants.formatted(), label: "In so far")
            }
            .padding(16)
            .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            PayoutMath(purse: purse)

            HStack(spacing: 12) {
                CharacterView(who: purse.art.host, mood: .happy, pose: .point)
                    .frame(width: 56, height: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Countdown(to: purse.startsAt, font: .system(.headline, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Text("Entries close when it starts, \(purse.startsAt.formatted(.dateTime.weekday(.wide).hour().minute())). Everyone starts on the same day.")
                        .font(.footnote)
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// What a finisher gets at real finish rates, shown before anyone joins.
struct PayoutMath: View {
    let purse: Purse

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What each finisher gets").font(.system(.title3, weight: .bold))
            VStack(spacing: 0) {
                ForEach(Array(Purse.projectionRates.enumerated()), id: \.offset) { i, rate in
                    let pay = purse.payout(finishRate: rate)
                    let profit = pay.cents - purse.entryUnits * 100
                    HStack {
                        Text("If \(rate.formatted(.percent.precision(.fractionLength(0)))) finish")
                            .font(.body).foregroundStyle(Palette.ink)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(pay.formatted)
                                .font(BrandFont.numerals(22, relativeTo: .body))
                                .foregroundStyle(Palette.ink)
                            Text("\(profit >= 0 ? "+" : "−")\(Money(cents: abs(profit), currency: purse.currency).formatted) on your entry")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(profit > 0 ? Color(hex: 0x1F7A52) : Palette.inkSecondary)
                        }
                    }
                    .padding(.vertical, 12)
                    if i < Purse.projectionRates.count - 1 { Divider().overlay(Palette.hairline) }
                }
            }
            .padding(.horizontal, 16)
            .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text("Real step purses finish between about 75% and 93%. The fewer who finish, the bigger each split. These numbers use today's purse and won't change after you join; only the real result does.")
                .font(.footnote)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The sticky join bar: total to pay and a straight path to the join screen.
private struct JoinBar: View {
    let purse: Purse
    @Environment(AppModel.self) private var model

    var body: some View {
        let q = model.joinQuote(purse)
        VStack(spacing: 6) {
            NavigationLink(value: PurseJoin(purseID: purse.id)) {
                HStack(spacing: 8) {
                    Image(systemName: "ticket.fill")
                    Text("Join for \(Money(cents: q.entry + q.fee, currency: purse.currency).formatted)")
                }
            }
            .buttonStyle(.primary)
            .shimmer()
            Text(q.fee == 0 ? "No fee with Pro" : "\(purse.entry.formatted) entry + \(Money(cents: q.fee, currency: purse.currency).formatted) fee")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.inkSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(.bar)
    }
}

// MARK: - You're in

private struct YoureIn: View {
    let race: Race
    let purse: Purse

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(Color(hex: 0x1F7A52))
                Text(purse.hasStarted ? "You're in. \(race.dayLabel)." : "You're in. See you at the start.")
                    .font(.system(.headline, weight: .bold))
            }
            NavigationLink(value: race) { BibCard(race: race, compact: true) }
                .buttonStyle(.pressable)
        }
    }
}

// MARK: - Live

private struct LiveSection: View {
    let purse: Purse
    @Environment(AppModel.self) private var model

    private var rows: [PurseRunner] { model.purseBoards[purse.id] ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    if let d = purse.dayNumber {
                        Text("Day \(d) of \(purse.days)").font(.system(.title3, weight: .bold))
                    }
                    Spacer()
                    LiveTag().foregroundStyle(Palette.ink)
                }
                HStack(spacing: 0) {
                    PurseFact(value: purse.stillIn.formatted(), label: "Still in")
                    PurseFact(value: purse.onPace.formatted(), label: "On pace", tint: Color(hex: 0x1F7A52))
                    PurseFact(value: (purse.entrants - purse.stillIn).formatted(), label: "Out")
                    PurseFact(value: purse.livePayout.formatted, label: "Split now", tint: Palette.cobalt)
                }
                StillInBar(entrants: purse.entrants, stillIn: purse.stillIn, onPace: purse.onPace)
                HStack(spacing: 14) {
                    legend(Palette.volt, "On pace")
                    legend(Color(hex: 0xFFB020), "Behind")
                    legend(Palette.hairline, "Out")
                }
                if purse.lateSyncsBack > 0 {
                    Label("\(purse.lateSyncsBack) people moved back in when late watch syncs landed. Nobody is out until a day after the day closes.", systemImage: "arrow.triangle.2.circlepath")
                        .font(.footnote)
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if purse.benched > 0 {
                    Label("\(purse.benched) removed for fake steps. Their entries stay in the purse.", systemImage: "hand.raised.fill")
                        .font(.footnote)
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            LiveBoard(rows: rows, goal: purse.dailyGoal)
        }
        .task(id: purse.id) { await tick() }
    }

    private func legend(_ c: Color, _ s: String) -> some View {
        HStack(spacing: 5) {
            Capsule().fill(c).frame(width: 14, height: 6)
            Text(s).font(.caption.weight(.semibold)).foregroundStyle(Palette.inkSecondary)
        }
    }

    /// Keeps the board moving: real boards poll, demo boards walk a little.
    private func tick() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(model.isDemo ? 2.2 : 30))
            if Task.isCancelled { return }
            if model.isDemo {
                var r = model.purseBoards[purse.id] ?? []
                guard !r.isEmpty else { continue }
                let i = Int.random(in: 0..<r.count)
                if r[i].state != .out && !r[i].isMe {
                    r[i].steps += Int.random(in: 60...420)
                    if r[i].steps >= purse.dailyGoal { r[i].state = .finished }
                }
                r.sort { ($0.state == .out ? -1 : $0.steps) > ($1.state == .out ? -1 : $1.steps) }
                for k in r.indices { r[k].rank = k + 1 }
                withAnimation(Motion.standard) { model.purseBoards[purse.id] = r }
            } else {
                await model.loadBoard(for: purse)
            }
        }
    }
}

/// The live board: rank, name, steps today, and where they stand.
struct LiveBoard: View {
    let rows: [PurseRunner]
    let goal: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today's board").font(.system(.title3, weight: .bold))
            if rows.isEmpty {
                Text("The board fills in as steps sync.")
                    .font(.subheadline).foregroundStyle(Palette.inkSecondary)
            } else {
                if let me = rows.first(where: \.isMe) {
                    RunnerRow(row: me, goal: goal).padding(.horizontal, 12)
                        .background(Palette.cobalt.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                VStack(spacing: 0) {
                    ForEach(rows.prefix(25)) { r in
                        RunnerRow(row: r, goal: goal)
                            .padding(.horizontal, 12)
                            .background(r.isMe ? Palette.cobalt.opacity(0.06) : .clear)
                    }
                }
                .background(Palette.tyvek, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .animation(Motion.standard, value: rows)
            }
        }
    }
}

private struct RunnerRow: View {
    let row: PurseRunner
    let goal: Int

    var body: some View {
        HStack(spacing: 12) {
            Text("\(row.rank)")
                .font(BrandFont.numerals(18, relativeTo: .body))
                .foregroundStyle(row.rank <= 3 ? Palette.ink : Palette.inkSecondary)
                .frame(width: 34, alignment: .leading)
                .contentTransition(.numericText(value: Double(row.rank)))
            Text(String(row.name.prefix(1)))
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(row.isMe ? Palette.cobalt : Color(hex: 0x6B7385), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(row.isMe ? "\(row.name) (you)" : row.name)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(row.state == .out ? Palette.inkSecondary : Palette.ink)
                    .strikethrough(row.state == .out)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.hairline.opacity(0.6))
                        Capsule().fill(color).frame(width: geo.size.width * min(Double(row.steps) / Double(max(goal, 1)), 1))
                    }
                }
                .frame(height: 5)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(row.state == .out ? "–" : row.steps.formatted())
                    .font(BrandFont.numerals(16, relativeTo: .subheadline))
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText(value: Double(row.steps)))
                Text(label)
                    .font(BrandFont.label(10))
                    .foregroundStyle(row.state == .finished ? Palette.onVolt : Palette.inkSecondary)
                    .padding(.horizontal, row.state == .finished ? 5 : 0)
                    .background(row.state == .finished ? Palette.volt : .clear, in: Capsule())
            }
            .frame(width: 76, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rank \(row.rank), \(row.name), \(row.steps) steps, \(label.lowercased())")
    }

    private var color: Color {
        switch row.state {
        case .finished, .onPace: Palette.volt
        case .behind: Color(hex: 0xFFB020)
        case .out: Palette.hairline
        }
    }

    private var label: String {
        switch row.state {
        case .finished: "DONE"
        case .onPace: "ON PACE"
        case .behind: "BEHIND"
        case .out: "OUT"
        }
    }
}

// MARK: - Rules

private struct RulesSection: View {
    let purse: Purse

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("The rules").font(.system(.title3, weight: .bold))
            RuleLine(symbol: "figure.walk", text: purse.rule)
            if let w = purse.window {
                RuleLine(symbol: "clock", text: "Only steps between \(w.label) your time count. Steps outside the window still count for your streak.")
            }
            RuleLine(symbol: "person.3", text: "Every finisher gets an equal split of the whole purse. Steppie takes no cut of it. Leftover cents go to the finisher with the most steps.")
            RuleLine(symbol: "moon.stars", text: "Each day closes at midnight your time. Nobody is marked out until 24 hours later, so late watch syncs always count.")
            RuleLine(symbol: "shield.lefthalf.filled", text: "Shields from Shelly cover a missed day. Equip up to two when you join; unused ones come back.")
            RuleLine(symbol: "photo.on.rectangle", text: "Steps didn't count? Send a Health screenshot from the day. A person checks it before the purse settles.")
            RuleLine(symbol: "hand.raised", text: "Steps typed into Health by hand don't count. Accounts with fake steps are removed, and their entry stays in the purse.")
            if purse.kind == .host, let host = purse.hostName {
                RuleLine(symbol: "megaphone", text: "Hosted by \(host). Hosts earn 5% on top of each entry, never from the purse.")
            }
        }
    }
}

struct RuleLine: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(Palette.cobalt)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
