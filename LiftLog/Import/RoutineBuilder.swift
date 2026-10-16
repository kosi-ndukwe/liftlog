import Foundation
import SwiftData

/// Turns workouts you've repeated into saved routines.
///
/// Workouts change a little from week to week (an extra fly, dumbbells instead
/// of a barbell), so two workouts count as the same routine when they share at
/// least half their exercises. Only workouts with 3 or more exercises from the
/// last `lookbackDays` are used, which leaves out single cardio sessions.
enum RoutineBuilder {
    struct Options: Sendable {
        var lookbackDays = 180
        var minimumExercises = 3
        var minimumRepeats = 3
        var maximumRoutines = 6
        /// Shared exercises ÷ all exercises across the two workouts.
        var similarity = 0.5
    }

    /// Returns how many routines were created.
    @discardableResult
    static func buildRoutines(in context: ModelContext, options: Options = .init()) throws -> Int {
        let sessions = try context.fetch(
            FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.start, order: .reverse)])
        )
        guard let newest = sessions.first?.start else { return 0 }
        let cutoff = newest.addingTimeInterval(-Double(options.lookbackDays) * 86_400)

        // Group recent workouts. Each group is compared against its newest workout.
        var groups: [[WorkoutSession]] = []
        for session in sessions where session.start >= cutoff {
            let exercises = names(in: session)
            guard exercises.count >= options.minimumExercises else { continue }
            let best = groups.indices
                .map { ($0, similarity(exercises, names(in: groups[$0][0]))) }
                .max { $0.1 < $1.1 }
            if let best, best.1 >= options.similarity {
                groups[best.0].append(session)
            } else {
                groups.append([session])
            }
        }

        var routines = try context.fetch(FetchDescriptor<Routine>())
        var added = 0
        let popular = groups
            .filter { $0.count >= options.minimumRepeats }
            .sorted { $0.count > $1.count }
            .prefix(options.maximumRoutines)

        for group in popular {
            let exercises = coreExercises(of: group)
            let core = Set(exercises.map(\.name))
            // Skip it if an existing routine already covers it (for example on a re-import).
            guard !routines.contains(where: { similarity(core, Set($0.orderedExercises.map(\.name))) >= options.similarity })
            else { continue }

            let routine = Routine(name: name(for: exercises))
            context.insert(routine)
            exercises.forEach(routine.append)
            routines.append(routine)
            added += 1
        }

        // Link past workouts to the routine they're closest to, so History can show its name.
        let routineNames = routines.map { ($0, Set($0.orderedExercises.map(\.name))) }
        for session in sessions where session.routine == nil {
            let exercises = names(in: session)
            guard exercises.count >= options.minimumExercises else { continue }
            let best = routineNames
                .map { ($0.0, similarity(exercises, $0.1)) }
                .max { $0.1 < $1.1 }
            if let best, best.1 >= options.similarity {
                session.routine = best.0
            }
        }

        return added
    }

    /// Exercises done in at least half the group's workouts, in the order of the
    /// most recent workout. Ones missing from it go at the end.
    static func coreExercises(of group: [WorkoutSession]) -> [Exercise] {
        var counts: [String: Int] = [:]
        for session in group {
            for name in names(in: session) { counts[name, default: 0] += 1 }
        }
        let isCore = { (exercise: Exercise) in Double(counts[exercise.name] ?? 0) >= Double(group.count) / 2 }

        var seen = Set<String>()
        var result: [Exercise] = []
        for session in group {
            for exercise in exercisesInOrder(session) where isCore(exercise) && seen.insert(exercise.name).inserted {
                result.append(exercise)
            }
        }
        return result
    }

    static func names(in session: WorkoutSession) -> Set<String> {
        Set(session.sets.compactMap { $0.exercise?.name })
    }

    static func similarity(_ a: Set<String>, _ b: Set<String>) -> Double {
        let union = a.union(b).count
        return union == 0 ? 0 : Double(a.intersection(b).count) / Double(union)
    }

    /// Each exercise once, in the order it was first done.
    static func exercisesInOrder(_ session: WorkoutSession) -> [Exercise] {
        var seen = Set<String>()
        return session.orderedSets.compactMap(\.exercise).filter { seen.insert($0.name).inserted }
    }

    /// For example "Barbell Bench Press, Cable Row + 3 more". You can rename routines later.
    static func name(for exercises: [Exercise]) -> String {
        let names = exercises.prefix(2).map(\.name).joined(separator: ", ")
        let remaining = exercises.count - 2
        return remaining > 0 ? "\(names) + \(remaining) more" : names
    }
}
