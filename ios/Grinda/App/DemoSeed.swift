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
            usesHold: false, cardLast4: "4242", createdAt: day(-3), settledAt: nil
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
        return [live, sprint, weekend, practice]
    }

    static func ledger(races: [Race]) -> [LedgerEntry] {
        let cur = Money.localCurrency
        func entry(_ offset: Int, _ hour: Int, _ name: String, _ kind: LedgerKind, _ units: Int, _ ref: String) -> LedgerEntry {
            let date = Calendar.current.date(byAdding: .hour, value: hour, to: day(offset))!
            return LedgerEntry(id: UUID(), date: date, raceName: name, kind: kind, amount: Money(units: units, currency: cur), reference: ref)
        }
        return [
            entry(-3, 8, "10K Week", .charged, 20, "pi_3QkT8e2417"),
            entry(-6, 3, "5-Day Sprint", .released, 10, "pi_3QhA1c1188"),
            entry(-12, 7, "5-Day Sprint", .held, 10, "pi_3QhA1c1188"),
            entry(-16, 3, "Weekend Warrior", .kept, 10, "pi_3QdR7w3902"),
            entry(-27, 19, "Weekend Warrior", .charged, 10, "pi_3QdR7w3902"),
        ]
    }

    /// Clearly flagged as sample data; the real app reads the backend's public_stats view.
    static let stats = PublicStats(
        walkers: 12_408, stepsWalked: 1_486_220_000, kmWalked: 1_129_527, racesFinished: 8_410,
        completionRate: 0.74, returnedCents: 7_130_400, keptCents: 2_408_000,
        currency: Money.localCurrency, isSample: true
    )
}
