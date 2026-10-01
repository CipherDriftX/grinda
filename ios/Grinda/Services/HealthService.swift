import Foundation
import HealthKit

/// Everything Grinda needs from a step source. Implemented by Apple Health
/// and by a deterministic demo source used for previews and screenshots.
protocol HealthProviding: AnyObject {
    var isAvailable: Bool { get }
    func requestAuthorization() async throws
    /// Steps for one local calendar day, as a total plus 24 hourly buckets.
    func steps(on day: Date) async throws -> (total: Int, hourly: [Int])
    /// Daily totals for the last `days` days, oldest first, including today.
    func dailySteps(days: Int) async throws -> [DaySteps]
    func weights(days: Int) async throws -> [WeightSample]
    func saveWeight(kg: Double, date: Date) async throws
    /// Called on the main queue whenever new step samples arrive.
    func observeSteps(_ handler: @escaping () -> Void)
}

enum HealthError: LocalizedError {
    case unavailable
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .unavailable: "Apple Health isn't available on this device."
        case .notAuthorized: "Grinda can't read your steps. Turn on Steps in Settings › Health › Data Access › Grinda."
        }
    }
}

final class HealthKitService: HealthProviding {
    private let store = HKHealthStore()
    private let stepType = HKQuantityType(.stepCount)
    private let weightType = HKQuantityType(.bodyMass)
    private let distanceType = HKQuantityType(.distanceWalkingRunning)
    private var observer: HKObserverQuery?

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async throws {
        guard isAvailable else { throw HealthError.unavailable }
        try await store.requestAuthorization(
            toShare: [weightType],
            read: [stepType, weightType, distanceType]
        )
    }

    /// Manually typed step samples don't count toward races (anti-cheat).
    private var excludeUserEntered: NSPredicate {
        HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeyWasUserEntered, operatorType: .notEqualTo, value: true)
    }

    func steps(on day: Date) async throws -> (total: Int, hourly: [Int]) {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        let buckets = try await collection(start: start, end: end, interval: DateComponents(hour: 1))
        var hourly = Array(repeating: 0, count: 24)
        for (date, value) in buckets {
            let h = cal.component(.hour, from: date)
            if h < 24 { hourly[h] = value }
        }
        return (hourly.reduce(0, +), hourly)
    }

    func dailySteps(days: Int) async throws -> [DaySteps] {
        let cal = Calendar.current
        let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: .now))!
        let start = cal.date(byAdding: .day, value: -days, to: end)!
        let buckets = try await collection(start: start, end: end, interval: DateComponents(day: 1))
        return buckets.map { DaySteps(date: $0.0, steps: $0.1) }
    }

    private func collection(start: Date, end: Date, interval: DateComponents) async throws -> [(Date, Int)] {
        let range = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [range, excludeUserEntered])
        return try await withCheckedThrowingContinuation { cont in
            let q = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: start,
                intervalComponents: interval
            )
            q.initialResultsHandler = { _, results, error in
                if let error { cont.resume(throwing: error); return }
                var out: [(Date, Int)] = []
                results?.enumerateStatistics(from: start, to: end) { stat, _ in
                    let v = stat.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    out.append((stat.startDate, Int(v)))
                }
                cont.resume(returning: out)
            }
            store.execute(q)
        }
    }

    func weights(days: Int) async throws -> [WeightSample] {
        let start = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        return try await withCheckedThrowingContinuation { cont in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let q = HKSampleQuery(sampleType: weightType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, error in
                if let error { cont.resume(throwing: error); return }
                let out = (samples as? [HKQuantitySample] ?? []).map {
                    WeightSample(date: $0.startDate, kg: $0.quantity.doubleValue(for: .gramUnit(with: .kilo)))
                }
                cont.resume(returning: out)
            }
            store.execute(q)
        }
    }

    func saveWeight(kg: Double, date: Date) async throws {
        let q = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg)
        try await store.save(HKQuantitySample(type: weightType, quantity: q, start: date, end: date))
    }

    func observeSteps(_ handler: @escaping () -> Void) {
        guard observer == nil else { return }
        let q = HKObserverQuery(sampleType: stepType, predicate: nil) { _, completion, _ in
            DispatchQueue.main.async(execute: handler)
            completion()
        }
        observer = q
        store.execute(q)
        store.enableBackgroundDelivery(for: stepType, frequency: .hourly) { _, _ in }
    }
}

/// Deterministic, realistic step data for demo mode, previews and screenshots.
final class DemoHealthService: HealthProviding {
    var isAvailable: Bool { true }
    func requestAuthorization() async throws {}

    /// A believable walking day: quiet night, commute bumps, lunch walk, evening walk.
    static let dayShape: [Double] = [0, 0, 0, 0, 0, 0.1, 0.5, 1.4, 1.1, 0.6, 0.5, 0.7,
                                     1.5, 0.9, 0.5, 0.6, 0.8, 1.3, 1.6, 1.0, 0.5, 0.2, 0.05, 0]

    private func seeded(_ day: Date) -> Double {
        let n = Calendar.current.ordinality(of: .day, in: .era, for: day) ?? 1
        return Double((n * 9301 + 49297) % 233280) / 233280
    }

    func steps(on day: Date) async throws -> (total: Int, hourly: [Int]) {
        let cal = Calendar.current
        if cal.isDateInToday(day) {
            // Today in the demo: 6,480 steps by early evening.
            let target = 6_480.0
            let throughHour = 17
            let weight = Self.dayShape[0...throughHour].reduce(0, +)
            let hourly = (0..<24).map { h in h <= throughHour ? Int(Self.dayShape[h] / weight * target) : 0 }
            return (hourly.reduce(0, +), hourly)
        }
        let r = seeded(day)
        let total = 7_200 + Int(r * 6_400)
        let sum = Self.dayShape.reduce(0, +)
        let hourly = Self.dayShape.map { Int($0 / sum * Double(total)) }
        return (hourly.reduce(0, +), hourly)
    }

    func dailySteps(days: Int) async throws -> [DaySteps] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        var out: [DaySteps] = []
        for i in stride(from: days - 1, through: 0, by: -1) {
            let d = cal.date(byAdding: .day, value: -i, to: today)!
            // The demo walker started about two months ago.
            if i > 60 { out.append(DaySteps(date: d, steps: 0)); continue }
            var total = try await steps(on: d).total
            // Earlier weeks were lower: the habit is building.
            if i > 21 { total = Int(Double(total) * 0.68) } else if i > 14 { total = Int(Double(total) * 0.82) }
            if (1...11).contains(i) { total = max(total, 10_150 + (i * 373) % 2_600) }
            if i == 12 { total = 5_900 } // one honest miss
            out.append(DaySteps(date: d, steps: total))
        }
        return out
    }

    func weights(days: Int) async throws -> [WeightSample] {
        let cal = Calendar.current
        return stride(from: days, through: 0, by: -3).map { i in
            let d = cal.date(byAdding: .day, value: -i, to: .now)!
            let trend = 86.4 - (Double(days - i) / Double(days)) * 3.1
            let wobble = sin(Double(i) * 1.7) * 0.35
            return WeightSample(date: d, kg: ((trend + wobble) * 10).rounded() / 10)
        }
    }

    func saveWeight(kg: Double, date: Date) async throws {}
    func observeSteps(_ handler: @escaping () -> Void) {}
}
