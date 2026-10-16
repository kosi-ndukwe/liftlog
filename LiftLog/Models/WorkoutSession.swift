import Foundation
import SwiftData

/// One workout, from start to finish.
@Model
final class WorkoutSession {
    var start: Date
    /// Empty while the workout is still in progress.
    var end: Date?
    var routine: Routine?

    /// Beats per minute, read from Apple Health (WHOOP) after the workout.
    var averageHeartRate: Double?
    var peakHeartRate: Double?

    // Totals kept on the session so lists don't have to load every set.
    // Call `refreshSummary()` after changing the sets.
    var setCount: Int = 0
    /// reps × weight × multiplier over every set, in lb (what Fitbod calls volume).
    var volumeLb: Double = 0
    /// Exercise names in the order they were first done.
    var exerciseNames: [String] = []
    /// "push", "pull", "legs" or "core": the muscle group most of the exercises work.
    var muscleGroup: String = ""
    /// 0 means the totals above were never worked out.
    var summaryVersion: Int = 0

    static let currentSummaryVersion = 2

    /// Deleting a session deletes its sets.
    @Relationship(deleteRule: .cascade, inverse: \SetEntry.session)
    var sets: [SetEntry] = []

    init(start: Date, end: Date? = nil, routine: Routine? = nil) {
        self.start = start
        self.end = end
        self.routine = routine
    }

    /// Sets in the order they were done.
    var orderedSets: [SetEntry] {
        sets.sorted { $0.order < $1.order }
    }

    var duration: TimeInterval? {
        end.map { $0.timeIntervalSince(start) }
    }

    /// Each exercise once, in the order it was first done.
    var exercisesInOrder: [Exercise] {
        var seen = Set<String>()
        return orderedSets.compactMap(\.exercise).filter { seen.insert($0.name).inserted }
    }

    /// Works out the stored totals from the sets.
    func refreshSummary() {
        let ordered = orderedSets
        setCount = ordered.count
        volumeLb = ordered.map(\.volumeLb).reduce(0, +)
        var seen = Set<String>()
        exerciseNames = ordered.compactMap { $0.exercise?.name }.filter { seen.insert($0).inserted }
        var tally: [MuscleGroup: Int] = [:]
        for exercise in exercisesInOrder {
            for muscle in exercise.primary { tally[muscle.group, default: 0] += 1 }
        }
        muscleGroup = tally.max { $0.value < $1.value }?.key.rawValue ?? ""
        summaryVersion = Self.currentSummaryVersion
    }

    var group: MuscleGroup? { MuscleGroup(rawValue: muscleGroup) }

    /// The routine's name, else the muscle group ("legs"), else the exercises done, e.g. "Cycling".
    var title: String {
        if let routine { return routine.name }
        let names = summaryVersion > 0 ? exerciseNames : exercisesInOrder.map(\.name)
        if names.count >= 3, let group, group != .cardio { return group.rawValue }
        return names.isEmpty ? "Workout" : RoutineBuilder.name(for: names)
    }

    /// "Deadlift, Lat Pulldown, Cable Face Pull and 5 more".
    var exerciseSummary: String {
        let names = summaryVersion > 0 ? exerciseNames : exercisesInOrder.map(\.name)
        let shown = names.prefix(3).joined(separator: ", ")
        let more = names.count - 3
        return more > 0 ? "\(shown) and \(more) more" : shown
    }
}
