import SwiftUI
import Observation
import WidgetKit

enum AppTab: String, Hashable {
    case today, races, progress, wallet
}

/// Single source of truth for the app. Owns services, local persistence and
/// the derived race state the screens render.
@MainActor
@Observable
final class AppModel {
    // MARK: State

    var profile: Profile
    var races: [Race]
    var ledger: [LedgerEntry]
    var todaySteps = 0
    var todayHourly: [Int] = Array(repeating: 0, count: 24)
    var history: [DaySteps] = []
    var weights: [WeightSample] = []
    var isPro = false
    var publicStats: PublicStats?
    var healthConnected = false
    var tab: AppTab = .today
    var celebrating: Race?
    var showingProfile = false
    var showingPaywall = false
    var lastError: String?

    let isDemo: Bool
    let health: HealthProviding
    let api = APIClient()
    let payments = PaymentService()
    let store = StoreService()

    private let profileStore = FileStore<Profile>(name: "profile")
    private let racesStore = FileStore<[Race]>(name: "races")
    private let ledgerStore = FileStore<[LedgerEntry]>(name: "ledger")

    // MARK: Derived

    var liveRaces: [Race] { races.filter { $0.status.isLive } }
    var finishedRaces: [Race] { races.filter { !$0.status.isLive } }
    var primaryRace: Race? { liveRaces.first { $0.todayIndex != nil } ?? liveRaces.first }

    /// Today's goal: the strictest live race today, else the personal goal.
    var todayGoal: Int {
        liveRaces.compactMap { $0.today?.goal }.max() ?? profile.dailyGoal
    }

    var onTheLine: Money {
        liveRaces.compactMap(\.stake).reduce(Money.zero(currency)) { $0 + $1 }
    }

    var returnedTotal: Money {
        ledger.filter { $0.kind.isReturn }.map(\.amount).reduce(Money.zero(currency)) { $0 + $1 }
    }

    var keptTotal: Money {
        ledger.filter { $0.kind == .kept }.map(\.amount).reduce(Money.zero(currency)) { $0 + $1 }
    }

    var currency: String { Money.localCurrency }

    /// Where a steady walker would be by now (07:00 to 21:00 window).
    var pacerFraction: Double {
        let cal = Calendar.current
        let now = Date.now
        let h = Double(cal.component(.hour, from: now)) + Double(cal.component(.minute, from: now)) / 60
        return min(max((h - 7) / 14, 0), 1)
    }

    var streak: Int {
        var count = 0
        for day in history.reversed() {
            if Calendar.current.isDateInToday(day.date) {
                if day.steps >= profile.dailyGoal { count += 1 }
                continue
            }
            if day.steps >= profile.dailyGoal { count += 1 } else { break }
        }
        return count
    }

    // MARK: Init

    init(demo: Bool) {
        isDemo = demo
        if demo {
            health = DemoHealthService()
        } else {
            health = HealthKitService()
        }
        if demo {
            profile = DemoSeed.profile
            races = DemoSeed.races()
            ledger = DemoSeed.ledger(races: races)
            publicStats = DemoSeed.stats
            healthConnected = true
        } else {
            profile = FileStore<Profile>(name: "profile").load() ?? Profile()
            races = FileStore<[Race]>(name: "races").load() ?? []
            ledger = FileStore<[LedgerEntry]>(name: "ledger").load() ?? []
            healthConnected = UserDefaults.standard.bool(forKey: "grinda.healthConnected")
        }
    }

    func bootstrap() async {
        if !isDemo {
            store.start { [weak self] pro in self?.isPro = pro }
            health.observeSteps { [weak self] in Task { await self?.refresh() } }
        }
        await refresh()
        if !isDemo, api.isConfigured {
            publicStats = try? await api.publicStats()
        }
    }

    // MARK: Health

    func connectHealth() async {
        do {
            try await health.requestAuthorization()
            healthConnected = true
            UserDefaults.standard.set(true, forKey: "grinda.healthConnected")
            await refresh()
            if profile.baseline == nil {
                let last = history.dropLast().suffix(14)
                if !last.isEmpty {
                    profile.baseline = last.map(\.steps).reduce(0, +) / last.count
                    profile.dailyGoal = Estimate.suggestedGoal(baseline: profile.baseline)
                    persist()
                }
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refresh() async {
        guard healthConnected else { return }
        if let today = try? await health.steps(on: .now) {
            todaySteps = today.total
            todayHourly = today.hourly
        }
        history = (try? await health.dailySteps(days: 35)) ?? history
        weights = (try? await health.weights(days: 90)) ?? weights
        reconcileRaces()
        writeWidget()
        if profile.notificationsEnabled {
            NotificationService.planPaceCheck(steps: todaySteps, goal: todayGoal, stake: primaryRace?.stake)
        }
        if !isDemo { await syncRaces() }
    }

    /// Updates each live race's day records from Health data.
    private func reconcileRaces() {
        let byDay = Dictionary(history.map { (Calendar.current.startOfDay(for: $0.date), $0.steps) }, uniquingKeysWith: { max($0, $1) })
        for r in races.indices where races[r].status == .active {
            for d in races[r].days.indices {
                let day = races[r].days[d]
                let cal = Calendar.current
                if cal.isDateInToday(day.date) {
                    races[r].days[d].steps = todaySteps
                    races[r].days[d].state = todaySteps >= day.goal ? .hit : .today
                } else if day.date < cal.startOfDay(for: .now) {
                    // Late syncs only ever add steps, so never lower a recorded count.
                    let steps = max(byDay[day.date] ?? 0, day.steps)
                    races[r].days[d].steps = steps
                    if day.state == .graced { continue }
                    races[r].days[d].state = steps >= day.goal ? .hit : .missed
                }
            }
        }
        persist()
    }

    private func writeWidget() {
        let r = primaryRace
        WidgetSnapshot(
            steps: todaySteps, goal: todayGoal, stakeLabel: r?.stake?.formatted, raceName: r?.name,
            dayIndex: r?.todayIndex.map { $0 + 1 }, dayCount: r?.days.count, updatedAt: .now
        ).save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Sends day totals + hourly buckets for server-side verification and settlement.
    private func syncRaces() async {
        guard api.isConfigured, api.session != nil else { return }
        let fmt = Self.dayFormatter
        for race in races where race.status == .active && !race.isPractice {
            let days = race.days.filter { $0.date <= .now }.map { day -> APIClient.DaySubmission in
                let hourly = Calendar.current.isDateInToday(day.date) ? todayHourly : []
                return .init(date: fmt.string(from: day.date), steps: day.steps, hourly: hourly)
            }
            try? await api.submitSteps(.init(raceId: race.id, days: days, attestation: nil))
        }
        if let remote = try? await api.races() {
            for r in remote {
                guard let i = races.firstIndex(where: { $0.id == r.id }) else { continue }
                let wasLive = races[i].status.isLive
                races[i].status = RaceStatus(rawValue: r.status) ?? races[i].status
                races[i].stakeState = StakeState(rawValue: r.stakeState) ?? races[i].stakeState
                races[i].settledAt = r.settledAt
                if wasLive && races[i].status == .won { celebrating = races[i] }
            }
        }
        if let remote = try? await api.ledger() {
            ledger = remote.map {
                LedgerEntry(id: $0.id, date: $0.createdAt, raceName: $0.raceName,
                            kind: LedgerKind(rawValue: $0.kind) ?? .held,
                            amount: Money(cents: $0.amountCents, currency: $0.currency), reference: $0.stripeRef)
            }
        }
        persist()
    }

    // MARK: Entering races

    enum EnterError: LocalizedError {
        case needsSignIn, underage, healthMissing, alreadyRunning

        var errorDescription: String? {
            switch self {
            case .needsSignIn: "Sign in with Apple to put money on a race."
            case .underage: "Staked races are for adults 18 and over. Practice laps are open to everyone."
            case .healthMissing: "Connect Apple Health first so your steps count."
            case .alreadyRunning: "You already have a race running. Grinda Pro lets you run up to three at once."
            }
        }
    }

    func canEnter(_ t: RaceTemplate) -> EnterError? {
        if !healthConnected { return .healthMissing }
        if !isPro && liveRaces.contains(where: { !$0.isPractice }) && t.kind == .staked { return .alreadyRunning }
        if t.kind == .staked {
            if !profile.isSignedIn && !isDemo { return .needsSignIn }
            if !profile.isAdult && !isDemo { return .underage }
        }
        return nil
    }

    nonisolated static func schedule(for t: RaceTemplate, startingToday: Bool) -> [Date] {
        let cal = Calendar.current
        var day = cal.startOfDay(for: startingToday ? .now : cal.date(byAdding: .day, value: 1, to: .now)!)
        var out: [Date] = []
        while out.count < t.days {
            if t.schedule == .consecutive || cal.isDateInWeekend(day) { out.append(day) }
            day = cal.date(byAdding: .day, value: 1, to: day)!
        }
        return out
    }

    /// Creates the race, takes payment (or a hold) and activates it.
    /// Returns false if the person cancelled the payment sheet.
    @discardableResult
    func enter(_ t: RaceTemplate, stake units: Int?, startingToday: Bool) async throws -> Bool {
        if let e = canEnter(t) { throw e }
        let dates = Self.schedule(for: t, startingToday: startingToday)
        let stake = units.map { Money(units: $0, currency: currency) }
        var race = Race(
            id: UUID(), templateID: t.id, name: t.name, dailyGoal: t.dailyGoal,
            bibNumber: Int.random(in: 1_000...9_999),
            days: dates.map { DayRecord(date: $0, steps: 0, goal: t.dailyGoal, state: .upcoming) },
            graceAllowed: t.graceDays, stake: stake,
            stakeState: stake == nil ? .none : (t.usesHold ? .held : .charged),
            status: stake == nil ? .active : .pendingPayment,
            usesHold: t.usesHold, cardLast4: nil, createdAt: .now, settledAt: nil
        )

        if let stake, !isDemo {
            let reply = try await api.createStake(.init(
                templateId: t.id, stakeCents: stake.cents, currency: stake.currency,
                timezone: TimeZone.current.identifier, startDate: Self.dayFormatter.string(from: dates[0]),
                birthYear: profile.birthYear
            ))
            race.id = reply.raceId
            race.bibNumber = reply.bibNumber
            guard try await payments.pay(reply, currency: stake.currency) == .paid else { return false }
            race.status = .active
        } else if let stake {
            try await Task.sleep(for: .milliseconds(900))
            race.status = .active
            race.cardLast4 = "4242"
            ledger.insert(LedgerEntry(id: UUID(), date: .now, raceName: t.name, kind: t.usesHold ? .held : .charged,
                                      amount: stake, reference: "pi_demo_\(race.bibNumber)"), at: 0)
        }

        races.insert(race, at: 0)
        reconcileRaces()
        writeWidget()
        return true
    }

    // MARK: Profile

    func completeOnboarding() {
        profile.onboarded = true
        persist()
    }

    func logWeight(_ kg: Double) async {
        weights.append(WeightSample(date: .now, kg: kg))
        profile.weightKg = kg
        persist()
        try? await health.saveWeight(kg: kg, date: .now)
    }

    func signedIn(appleUserID: String, name: String?) {
        profile.appleUserID = appleUserID
        if let name, !name.isEmpty { profile.displayName = name }
        persist()
    }

    func deleteAccount() async {
        try? await api.deleteAccount()
        profileStore.delete(); racesStore.delete(); ledgerStore.delete()
        profile = Profile(); races = []; ledger = []
    }

    func persist() {
        guard !isDemo else { return }
        profileStore.save(profile)
        racesStore.save(races)
        ledgerStore.save(ledger)
    }

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
