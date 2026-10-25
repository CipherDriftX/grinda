import Foundation

/// Synthetic data for demo mode (`-demo YES`), used for App Store screenshots
/// and previews. None of it is presented as real user outcomes.
enum DemoSeed {
    static var profile: Profile {
        var p = Profile()
        p.why = .loseWeight
        p.weightKg = 83.3
        p.goalWeightKg = 78
        p.dailyGoal = 10_000
        p.baseline = 6_240
        p.onboarded = true
        p.appleUserID = "demo"
        p.displayName = "Sam"
        p.birthYear = 1990
        p.notificationsEnabled = true
        p.invitesEnabled = true
        p.shields = 2
        p.shoes = ["classic", "chalk", "sunrise", "mint", "volt"]
        p.wearing = "classic"
        p.unopenedBoxes = 1
        p.league = .gold
        p.vaultCents = 4_386
        p.creditCents = 500
        p.inviteCode = "SAM-4821"
        p.invitesPaid = 3
        return p
    }

    private static func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: .now))!
    }

    static func races() -> [Race] {
        let cur = Money.localCurrency
        // Live: 10K Week, day 4 of 7, three days banked.
        let live = Race(
            id: UUID(uuidString: "6B0D5E1A-2F2B-4C57-9E43-1B3C3F0A7D11")!, templateID: "10k-week", name: "10K Week",
            dailyGoal: 10_000, bibNumber: 2_417,
            days: (0..<7).map { i in
                let o = i - 3
                let steps = [11_204, 10_380, 12_947, 6_480, 0, 0, 0][i]
                let state: DayState = o < 0 ? .hit : (o == 0 ? .today : .upcoming)
                return DayRecord(date: day(o), steps: steps, goal: 10_000, state: state)
            },
            graceAllowed: 1, stake: Money(units: 20, currency: cur), stakeState: .charged, status: .active,
            usesHold: false, cardLast4: "4242", createdAt: day(-3), settledAt: nil, shieldsEquipped: 1
        )
        let sprint = Race(
            id: UUID(), templateID: "sprint-5", name: "5-Day Sprint", dailyGoal: 8_000, bibNumber: 1_188,
            days: (0..<5).map { DayRecord(date: day(-12 + $0), steps: 8_600 + $0 * 410, goal: 8_000, state: .hit) },
            graceAllowed: 0, stake: Money(units: 10, currency: cur), stakeState: .released, status: .won,
            usesHold: true, cardLast4: "4242", createdAt: day(-12), settledAt: day(-6)
        )
        let weekend = Race(
            id: UUID(), templateID: "weekend", name: "Weekend Warrior", dailyGoal: 12_000, bibNumber: 3_902,
            days: (0..<4).map { i in
                DayRecord(date: day(-26 + i * 3), steps: i == 2 ? 9_870 : 12_900, goal: 12_000, state: i == 2 ? .missed : .hit)
            },
            graceAllowed: 0, stake: Money(units: 10, currency: cur), stakeState: .kept, status: .lost,
            usesHold: false, cardLast4: "4242", createdAt: day(-27), settledAt: day(-16)
        )
        let practice = Race(
            id: UUID(), templateID: "practice", name: "Practice Lap", dailyGoal: 7_000, bibNumber: 7_000,
            days: (0..<3).map { DayRecord(date: day(-31 + $0), steps: 7_450 + $0 * 300, goal: 7_000, state: .hit) },
            graceAllowed: 0, stake: nil, stakeState: .none, status: .won,
            usesHold: false, cardLast4: nil, createdAt: day(-31), settledAt: day(-28)
        )
        // Live purse: Lion's Share, day 4 of 7, the purse race on Today.
        let lions = livePurseRace()
        // A purse finished last week: One and Done, split with 571 finishers.
        let oneDay = Race(
            id: UUID(uuidString: "7C1D5E1A-2F2B-4C57-9E43-1B3C3F0A7D33")!, templateID: "purse:one-and-done-41", name: "One and Done",
            dailyGoal: 20_000, bibNumber: 5_031,
            days: [DayRecord(date: day(-9), steps: 21_480, goal: 20_000, state: .hit)],
            graceAllowed: 0, stake: Money(units: 10, currency: cur), stakeState: .charged, status: .won,
            usesHold: false, cardLast4: "4242", createdAt: day(-11), settledAt: day(-8),
            purse: PurseTicket(purseID: "one-and-done-41", entrants: 640, potCents: 640_000, feeCents: 90, window: nil, finishers: 571, payoutCents: 1_120)
        )
        return [lions, live, oneDay, sprint, weekend, practice]
    }

    static let lionsShareLiveID = "lions-share-43"

    static func livePurseRace() -> Race {
        let cur = Money.localCurrency
        return Race(
            id: UUID(uuidString: "8D2E5E1A-2F2B-4C57-9E43-1B3C3F0A7D44")!, templateID: "purse:\(lionsShareLiveID)", name: "Lion's Share",
            dailyGoal: 10_000, bibNumber: 3_318,
            days: (0..<7).map { i in
                let o = i - 3
                let steps = [12_040, 10_215, 11_388, 6_480, 0, 0, 0][i]
                let state: DayState = o < 0 ? .hit : (o == 0 ? .today : .upcoming)
                return DayRecord(date: day(o), steps: steps, goal: 10_000, state: state)
            },
            graceAllowed: 0, stake: Money(units: 20, currency: cur), stakeState: .charged, status: .active,
            usesHold: false, cardLast4: "4242", createdAt: day(-4), settledAt: nil, shieldsEquipped: 1,
            purse: PurseTicket(purseID: lionsShareLiveID, entrants: 1_912, potCents: 1_912 * 2_000, feeCents: 130, window: nil)
        )
    }

    // MARK: Purses (sample numbers, demo mode only)

    static func purses() -> [Purse] {
        let cur = Money.localCurrency
        let now = Date.now
        func spec(_ id: String) -> PurseCatalog.Spec { PurseCatalog.specs.first { $0.id == id }! }
        var out: [Purse] = []
        // Open for entries, starting soon.
        let open: [(String, Int)] = [
            ("lions-share", 1_284), ("dawn-patrol", 846), ("one-and-done", 2_210), ("fresh-paws", 1_530),
            ("night-shift", 412), ("the-gauntlet", 377), ("golden-mane", 214), ("walktober-finale", 958), ("winter-mane", 603),
        ]
        for (id, n) in open { out.append(PurseCatalog.purse(spec(id), currency: cur, now: now, entrants: n)) }
        // Running now.
        var lions = PurseCatalog.purse(spec("lions-share"), currency: cur, now: now, entrants: 1_912, stillIn: 1_604, onPace: 1_180, startOffset: -3)
        lions = Purse(id: lionsShareLiveID, name: lions.name, tagline: lions.tagline, kind: .house, art: lions.art, dailyGoal: lions.dailyGoal,
                      days: lions.days, window: nil, entryUnits: lions.entryUnits, currency: cur, startsAt: lions.startsAt,
                      entrants: 1_912, stillIn: 1_604, onPace: 1_180, benched: 9, lateSyncsBack: 14)
        out.append(lions)
        var dawn = PurseCatalog.purse(spec("dawn-patrol"), currency: cur, now: now, entrants: 733, stillIn: 655, onPace: 655, startOffset: -2)
        dawn = Purse(id: "dawn-patrol-43", name: dawn.name, tagline: dawn.tagline, kind: .house, art: dawn.art, dailyGoal: dawn.dailyGoal,
                     days: dawn.days, window: dawn.window, entryUnits: dawn.entryUnits, currency: cur, startsAt: dawn.startsAt,
                     entrants: 733, stillIn: 655, onPace: 655, benched: 3)
        out.append(dawn)
        // Hosted by members.
        let start2 = Calendar.current.date(byAdding: .day, value: 2, to: Calendar.current.startOfDay(for: now))!
        out.append(Purse(id: "host-mia-10k", name: "Mia's 10K Club", tagline: "Walk with my followers for a week. I'll be on the board too.",
                         kind: .host, art: .megaphone, dailyGoal: 10_000, days: 7, entryUnits: 15, currency: cur, startsAt: start2,
                         entrants: 486, stillIn: 486, onPace: 486, hostName: "Mia Walks", code: "MIAWALKS"))
        out.append(Purse(id: "host-desk-escape", name: "Desk Escape", tagline: "For people who sit all day. Lunch walks count.",
                         kind: .host, art: .megaphone, dailyGoal: 8_000, days: 5, entryUnits: 10, currency: cur, startsAt: start2,
                         entrants: 129, stillIn: 129, onPace: 129, hostName: "Coach Ren", code: "DESKESCAPE"))
        // A crew purse with friends.
        let start1 = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now))!
        out.append(Purse(id: "crew-sunday", name: "Sunday Crew", tagline: "Loser picks the brunch spot. Winners split the purse.",
                         kind: .crew, art: .crew, dailyGoal: 9_000, days: 7, entryUnits: 25, currency: cur, startsAt: start1,
                         entrants: 6, stillIn: 6, onPace: 6, code: "SUNDAY-77", cap: 12))
        return out
    }

    private static let runnerNames = [
        "Lena K.", "Marco", "Aisha B.", "Jonas", "Priya", "Tom W.", "Sofia", "Ben", "Mia R.", "Kenji", "Clara", "Omar",
        "Elif", "Noah P.", "Hannah", "Diego", "Ines", "Yusuf", "Freya", "Luca", "Amara", "Theo", "Zoe M.", "Ravi",
    ]

    /// A sample live board around the walker's own steps, so the two always agree.
    static func board(for p: Purse, me: String, mine: Race?, todaySteps: Int) -> [PurseRunner] {
        guard p.hasStarted else { return [] }
        let goal = p.dailyGoal
        var rng = SeededRNG(seed: p.id.unicodeScalars.reduce(7) { $0 &* 31 &+ UInt64($1.value) })
        var rows: [PurseRunner] = runnerNames.enumerated().map { i, name in
            let f = Double(rng.next() % 1_000) / 1_000
            let steps = Int(Double(goal) * (0.25 + f * 1.25))
            let state: PurseRunner.State = i % 11 == 10 ? .out : (steps >= goal ? .finished : (f > 0.38 ? .onPace : .behind))
            return PurseRunner(rank: 0, name: name, steps: state == .out ? 0 : steps, state: state)
        }
        if let mine {
            let steps = mine.today?.steps ?? todaySteps
            rows.append(PurseRunner(rank: 0, name: me, steps: steps, state: steps >= goal ? .finished : .onPace, isMe: true))
        }
        rows.sort { ($0.state == .out ? -1 : $0.steps) > ($1.state == .out ? -1 : $1.steps) }
        return rows.enumerated().map { i, r in var r = r; r.rank = i + 1; return r }
    }

    static func payoutFeed() -> [PayoutEvent] {
        let cur = Money.localCurrency
        let rows: [(String, String, Int, Int, Int)] = [
            ("Jess T.", "One and Done", 1_120, 120, 4), ("Daniel", "Fresh Paws", 562, 62, 9), ("Aisha B.", "Lion's Share", 2_394, 394, 15),
            ("Kenji", "Dawn Patrol", 1_208, 208, 22), ("Ravi", "The Gauntlet", 7_310, 2_310, 31), ("Freya", "One and Done", 1_120, 120, 38),
            ("Marco", "Night Shift", 1_164, 164, 47), ("Ines", "Lion's Share", 2_394, 394, 55), ("Theo", "Fresh Paws", 562, 62, 63),
            ("Clara", "Walktober Finale", 2_871, 371, 71),
        ]
        return rows.map { PayoutEvent(name: $0.0, purseName: $0.1, amount: Money(cents: $0.2, currency: cur),
                                      profit: Money(cents: $0.3, currency: cur), at: Date.now.addingTimeInterval(-Double($0.4) * 60)) }
    }

    static let benchTotal = 131

    static func ledger(races: [Race]) -> [LedgerEntry] {
        let cur = Money.localCurrency
        func entry(_ offset: Int, _ hour: Int, _ name: String, _ kind: LedgerKind, _ units: Int, _ ref: String) -> LedgerEntry {
            let date = Calendar.current.date(byAdding: .hour, value: hour, to: day(offset))!
            return LedgerEntry(id: UUID(), date: date, raceName: name, kind: kind, amount: Money(units: units, currency: cur), reference: ref)
        }
        return [
            entry(-4, 9, "Lion's Share", .entry, 20, "pe_3QmL2a3318"),
            LedgerEntry(id: UUID(), date: Calendar.current.date(byAdding: .hour, value: 4, to: day(-8))!, raceName: "One and Done",
                        kind: .winnings, amount: Money(cents: 1_120, currency: cur), reference: "split_one-and-done-41"),
            entry(-9, 12, "Invite: Jonas", .referral, 5, "inv_SAM-4821_J"),
            entry(-11, 18, "One and Done", .entry, 10, "pe_3QkA9b5031"),
            entry(-3, 8, "10K Week", .charged, 20, "pi_3QkT8e2417"),
            entry(-6, 3, "5-Day Sprint", .released, 10, "pi_3QhA1c1188"),
            entry(-12, 7, "5-Day Sprint", .held, 10, "pi_3QhA1c1188"),
            entry(-16, 3, "Weekend Warrior", .kept, 10, "pi_3QdR7w3902"),
            entry(-27, 19, "Weekend Warrior", .charged, 10, "pi_3QdR7w3902"),
        ]
    }

    /// A missed race from yesterday, for the Comeback screens.
    static func missedYesterday() -> Race {
        let cur = Money.localCurrency
        return Race(
            id: UUID(uuidString: "0C0B5E1A-2F2B-4C57-9E43-1B3C3F0A7D22")!, templateID: "10k-week", name: "10K Week",
            dailyGoal: 10_000, bibNumber: 4_120,
            days: (0..<7).map { i in
                let steps = [10_420, 11_030, 6_210, 10_880, 7_940, 10_210, 10_650][i]
                return DayRecord(date: day(-8 + i), steps: steps, goal: 10_000, state: steps >= 10_000 ? .hit : .missed)
            },
            graceAllowed: 1, stake: Money(units: 20, currency: cur), stakeState: .kept, status: .lost,
            usesHold: false, cardLast4: "4242", createdAt: day(-8), settledAt: Calendar.current.date(byAdding: .hour, value: -20, to: .now)
        )
    }

    /// Sample league table for demo mode only; the real app reads league_board().
    static func league(me: String, grit: Int) -> [APIClient.BoardRow] {
        let names = ["Lena", "Marco", "Aisha", "Jonas", "Priya", "Tom", "Sofia", "Ben", "Mia", "Kenji", "Clara", "Omar", "Elif", "Noah", "Hannah"]
        // Scaled around the demo walker's own Grit so the table always agrees with the header.
        let base = Double(max(grit, 500))
        let factors = [1.34, 1.23, 1.19, 1.06, 1.02, 0.98, 0.9, 0.82, 0.77, 0.69, 0.64, 0.53, 0.42, 0.33, 0.22]
        var rows = zip(names, factors).map { (name: $0, grit: Int(base * $1), me: false) }
        rows.append((name: me, grit: grit, me: true))
        rows.sort { $0.grit > $1.grit }
        return rows.enumerated().map { APIClient.BoardRow(rank: $0 + 1, name: $1.name, grit: $1.grit, isMe: $1.me) }
    }

    /// Clearly flagged as sample data; the real app reads the backend's public_stats view.
    static let stats = PublicStats(
        walkers: 12_408, stepsWalked: 1_486_220_000, kmWalked: 1_129_527, racesFinished: 8_410,
        completionRate: 0.74, returnedCents: 7_130_400, keptCents: 2_408_000,
        currency: Money.localCurrency, isSample: true
    )
}

/// Deterministic numbers for demo boards (same screenshot every run).
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E37_79B9_7F4A_7C15 | 1 }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
