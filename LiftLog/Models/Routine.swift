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
