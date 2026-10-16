import Foundation
import SwiftData

/// A saved workout you repeat, such as "Push Day", with its exercises in order.
@Model
final class Routine {
    var name: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \RoutineExercise.routine)
    var entries: [RoutineExercise] = []

    /// Past sessions started from this routine. Deleting the routine keeps them.
    @Relationship(deleteRule: .nullify, inverse: \WorkoutSession.routine)
    var sessions: [WorkoutSession] = []

    init(name: String, createdAt: Date = .now) {
        self.name = name
        self.createdAt = createdAt
    }

    /// The routine's exercises in the order you do them.
    var orderedExercises: [Exercise] {
        entries.sorted { $0.order < $1.order }.compactMap(\.exercise)
    }

    /// "push", "pull" or "legs", from the muscles its exercises mainly work;
    /// nil when the exercises don't know their muscles yet.
    var suggestedName: String? {
        var tally: [MuscleGroup: Int] = [:]
        for exercise in orderedExercises {
            for muscle in exercise.primary where muscle.group != .cardio && muscle.group != .core {
                tally[muscle.group, default: 0] += 1
            }
        }
        return tally.max { $0.value < $1.value }?.key.rawValue
    }

    /// When this routine was last done.
    var lastDone: Date? {
        sessions.map(\.start).max()
    }

    /// Adds an exercise to the end of the routine.
    func append(_ exercise: Exercise) {
        let nextOrder = (entries.map(\.order).max() ?? -1) + 1
        entries.append(RoutineExercise(order: nextOrder, exercise: exercise))
    }
}

/// One slot in a routine. SwiftData doesn't keep lists in order, so this
/// small record stores each exercise's position.
@Model
final class RoutineExercise {
    var order: Int
    var routine: Routine?
    var exercise: Exercise?

    init(order: Int, exercise: Exercise) {
        self.order = order
        self.exercise = exercise
    }
}
