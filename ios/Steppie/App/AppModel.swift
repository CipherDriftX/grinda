import SwiftUI
import Observation
import StoreKit
import WidgetKit

enum AppTab: String, Hashable {
    case today, races, league, progress, wallet
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
    var lifetimeSteps = 0
    var newMilestone: Milestone?
    /// Increment to make Steppie hop on Today (goal hit, taps).
    var steppieHop = 0
    var coachSeed = Int.random(in: 0..<1000)
    var showingShields = false
    var showingShoeBox = false
    var leagueBoard: [APIClient.BoardRow] = []

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

    // MARK: Game layer

    var finishedStakedCount: Int { races.filter { $0.status == .won && !$0.isPractice }.count }

    func isUnlocked(_ tier: StakeTier) -> Bool { isDemo || finishedStakedCount >= tier.unlockAfter }

    /// The latest settled staked race decides the ladder's next rung.
    func suggestedStake(for t: RaceTemplate) -> Int? {
        let last = races.filter { !$0.isPractice && ($0.status == .won || $0.status == .lost) }
            .max { ($0.settledAt ?? $0.createdAt) < ($1.settledAt ?? $1.createdAt) }
        let open = t.suggestedStakes.filter { isUnlocked(StakeTier.tier(units: $0)) }
        return StakeLadder.suggestion(lastStake: last?.stake?.units, lastWon: last.map { $0.status == .won }, options: open)
    }

    /// A missed staked race from the last 72 hours that can still get its one comeback.
    var comebackOffer: Race? {
        races.first { r in
            guard r.status == .lost, !r.isPractice, !r.isComeback, let settled = r.settledAt else { return false }
            guard Date.now.timeIntervalSince(settled) < 72 * 3600 else { return false }
            return !races.contains { $0.comebackOf == r.id && $0.status != .cancelled }
        }
    }

    func comebackDeadline(_ r: Race) -> Date { (r.settledAt ?? .now).addingTimeInterval(72 * 3600) }

    /// Grit earned this week (Monday start) from race days.
    var weekGrit: Int {
        let cal = Calendar(identifier: .iso8601)
        guard let monday = cal.dateInterval(of: .weekOfYear, for: .now)?.start else { return 0 }
        return races.filter { $0.status != .cancelled }.reduce(0) { sum, r in
            sum + r.days.filter { $0.date >= monday && $0.date <= .now }.reduce(0) { $0 + Grit.day(steps: $1.steps, tier: r.tier) }
        }
    }

    /// For people who haven't backed themselves yet: what the last 7 days would
    /// have looked like with a stake on them. Their own numbers, nothing invented.
    var shadowWeek: (hits: Int, days: Int) {
        let past = history.dropLast().suffix(7)
        return (past.filter { $0.steps >= profile.dailyGoal }.count, past.count)
    }

    /// When the "not staked yet" sequence starts counting: the last settle, else onboarding.
    var funnelAnchor: Date {
        races.compactMap(\.settledAt).max() ?? profile.onboardedAt ?? .now
    }

    var shoesOwned: Set<String> { Set(profile.shoes) }
    var wearing: ShoeStyle { ShoeStyle.find(profile.wearing) }

    /// Opens one Shoe Box. Odds depend on the most recent finish's length.
    @discardableResult
    func openShoeBox() -> ShoeStyle? {
        guard profile.unopenedBoxes > 0 else { return nil }
        let days = races.filter { $0.status == .won }.max { ($0.settledAt ?? .distantPast) < ($1.settledAt ?? .distantPast) }?.days.count ?? 3
        let shoe = ShoeBox.roll(days: days, owned: shoesOwned)
        profile.unopenedBoxes -= 1
        if !profile.shoes.contains(shoe.id) { profile.shoes.append(shoe.id) }
        persist()
        return shoe
    }

    func wear(_ shoe: ShoeStyle) {
        guard shoesOwned.contains(shoe.id) else { return }
        profile.wearing = shoe.id
        Haptics.tick()
        persist()
    }

    /// Finishing anything earns a Shoe Box.
    private func finished(_ race: Race) {
        profile.unopenedBoxes += 1
        celebrating = race
    }

    // MARK: Shields

    func buyShields(_ product: StoreKit.Product) async {
        do {
            let account = api.session.flatMap { UUID(uuidString: $0.userID) }
            guard let t = try await StoreService.buy(product, account: account) else { return }
            await credit(t)
            await t.finish()
            Haptics.success()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func credit(_ t: StoreKit.Transaction) async {
        if isDemo || !api.isConfigured {
            profile.shields += t.productID.hasSuffix(".3") ? 3 : 1
        } else if let n = try? await api.grantShields(transactionID: t.id) {
            profile.shields = n
        }
        persist()
    }

    func loadLeague() async {
        if isDemo { leagueBoard = DemoSeed.league(me: profile.displayName ?? "You", grit: weekGrit); return }
        leagueBoard = (try? await api.leagueBoard()) ?? []
    }

    /// Where a steady walker would be by now (07:00 to 21:00 window).
    var pacerFraction: Double {
        let cal = Calendar.current
        let now = Date.now
        let h = Double(cal.component(.hour, from: now)) + Double(cal.component(.minute, from: now)) / 60
        return min(max((h - 7) / 14, 0), 1)
    }

    /// Goal days in the last 14 (today counts once it's hit).
    var goalDays14: Int {
        history.suffix(14).filter { day in
            Calendar.current.isDateInToday(day.date) ? todaySteps >= todayGoal : day.steps >= profile.dailyGoal
        }.count
    }

    var maneLevel: Int { Coach.maneLevel(goalDaysOf14: goalDays14) }

    var lifetimeKm: Double { Estimate.km(steps: lifetimeSteps) }

    var coachContext: Coach.Context {
        Coach.Context(steps: todaySteps, goal: todayGoal, stake: primaryRace?.stake, streak: streak,
                          pacerSteps: Int(Double(todayGoal) * pacerFraction),
                          hour: Calendar.current.component(.hour, from: .now))
    }

    var earnedMilestones: Set<String> {
        let finished = races.filter { $0.status == .won }
        var out = Set<String>()
        for m in Milestone.all {
            let ok: Bool
            switch m.kind {
            case .km: ok = lifetimeKm >= m.threshold
            case .streak: ok = Double(streak) >= m.threshold
            case .races: ok = Double(finished.count) >= m.threshold
            case .season:
                ok = finished.contains { r in
                    let c = Calendar.current.dateComponents([.year, .month], from: r.settledAt ?? r.endDate)
                    return c.year == 2026 && c.month == 10
                }
            }
            if ok { out.insert(m.id) }
        }
        return out
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
            let seeded = DemoSeed.races()
            races = seeded
            ledger = DemoSeed.ledger(races: seeded)
            publicStats = DemoSeed.stats
            healthConnected = true
            isPro = true
        } else {
            profile = FileStore<Profile>(name: "profile").load() ?? Profile()
            races = FileStore<[Race]>(name: "races").load() ?? []
            ledger = FileStore<[LedgerEntry]>(name: "ledger").load() ?? []
            healthConnected = UserDefaults.standard.bool(forKey: "steppie.healthConnected")
        }
    }

    func bootstrap() async {
        if !isDemo {
            store.start(onChange: { [weak self] pro in self?.isPro = pro },
                        onShields: { [weak self] t in await self?.credit(t) })
            health.observeSteps { [weak self] in Task { await self?.refresh() } }
        }
        await refresh()
        if !isDemo, api.isConfigured {
            publicStats = try? await api.publicStats()
            if let me = try? await api.me() {
                profile.shields = me.shields
                profile.league = League(rawValue: me.league) ?? profile.league
                persist()
            }
        }
    }

    // MARK: Health

    func connectHealth() async {
        do {
            try await health.requestAuthorization()
            healthConnected = true
            UserDefaults.standard.set(true, forKey: "steppie.healthConnected")
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
        let wasDone = todaySteps >= todayGoal && todaySteps > 0
        if let today = try? await health.steps(on: .now) {
            todaySteps = today.total
            todayHourly = today.hourly
        }
        if !wasDone && todaySteps >= todayGoal && todaySteps > 0 {
            steppieHop += 1
            Haptics.success()
        }
        history = (try? await health.dailySteps(days: 35)) ?? history
        weights = (try? await health.weights(days: 90)) ?? weights
        if let year = try? await health.dailySteps(days: 365) {
            lifetimeSteps = year.map(\.steps).reduce(0, +)
        }
        reconcileRaces()
        checkMilestones()
        writeWidget()
        if profile.notificationsEnabled {
            NotificationService.plan(.init(
                steps: todaySteps, goal: todayGoal, stake: primaryRace?.stake,
                hasLiveStake: liveRaces.contains { !$0.isPractice }, invites: profile.invitesEnabled,
                anchor: funnelAnchor, comebackDeadline: comebackOffer.map { comebackDeadline($0) },
                comebackStake: comebackOffer?.stake, shadow: shadowWeek, shields: profile.shields,
                suggested: suggestedStake(for: RaceTemplate.board[0]).map { Money(units: $0, currency: currency) }
            ))
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
        settlePracticeLaps()
        persist()
    }

    /// Practice laps have no money and no server side, so they settle on device
    /// once their last day is over.
    private func settlePracticeLaps() {
        let today = Calendar.current.startOfDay(for: .now)
        for i in races.indices where races[i].isPractice && races[i].status == .active {
            guard let last = races[i].days.last, last.date < today else { continue }
            let won = races[i].missedCount <= races[i].graceAllowed + races[i].shieldsEquipped
            races[i].status = won ? .won : .lost
            races[i].settledAt = .now
            if won { finished(races[i]) }
        }
    }

    private func writeWidget() {
        let r = primaryRace
        WidgetSnapshot(
            steps: todaySteps, goal: todayGoal, stakeLabel: r?.stake?.formatted, raceName: r?.name,
            dayIndex: r?.todayIndex.map { $0 + 1 }, dayCount: r?.days.count, updatedAt: .now,
            maneLevel: maneLevel, line: Coach.line(coachContext, seed: coachSeed)
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
                if wasLive && races[i].status == .won { finished(races[i]) }
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

    // MARK: Milestones

    private static let seenKey = "steppie.seenMilestones"

    /// Presents the first newly earned medal. On first launch, existing medals are
    /// marked seen silently so people aren't flooded.
    func checkMilestones() {
        let defaults = UserDefaults.standard
        let earned = earnedMilestones
        guard let seen = defaults.stringArray(forKey: Self.seenKey) else {
            defaults.set(Array(earned), forKey: Self.seenKey)
            return
        }
        let fresh = earned.subtracting(seen)
        guard !fresh.isEmpty, !isDemo else { return }
        defaults.set(Array(earned.union(seen)), forKey: Self.seenKey)
        newMilestone = Milestone.all.first { fresh.contains($0.id) }
    }

    // MARK: Entering races

    enum EnterError: LocalizedError {
        case needsSignIn, underage, healthMissing, alreadyRunning

        var errorDescription: String? {
            switch self {
            case .needsSignIn: "Sign in with Apple to put money on a race."
            case .underage: "Staked races are for adults 18 and over. Practice laps are open to everyone."
            case .healthMissing: "Connect Apple Health first so your steps count."
            case .alreadyRunning: "You already have a race running. Steppie Pro lets you run up to three at once."
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
    func enter(_ t: RaceTemplate, stake units: Int?, startingToday: Bool, shields: Int = 0, comebackOf: UUID? = nil) async throws -> Bool {
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
            usesHold: t.usesHold, cardLast4: nil, createdAt: .now, settledAt: nil,
            shieldsEquipped: stake == nil ? 0 : min(shields, profile.shields, 2), comebackOf: comebackOf
        )

        if let stake, !isDemo {
            let reply = try await api.createStake(.init(
                templateId: t.id, stakeCents: stake.cents, currency: stake.currency,
                timezone: TimeZone.current.identifier, startDate: Self.dayFormatter.string(from: dates[0]),
                birthYear: profile.birthYear, shieldsEquipped: race.shieldsEquipped, comebackOf: comebackOf
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

        profile.shields -= race.shieldsEquipped
        races.insert(race, at: 0)
        reconcileRaces()
        writeWidget()
        return true
    }

    // MARK: Profile

    func completeOnboarding() {
        profile.onboarded = true
        profile.onboardedAt = .now
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
