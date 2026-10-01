import Foundation

/// Small value the app writes to the shared App Group so the widget can draw
/// today's track without touching HealthKit or the network.
struct WidgetSnapshot: Codable, Equatable {
    var steps: Int
    var goal: Int
    var stakeLabel: String?
    var raceName: String?
    var dayIndex: Int?
    var dayCount: Int?
    var updatedAt: Date
    var maneLevel: Int? = nil
    var line: String? = nil

    var progress: Double { goal > 0 ? min(Double(steps) / Double(goal), 1) : 0 }
    var remaining: Int { max(goal - steps, 0) }

    static let placeholder = WidgetSnapshot(
        steps: 6_480, goal: 10_000, stakeLabel: "€20", raceName: "10K Week",
        dayIndex: 4, dayCount: 7, updatedAt: .now, maneLevel: 2, line: "3,520 to go. You've got this."
    )

    private static let key = "grinda.widget.snapshot"

    static var appGroup: String {
        (Bundle.main.object(forInfoDictionaryKey: "GrindaAppGroup") as? String) ?? "group.com.cipherdriftx.grinda"
    }

    static func load() -> WidgetSnapshot? {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: Self.appGroup)?.set(data, forKey: Self.key)
    }
}
