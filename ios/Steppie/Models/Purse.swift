import Foundation

// MARK: - Purse races
//
// Everyone in a purse pays the same entry and walks the same goal. Finish every
// day and you split the whole purse with the other finishers. Steppie's money
// comes from the fee on top of the entry, never from the purse, so the purse is
// 100% walkers' money. Whether money comes back depends only on steps.

enum PurseKind: String, Codable, Hashable {
    /// Run by Steppie.
    case house
    /// Run by a member, public, with a code. The host earns 5% on top of each entry.
    case host
    /// Private: friends with the invite code only.
    case crew
}

/// Look of a purse card: accent colour, symbol and who from the cast hosts it.
enum PurseArt: String, Codable, Hashable, CaseIterable {
    case lion, sunrise, moon, bolt, flame, crown, paw, snow, leaf, megaphone, crew

    var color: UInt32 {
        switch self {
        case .lion: 0xFFB020
        case .sunrise: 0xFF7A3D
        case .moon: 0x5B47D6
        case .bolt: 0x1F4FD8
        case .flame: 0xE8484A
        case .crown: 0xC9971C
        case .paw: 0x22B37A
        case .snow: 0x3AA8E0
        case .leaf: 0xF0781E
        case .megaphone: 0xD9418C
        case .crew: 0x0F9E9A
        }
    }

    /// A darker shade for gradients and text on light paper.
    var deep: UInt32 {
        switch self {
        case .lion: 0xB86E00
        case .sunrise: 0xC2461B
        case .moon: 0x2E2180
        case .bolt: 0x10307F
        case .flame: 0x9E1F25
        case .crown: 0x7A5A08
        case .paw: 0x0E6B4B
        case .snow: 0x14608C
        case .leaf: 0xA2440A
        case .megaphone: 0x8A1D55
        case .crew: 0x075E5C
        }
    }

    var symbol: String {
        switch self {
        case .lion: "crown.fill"
        case .sunrise: "sunrise.fill"
        case .moon: "moon.stars.fill"
        case .bolt: "bolt.fill"
        case .flame: "flame.fill"
        case .crown: "crown.fill"
        case .paw: "pawprint.fill"
        case .snow: "snowflake"
        case .leaf: "leaf.fill"
        case .megaphone: "megaphone.fill"
        case .crew: "person.3.fill"
        }
    }

    var host: CastMember {
        switch self {
        case .lion, .crown, .flame: .steppie
        case .sunrise, .megaphone: .pip
        case .moon: .bo
        case .bolt: .dash
        case .paw, .snow, .leaf, .crew: .shelly
        }
    }
}

struct Purse: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var tagline: String
    var kind: PurseKind
    var art: PurseArt
    var dailyGoal: Int
    var days: Int
    var window: StepWindow? = nil
    var entryUnits: Int
    var currency: String
    var startsAt: Date
    /// People in the purse.
    var entrants: Int
    /// Still in (no uncovered missed day). Equals `entrants` before the start.
    var stillIn: Int
    /// Of those still in, how many are at or ahead of pace today.
    var onPace: Int
    /// Added by a sponsor on top of the entries.
    var sponsorCents = 0
    var hostName: String? = nil
    var code: String? = nil
    var cap: Int? = nil
    var proOnly = false
    /// People removed from this purse for fake steps (no names, ever).
    var benched = 0
    /// People moved back in after a late sync landed.
    var lateSyncsBack = 0

    // MARK: Derived

    var entry: Money { Money(units: entryUnits, currency: currency) }
    var potCents: Int { entrants * entryUnits * 100 + sponsorCents }
    var pot: Money { Money(cents: potCents, currency: currency) }

    var endsAt: Date {
        Calendar.current.date(byAdding: .day, value: days, to: startsAt) ?? startsAt
    }

    /// Settles a day after the last day closes, so late syncs always land.
    var settlesAt: Date {
        Calendar.current.date(byAdding: .hour, value: 24, to: endsAt) ?? endsAt
    }

    var hasStarted: Bool { startsAt <= .now }
    var isOpen: Bool { !hasStarted && (cap.map { entrants < $0 } ?? true) }
    var isOver: Bool { endsAt <= .now }

    /// Day of the purse today (1-based), if it's running.
    var dayNumber: Int? {
        guard hasStarted, !isOver else { return nil }
        let d = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: startsAt), to: Calendar.current.startOfDay(for: .now)).day ?? 0
        return min(d + 1, days)
    }

    var goalLabel: String {
        dailyGoal % 1000 == 0 ? "\(dailyGoal / 1000)K" : String(format: "%.1fK", Double(dailyGoal) / 1000)
    }

    /// The whole rule, in one line. No "5 of 7" tricks.
    var rule: String {
        let steps = "\(dailyGoal.formatted()) steps"
        let when = window.map { " between \($0.label)" } ?? ""
        if days == 1 { return "\(steps)\(when) in one day. That's it." }
        return "\(steps)\(when) every day for \(days) days. Miss a day and you're out."
    }

    var lengthLabel: String { days == 1 ? "1 day" : "\(days) days" }

    /// What each finisher gets if this share of the field finishes.
    func payout(finishRate: Double) -> Money {
        let finishers = max(Int((Double(entrants) * finishRate).rounded()), 1)
        return Money(cents: potCents / finishers, currency: currency)
    }

    /// What each finisher gets if everyone still in finishes.
    var livePayout: Money { Money(cents: potCents / max(stillIn, 1), currency: currency) }

    /// The finish rates shown before joining. Real step purses land between
    /// about 75% and 93% (16 public purse results, 7,141 entries, 77.5% finished).
    static let projectionRates: [Double] = [0.93, 0.85, 0.75]
}

// MARK: - Fees

/// The fee on top of every purse entry. It's how Steppie earns from purses:
/// win or lose, the same small amount, shown before you pin.
enum PurseFee {
    static let flatCents = 50
    static let percent = 0.04
    static let hostPercent = 0.05

    static func serviceCents(entryCents: Int, isPro: Bool) -> Int {
        isPro ? 0 : flatCents + Int((Double(entryCents) * percent).rounded())
    }

    static func hostCents(entryCents: Int, kind: PurseKind) -> Int {
        kind == .host ? Int((Double(entryCents) * hostPercent).rounded()) : 0
    }

    static func total(for purse: Purse, isPro: Bool) -> Int {
        serviceCents(entryCents: purse.entryUnits * 100, isPro: isPro) + hostCents(entryCents: purse.entryUnits * 100, kind: purse.kind)
    }

    /// Hosting a public purse costs this, or is free once a month with Pro.
    static let hostCreateCents = 2_500
}

// MARK: - Live board

/// One walker on a purse's live board.
struct PurseRunner: Identifiable, Hashable {
    enum State: String, Hashable { case finished, onPace, behind, out }

    var id: String { name }
    var rank: Int
    var name: String
    var steps: Int
    var state: State
    var isMe = false
}

/// A purse split paid out to someone, for the live payouts ticker.
struct PayoutEvent: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var purseName: String
    var amount: Money
    var profit: Money
    var at: Date
}

// MARK: - House purses

/// Steppie's own purses. They open every week; the backend runs the real ones.
enum PurseCatalog {
    struct Spec {
        let id: String, name: String, tagline: String, art: PurseArt
        let goal: Int, days: Int, window: StepWindow?, entry: Int
        let startOffset: Int, proOnly: Bool
    }

    static let specs: [Spec] = [
        Spec(id: "lions-share", name: "Lion's Share", tagline: "The flagship. Ten thousand a day, split with every finisher.",
             art: .lion, goal: 10_000, days: 7, window: nil, entry: 20, startOffset: 1, proOnly: false),
        Spec(id: "dawn-patrol", name: "Dawn Patrol", tagline: "Get it done before the coffee kicks in.",
             art: .sunrise, goal: 3_000, days: 5, window: StepWindow(startHour: 6, endHour: 9), entry: 10, startOffset: 1, proOnly: false),
        Spec(id: "one-and-done", name: "One and Done", tagline: "One big day. Twenty thousand steps, then you get paid.",
             art: .bolt, goal: 20_000, days: 1, window: nil, entry: 10, startOffset: 1, proOnly: false),
        Spec(id: "fresh-paws", name: "Fresh Paws", tagline: "Your first purse. Small entry, friendly goal.",
             art: .paw, goal: 6_000, days: 3, window: nil, entry: 5, startOffset: 1, proOnly: false),
        Spec(id: "night-shift", name: "Night Shift", tagline: "The evening walk, worth money. Steps after 8 pm.",
             art: .moon, goal: 4_000, days: 5, window: StepWindow(startHour: 20, endHour: 23), entry: 10, startOffset: 2, proOnly: false),
        Spec(id: "the-gauntlet", name: "The Gauntlet", tagline: "Fifteen thousand, ten days straight. Few finish. They split a lot.",
             art: .flame, goal: 15_000, days: 10, window: nil, entry: 50, startOffset: 3, proOnly: false),
        Spec(id: "golden-mane", name: "Golden Mane", tagline: "The big table. Twelve thousand a day for fifteen days.",
             art: .crown, goal: 12_000, days: 15, window: nil, entry: 250, startOffset: 5, proOnly: false),
        Spec(id: "walktober-finale", name: "Walktober Finale", tagline: "Close out the month on a high.",
             art: .leaf, goal: 9_000, days: 6, window: nil, entry: 25, startOffset: 1, proOnly: false),
        Spec(id: "winter-mane", name: "Winter Mane", tagline: "Thirty days through the cold. The habit that sticks.",
             art: .snow, goal: 10_000, days: 30, window: nil, entry: 50, startOffset: 7, proOnly: false),
    ]

    /// The catalog with no live numbers (before the backend answers).
    static func empty(currency: String = Money.localCurrency, now: Date = .now) -> [Purse] {
        specs.map { purse($0, currency: currency, now: now, entrants: 0) }
    }

    static func purse(_ s: Spec, currency: String, now: Date, entrants: Int, stillIn: Int? = nil, onPace: Int? = nil, startOffset: Int? = nil) -> Purse {
        let start = Calendar.current.date(byAdding: .day, value: startOffset ?? s.startOffset, to: Calendar.current.startOfDay(for: now)) ?? now
        return Purse(id: s.id, name: s.name, tagline: s.tagline, kind: .house, art: s.art, dailyGoal: s.goal, days: s.days,
                     window: s.window, entryUnits: s.entry, currency: currency, startsAt: start, entrants: entrants,
                     stillIn: stillIn ?? entrants, onPace: onPace ?? entrants, proOnly: s.proOnly)
    }
}

// MARK: - Invites

enum Invite {
    static let newMemberCreditCents = 500
    static let inviterBonusCents = 500

    /// A short code from your name: "SAM-4821".
    static func makeCode(name: String?) -> String {
        let letters = (name ?? "").uppercased().filter { $0.isLetter && $0.isASCII }
        let head = letters.isEmpty ? "LION" : String(letters.prefix(5))
        return "\(head)-\(Int.random(in: 1_000...9_999))"
    }

    static func isValid(_ code: String) -> Bool {
        let c = code.trimmingCharacters(in: .whitespaces).uppercased()
        return c.count >= 4 && c.count <= 16 && c.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" }
    }
}

// MARK: - Cash out

enum CashOut {
    static let minimumCents = 2_500
    static let dailyLimitCents = 50_000

    enum Method: String, CaseIterable, Identifiable {
        case bank, paypal

        var id: String { rawValue }
        var title: String { self == .bank ? "Bank account" : "PayPal" }
        var symbol: String { self == .bank ? "building.columns.fill" : "envelope.fill" }
        var timing: String { self == .bank ? "1 to 3 business days" : "Usually within a day" }
    }
}

// MARK: - Paid to Post

/// Members earn for posts about Steppie that people actually watch.
enum PaidToPost {
    static let centsPerThousandViews = 100
    static let capPerPostCents = 60_000

    static func earnings(views: Int) -> Money {
        Money(cents: min(views / 1_000 * centsPerThousandViews, capPerPostCents), currency: "USD")
    }
}
