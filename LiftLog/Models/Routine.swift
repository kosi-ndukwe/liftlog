import Foundation
import SwiftData

/// A saved workout you repeat, such as "Push Day", with its exercises in order.
@Model
final class Routine {
    var name: String
    var createdAt: Date
    /// Position on the Today screen. Lower comes first.
    var sortOrder: Int = 0

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

    /// When this routine was last finished (a workout in progress doesn't count).
    var lastDone: Date? {
        sessions.filter { $0.end != nil }.map(\.start).max()
    }

    /// Adds an exercise to the end of the routine.
    func append(_ exercise: Exercise) {
        let nextOrder = (entries.map(\.order).max() ?? -1) + 1
        entries.append(RoutineExercise(order: nextOrder, exercise: exercise))
    }

    /// Takes an exercise out of the routine.
    func remove(_ exercise: Exercise, in context: ModelContext) {
        for entry in entries where entry.exercise == exercise {
            context.delete(entry)
        }
        entries.removeAll { $0.exercise == exercise }
        renumber()
    }

    /// Moves exercises the way a list's drag handle does.
    func move(from source: IndexSet, to destination: Int) {
        var ordered = entries.sorted { $0.order < $1.order }
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, entry) in ordered.enumerated() { entry.order = index }
    }

    /// Makes the orders 0, 1, 2… again after a removal.
    private func renumber() {
        for (index, entry) in entries.sorted(by: { $0.order < $1.order }).enumerated() {
            entry.order = index
        }
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
