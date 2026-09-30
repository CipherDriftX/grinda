import Foundation

// MARK: - Money

struct Money: Codable, Hashable {
    var cents: Int
    var currency: String // ISO 4217, "EUR" or "USD"

    init(cents: Int, currency: String) {
        self.cents = cents
        self.currency = currency
    }

    init(units: Int, currency: String = Money.localCurrency) {
        self.init(cents: units * 100, currency: currency)
    }

    var units: Int { cents / 100 }

    /// "€20" / "$20" (no decimals for whole amounts).
    var formatted: String {
        let whole = cents % 100 == 0
        return (Double(cents) / 100).formatted(
            .currency(code: currency)
                .precision(.fractionLength(whole ? 0 : 2))
        )
    }

    static func + (lhs: Money, rhs: Money) -> Money {
        Money(cents: lhs.cents + rhs.cents, currency: lhs.currency)
    }

    static func zero(_ currency: String = Money.localCurrency) -> Money { Money(cents: 0, currency: currency) }

    /// Launch markets: EUR where the device uses euros, USD everywhere else.
    static var localCurrency: String {
        Locale.current.currency?.identifier == "EUR" ? "EUR" : "USD"
    }
}

// MARK: - Races

enum RaceKind: String, Codable, Hashable {
    case staked
    case practice
}

enum RaceSchedule: String, Codable, Hashable {
    case consecutive // every day from start
    case weekends    // Saturdays and Sundays only
}

/// A race you can enter from the board.
struct RaceTemplate: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let tagline: String
    let dailyGoal: Int
    let days: Int
    let graceDays: Int
    let schedule: RaceSchedule
    let kind: RaceKind
    let isPro: Bool
    let suggestedStakes: [Int] // whole currency units

    /// Stripe card authorisations last 7 days, so races that settle within
    /// ~6 days are a hold that is released on success. Longer races are
    /// charged and refunded automatically.
    var usesHold: Bool { kind == .staked && days <= 5 && schedule == .consecutive }

    var goalLabel: String {
        dailyGoal % 1000 == 0 ? "\(dailyGoal / 1000)K" : String(format: "%.1fK", Double(dailyGoal) / 1000)
    }

    static let board: [RaceTemplate] = [
        RaceTemplate(id: "sprint-5", name: "5-Day Sprint", tagline: "Your money never leaves your account if you finish.",
                     dailyGoal: 8_000, days: 5, graceDays: 0, schedule: .consecutive, kind: .staked, isPro: false,
                     suggestedStakes: [5, 10, 20, 50]),
        RaceTemplate(id: "10k-week", name: "10K Week", tagline: "The classic. Seven days, ten thousand a day.",
                     dailyGoal: 10_000, days: 7, graceDays: 1, schedule: .consecutive, kind: .staked, isPro: false,
                     suggestedStakes: [10, 20, 50, 100]),
        RaceTemplate(id: "weekend", name: "Weekend Warrior", tagline: "Saturdays and Sundays are where weeks are won.",
                     dailyGoal: 12_000, days: 8, graceDays: 1, schedule: .weekends, kind: .staked, isPro: false,
                     suggestedStakes: [10, 20, 50]),
        RaceTemplate(id: "reset-30", name: "30-Day Reset", tagline: "A month of walking changes a body. Two grace days included.",
                     dailyGoal: 8_000, days: 30, graceDays: 2, schedule: .consecutive, kind: .staked, isPro: false,
                     suggestedStakes: [20, 50, 100, 200]),
        RaceTemplate(id: "practice", name: "Practice Lap", tagline: "Three days, no money. See how it feels.",
                     dailyGoal: 7_000, days: 3, graceDays: 0, schedule: .consecutive, kind: .practice, isPro: false,
                     suggestedStakes: []),
    ]
}

// MARK: - Entered races

enum RaceStatus: String, Codable, Hashable {
    case pendingPayment, active, settling, won, lost, underReview, cancelled

    var isLive: Bool { self == .active || self == .settling || self == .pendingPayment }
}

enum StakeState: String, Codable, Hashable {
    case none      // practice
    case held      // card authorised, not charged
    case charged   // paid, refundable on success
    case released  // hold cancelled: money never moved
    case refunded  // charge refunded in full
    case kept      // missed: hold captured or charge kept
}

enum DayState: String, Codable, Hashable {
    case upcoming, today, hit, missed, graced, review
}

struct DayRecord: Identifiable, Codable, Hashable {
    var date: Date // start of day, local
    var steps: Int
    var goal: Int
    var state: DayState

    var id: Date { date }
    var progress: Double { goal > 0 ? min(Double(steps) / Double(goal), 1) : 0 }
}

struct Race: Identifiable, Codable, Hashable {
    var id: UUID
    var templateID: String
    var name: String
    var dailyGoal: Int
    var bibNumber: Int
    var days: [DayRecord]
    var graceAllowed: Int
    var stake: Money?
    var stakeState: StakeState
    var status: RaceStatus
    var usesHold: Bool
    var cardLast4: String?
    var createdAt: Date
    var settledAt: Date?

    var isPractice: Bool { stake == nil }
    var graceUsed: Int { days.filter { $0.state == .graced }.count }
    var hitCount: Int { days.filter { $0.state == .hit || $0.state == .graced }.count }
    var totalSteps: Int { days.reduce(0) { $0 + $1.steps } }
    var endDate: Date { days.last?.date ?? createdAt }

    /// Settlement runs 3 hours after the final day closes, to let late
    /// watch and tracker syncs arrive.
    var settlesAt: Date {
        Calendar.current.date(byAdding: .hour, value: 27, to: endDate) ?? endDate
    }

    var todayIndex: Int? {
        days.firstIndex { Calendar.current.isDateInToday($0.date) }
    }

    var today: DayRecord? { todayIndex.map { days[$0] } }

    /// "Day 3 of 7"
    var dayLabel: String {
        if let i = todayIndex { return "Day \(i + 1) of \(days.count)" }
        if status == .won { return "Finished" }
        if status == .lost { return "Missed" }
        if let first = days.first, first.date > .now { return "Starts \(first.date.formatted(.dateTime.weekday(.wide)))" }
        return "\(days.count) days"
    }
}

// MARK: - Wallet

enum LedgerKind: String, Codable, Hashable {
    case held, charged, released, refunded, kept

    var title: String {
        switch self {
        case .held: "Hold placed"
        case .charged: "Stake paid"
        case .released: "Hold released"
        case .refunded: "Refunded"
        case .kept: "Stake kept"
        }
    }

    var isReturn: Bool { self == .released || self == .refunded }
}

struct LedgerEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var date: Date
    var raceName: String
    var kind: LedgerKind
    var amount: Money
    var reference: String // Stripe PaymentIntent id
}

// MARK: - Person

enum WalkingWhy: String, Codable, CaseIterable, Identifiable {
    case loseWeight, habit, energy, training

    var id: String { rawValue }

    var title: String {
        switch self {
        case .loseWeight: "Lose weight"
        case .habit: "Walk every day, for real this time"
        case .energy: "Feel better, sleep better"
        case .training: "Train for something"
        }
    }

    var symbol: String {
        switch self {
        case .loseWeight: "scalemass"
        case .habit: "calendar"
        case .energy: "sun.max"
        case .training: "flag.checkered"
        }
    }
}

struct Profile: Codable, Hashable {
    var why: WalkingWhy?
    var weightKg: Double?
    var goalWeightKg: Double?
    var dailyGoal: Int = 8_000
    var baseline: Int?
    var usesMetric: Bool = Locale.current.measurementSystem != .us
    var onboarded = false
    var appleUserID: String?
    var displayName: String?
    var birthYear: Int?
    var notificationsEnabled = false

    var isSignedIn: Bool { appleUserID != nil }
    var isAdult: Bool {
        guard let y = birthYear else { return false }
        return Calendar.current.component(.year, from: .now) - y >= 18
    }
}

struct DaySteps: Identifiable, Hashable {
    var date: Date
    var steps: Int
    var id: Date { date }
}

struct WeightSample: Identifiable, Hashable {
    var date: Date
    var kg: Double
    var id: Date { date }
}

/// Aggregate numbers published by the backend's `public_stats` view.
struct PublicStats: Codable, Hashable {
    var walkers: Int
    var stepsWalked: Int64
    var kmWalked: Double
    var racesFinished: Int
    var completionRate: Double
    var returnedCents: Int64
    var keptCents: Int64
    var currency: String
    var isSample: Bool? = nil
}

// MARK: - Estimates

enum Estimate {
    /// Average stride ~0.76 m.
    static func km(steps: Int) -> Double { Double(steps) * 0.000_76 }

    /// kcal ≈ steps × 0.00055 × body kg (≈0.04 kcal/step at 75 kg).
    static func kcal(steps: Int, weightKg: Double?) -> Int {
        Int((Double(steps) * 0.000_55 * (weightKg ?? 75)).rounded())
    }

    /// ~100 steps per minute at an easy walk.
    static func minutes(steps: Int) -> Int { Int((Double(steps) / 100).rounded(.up)) }

    /// 7,700 kcal ≈ 1 kg of body fat.
    static func fatKg(kcal: Int) -> Double { Double(kcal) / 7_700 }

    /// Suggested goal: baseline + 25%, rounded to 500, clamped 5k...12k.
    static func suggestedGoal(baseline: Int?) -> Int {
        guard let b = baseline, b > 0 else { return 8_000 }
        let raw = Double(b) * 1.25
        return min(max(Int((raw / 500).rounded()) * 500, 5_000), 12_000)
    }
}
