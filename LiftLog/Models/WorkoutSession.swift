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

    /// The routine's name, or the exercises done, e.g. "Cycling".
    var title: String {
        if let routine { return routine.name }
        let exercises = exercisesInOrder
        return exercises.isEmpty ? "Workout" : RoutineBuilder.name(for: exercises)
    }
}
