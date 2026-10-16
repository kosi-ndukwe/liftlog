import Foundation
import SwiftData

/// After a workout is finished: read its heart rate from Health and,
/// if switched on, save it to Health. Failures are logged, never shown;
/// the workout is already saved in the app either way.
enum WorkoutHealthSync {
    @MainActor
    static func run(for session: WorkoutSession, in context: ModelContext) async {
        guard HealthStore.isAvailable, let end = session.end else { return }
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: HealthSettings.readHeartRateKey) {
            do {
                if let summary = try await HealthStore.shared.heartRate(from: session.start, to: end) {
                    session.averageHeartRate = summary.average
                    session.peakHeartRate = summary.peak
                    try context.save()
                }
            } catch {
                print("Couldn't read heart rate: \(error)")
            }
        }
        if defaults.bool(forKey: HealthSettings.saveWorkoutsKey) {
            do {
                try await HealthStore.shared.saveWorkout(start: session.start, end: end, title: session.title)
            } catch {
                print("Couldn't save the workout to Health: \(error)")
            }
        }
    }
}
