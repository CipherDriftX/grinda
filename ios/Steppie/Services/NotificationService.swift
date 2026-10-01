import UserNotifications

/// Two kinds of notification, never both at once:
///
/// 1. **Race invites** (opt-in, while nothing is staked). Pip brings one message
///    a day at most, on a decaying schedule (days 0, 1, 2, 4, 7, 10, 14, 21, 28
///    after onboarding or the last finish), each built on a different, honest
///    reason to start: a fresh start (Mondays, the 1st), your own shadow week, a
///    real comeback deadline, a Shield waiting in the locker.
/// 2. **Pace nudge** (while a stake is live). One evening check, only if you're
///    behind, cancelled the moment the goal is hit. Once money is down the app
///    goes quiet and lets you walk.
enum NotificationService {
    static let paceID = "steppie.pace"
    static let invitePrefix = "steppie.invite."

    struct Plan {
        var steps: Int
        var goal: Int
        var stake: Money?
        var hasLiveStake: Bool
        var invites: Bool
        var anchor: Date
        var comebackDeadline: Date?
        var comebackStake: Money?
        var shadow: (hits: Int, days: Int)
        var shields: Int
        var suggested: Money?
    }

    static let cadence = [0, 1, 2, 4, 7, 10, 14, 21, 28]

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func plan(_ p: Plan) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let old = pending.map(\.identifier).filter { $0.hasPrefix(invitePrefix) }
            center.removePendingNotificationRequests(withIdentifiers: old + [paceID])
            if p.hasLiveStake {
                planPaceCheck(p)
            } else if p.invites {
                planInvites(p)
            }
        }
    }

    // MARK: Pace (stake live)

    private static func planPaceCheck(_ p: Plan, hour: Int = 19, minute: Int = 30) {
        guard p.steps < p.goal else { return }
        let cal = Calendar.current
        guard let fire = cal.date(bySettingHour: hour, minute: minute, second: 0, of: .now), fire > .now else { return }

        // Assume a normal afternoon adds ~35% more before the nudge fires.
        let projected = Int(Double(p.steps) * 1.35)
        let left = max(p.goal - projected, 500)
        let minutes = Estimate.minutes(steps: left)

        let content = UNMutableNotificationContent()
        if let stake = p.stake {
            content.title = "Steppie's lacing up 🦁"
            content.body = "About \(left.formatted()) steps keeps your \(stake.formatted). A \(minutes)-minute walk does it."
        } else {
            content.title = "Steppie's waiting at the track"
            content.body = "\(left.formatted()) steps to go. A \(minutes)-minute walk closes today's lap."
        }
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        add(paceID, content, at: fire)
    }

    // MARK: Invites (nothing staked)

    private static func planInvites(_ p: Plan) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: p.anchor)
        var scheduled = 0
        for (i, offset) in cadence.enumerated() {
            guard scheduled < 4, let day = cal.date(byAdding: .day, value: offset, to: start) else { continue }
            // Lunch on odd steps, early evening on even ones: the two moments people decide.
            let (h, m) = i % 2 == 0 ? (18, 30) : (12, 15)
            guard let fire = cal.date(bySettingHour: h, minute: m, second: 0, of: day), fire > .now else { continue }
            let content = invite(index: i, on: fire, p)
            content.sound = .default
            content.interruptionLevel = .active
            add(invitePrefix + "\(offset)", content, at: fire)
            scheduled += 1
        }
    }

    /// Picks the most relevant true reason for that day.
    private static func invite(index: Int, on date: Date, _ p: Plan) -> UNMutableNotificationContent {
        let cal = Calendar.current
        let c = UNMutableNotificationContent()
        let stake = p.suggested?.formatted ?? Money(units: 10).formatted

        if let deadline = p.comebackDeadline, let lost = p.comebackStake, date < deadline {
            let hours = Int(deadline.timeIntervalSince(date) / 3600)
            c.title = "Pip: your Comeback closes in \(hours)h 🐦"
            c.body = "Finish a 5-day Comeback and half of your \(lost.formatted) comes back too."
            return c
        }
        if cal.component(.weekday, from: date) == 2 {
            c.title = "Pip: Monday. Clean slate. 🐦"
            c.body = "New weeks are when habits stick. Pin a bib today and Steppie runs it with you."
            return c
        }
        if cal.component(.day, from: date) == 1 {
            c.title = "Pip: new month, new mane 🐦"
            c.body = "Start the month with a race. Back yourself with \(stake) and keep every cent when you finish."
            return c
        }
        switch index % 4 {
        case 0 where p.shadow.days >= 3:
            c.title = "Pip: you'd have kept it 🐦"
            c.body = "You hit your goal \(p.shadow.hits) of the last \(p.shadow.days) days. With \(stake) on it, that's money you'd have kept. Make it count this time."
        case 1 where p.shields > 0:
            c.title = "Pip: Shelly's holding a Shield for you 🐢"
            c.body = "Your first race comes with a Shield: one bad day covered. Pin a bib and it's yours to use."
        case 2:
            c.title = "Pip: your bib's half pinned 🐦"
            c.body = "Your goal's set and Steppie's laced up. One hold on your card and you're racing. Short races are never charged if you finish."
        default:
            c.title = "Pip: Dash is out on the track 🐆"
            c.body = "People with money on the line hit their goal about 3 times in 4. Back yourself with \(stake) and show Dash who's faster."
        }
        return c
    }

    private static func add(_ id: String, _ content: UNMutableNotificationContent, at fire: Date) {
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
    }
}
