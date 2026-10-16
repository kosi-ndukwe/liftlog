import Foundation
import SwiftData

/// Starts, fills in and finishes a workout. The workout in progress is an
/// ordinary `WorkoutSession` with no `end`, so it survives the app closing.
/// Planned sets have `isCompleted == false`; they're pre-filled from the last
/// time you did the exercise.
enum WorkoutLogger {
    /// How many sets to plan for an exercise you've never done.
    static let defaultSetCount = 3

    /// The workout in progress, if there is one.
    static func inProgress(in context: ModelContext) throws -> WorkoutSession? {
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.end == nil },
            sortBy: [SortDescriptor(\.start, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Begins a workout from a routine (or an empty one) with planned sets.
    @discardableResult
    static func start(routine: Routine?, in context: ModelContext, now: Date = .now) throws -> WorkoutSession {
        let session = WorkoutSession(start: now, routine: routine)
        context.insert(session)
        for exercise in routine?.orderedExercises ?? [] {
            add(exercise, to: session)
        }
        try context.save()
        return session
    }

    /// Adds an exercise with sets planned from the last time you did it.
    static func add(_ exercise: Exercise, to session: WorkoutSession) {
        var order = (session.sets.map(\.order).max() ?? -1) + 1
        let previous = lastSets(of: exercise, before: session)
        if previous.isEmpty {
            for _ in 0..<defaultSetCount {
                session.sets.append(planned(order: order, exercise: exercise, reps: 0, weightKg: 0, isWarmup: false))
                order += 1
            }
        } else {
            for set in previous {
                session.sets.append(planned(order: order, exercise: exercise, reps: set.reps, weightKg: set.weightKg, isWarmup: set.isWarmup, multiplier: set.multiplier))
                order += 1
            }
        }
    }

    /// Adds one more set after the exercise's last one, copying it.
    @discardableResult
    static func addSet(for exercise: Exercise, to session: WorkoutSession) -> SetEntry {
        let last = session.orderedSets.last { $0.exercise == exercise }
        let order = (session.sets.map(\.order).max() ?? -1) + 1
        let set = planned(order: order, exercise: exercise, reps: last?.reps ?? 0, weightKg: last?.weightKg ?? 0, isWarmup: false, multiplier: last?.multiplier ?? 1)
        session.sets.append(set)
        return set
    }

    /// Removes an exercise and all its sets from the workout.
    static func remove(_ exercise: Exercise, from session: WorkoutSession, in context: ModelContext) {
        for set in session.sets where set.exercise == exercise {
            context.delete(set)
        }
        session.sets.removeAll { $0.exercise == exercise }
    }

    /// Ends the workout: drops sets that were never done, records the time
    /// and refreshes the totals. Returns false (and deletes the workout) if
    /// nothing was done at all.
    @discardableResult
    static func finish(_ session: WorkoutSession, in context: ModelContext, now: Date = .now) throws -> Bool {
        let undone = session.sets.filter { !$0.isCompleted }
        undone.forEach(context.delete)
        session.sets.removeAll { !$0.isCompleted }
        guard !session.sets.isEmpty else {
            context.delete(session)
            try context.save()
            return false
        }
        session.end = now
        session.refreshSummary()
        for exercise in session.exercisesInOrder { exercise.refreshStats() }
        try context.save()
        return true
    }

    /// Throws the workout away.
    static func discard(_ session: WorkoutSession, in context: ModelContext) throws {
        context.delete(session)
        try context.save()
    }

    /// The sets from the most recent finished workout that included the exercise.
    static func lastSets(of exercise: Exercise, before session: WorkoutSession) -> [SetEntry] {
        let candidates = exercise.sets.compactMap(\.session).filter { $0 != session && $0.end != nil }
        guard let latest = candidates.max(by: { $0.start < $1.start }) else { return [] }
        return latest.orderedSets.filter { $0.exercise == exercise }
    }

    private static func planned(order: Int, exercise: Exercise, reps: Int, weightKg: Double, isWarmup: Bool, multiplier: Double = 1) -> SetEntry {
        let set = SetEntry(order: order, exercise: exercise, reps: reps, weightKg: weightKg, isWarmup: isWarmup, multiplier: multiplier)
        set.isCompleted = false
        return set
    }
}

extension WorkoutSession {
    /// Sets done so far in a workout in progress.
    var completedCount: Int { sets.filter(\.isCompleted).count }
}
