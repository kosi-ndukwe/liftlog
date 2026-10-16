import Foundation
import HealthKit

/// LiftLog's window onto Apple Health: today's steps, heart rate during a
/// workout (WHOOP writes it to Health), and saving finished workouts.
/// Everything here is optional; the app works without Health access.
@MainActor
final class HealthStore {
    static let shared = HealthStore()

    private let store = HKHealthStore()

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var stepType: HKQuantityType { HKQuantityType(.stepCount) }
    private var heartRateType: HKQuantityType { HKQuantityType(.heartRate) }

    /// Asks once for what the app reads and writes. Health remembers the answer.
    func requestAccess() async throws {
        guard Self.isAvailable else { return }
        try await store.requestAuthorization(
            toShare: [HKWorkoutType.workoutType()],
            read: [stepType, heartRateType]
        )
    }

    /// Steps since midnight, or nil if Health can't say.
    func stepsToday(now: Date = .now) async throws -> Int? {
        guard Self.isAvailable else { return nil }
        let start = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, error in
                if let error { continuation.resume(throwing: error); return }
                let steps = stats?.sumQuantity()?.doubleValue(for: .count())
                continuation.resume(returning: steps.map { Int($0) })
            }
            store.execute(query)
        }
    }

    struct HeartRateSummary: Equatable {
        var average: Double
        var peak: Double
    }

    /// Average and peak heart rate between two times, or nil without readings.
    func heartRate(from start: Date, to end: Date) async throws -> HeartRateSummary? {
        guard Self.isAvailable else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: heartRateType, quantitySamplePredicate: predicate, options: [.discreteAverage, .discreteMax]) { _, stats, error in
                if let error { continuation.resume(throwing: error); return }
                let unit = HKUnit.count().unitDivided(by: .minute())
                guard let average = stats?.averageQuantity()?.doubleValue(for: unit),
                      let peak = stats?.maximumQuantity()?.doubleValue(for: unit)
                else { continuation.resume(returning: nil); return }
                continuation.resume(returning: HeartRateSummary(average: average, peak: peak))
            }
            store.execute(query)
        }
    }

    /// Writes a finished workout to Health as traditional strength training.
    func saveWorkout(start: Date, end: Date, title: String) async throws {
        guard Self.isAvailable else { return }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        try await builder.beginCollection(at: start)
        try await builder.addMetadata([HKMetadataKeyWorkoutBrandName: "LiftLog", "LiftLogRoutine": title])
        try await builder.endCollection(at: end)
        try await builder.finishWorkout()
    }
}

/// What the user has switched on in Settings.
enum HealthSettings {
    static let readStepsKey = "healthReadSteps"
    static let readHeartRateKey = "healthReadHeartRate"
    static let saveWorkoutsKey = "healthSaveWorkouts"
}
