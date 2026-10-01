import UserNotifications

/// At most two nudges a day, and only when they help: a pace check in the
/// evening when you're behind, and a streak-at-risk note before 21:00.
enum NotificationService {
    static let paceID = "grinda.pace"

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Re-plans tonight's pace check from the latest numbers. Cancels it once the goal is hit.
    static func planPaceCheck(steps: Int, goal: Int, stake: Money?, at hour: Int = 19, minute: Int = 30) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [paceID])
        guard steps < goal else { return }

        let cal = Calendar.current
        guard let fire = cal.date(bySettingHour: hour, minute: minute, second: 0, of: .now), fire > .now else { return }

        // Assume a normal afternoon adds ~35% more before the nudge fires.
        let projected = Int(Double(steps) * 1.35)
        let left = max(goal - projected, goal - steps > 0 ? 500 : 0)
        let minutes = Estimate.minutes(steps: left)

        let content = UNMutableNotificationContent()
        if let stake {
            content.title = "Grin's lacing up 🦁"
            content.body = "About \(left.formatted()) steps keeps your \(stake.formatted). A \(minutes)-minute walk does it."
        } else {
            content.title = "Grin's waiting at the track"
            content.body = "\(left.formatted()) steps to go. A \(minutes)-minute walk closes today's lap."
        }
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        let request = UNNotificationRequest(identifier: paceID, content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
        center.add(request)
    }
}
