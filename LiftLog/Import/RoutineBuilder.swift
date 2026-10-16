import Foundation
import SwiftData

/// Turns workouts you've repeated into saved routines.
///
/// Two workouts count as "the same" when they contain the same exercises, in
/// any order. A routine is made for each combination done at least
/// `minimumRepeats` times in the last `lookbackDays`, and its exercise order
/// comes from the most recent time you did it.
enum RoutineBuilder {
    struct Options: Sendable {
        var lookbackDays = 365
        var minimumRepeats = 3
        var maximumRoutines = 8
    }

    /// Returns how many routines were created.
    @discardableResult
    static func buildRoutines(in context: ModelContext, options: Options = .init()) throws -> Int {
        let sessions = try context.fetch(
            FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.start, order: .reverse)])
        )
        guard let newest = sessions.first?.start else { return 0 }
        let cutoff = newest.addingTimeInterval(-Double(options.lookbackDays) * 86_400)

        var routinesBySignature: [Set<String>: Routine] = [:]
        for routine in try context.fetch(FetchDescriptor<Routine>()) {
            routinesBySignature[Set(routine.orderedExercises.map(\.name))] = routine
        }

        // Sessions are newest first, so the first one seen for a signature is the latest.
        var counts: [Set<String>: Int] = [:]
        var latest: [Set<String>: WorkoutSession] = [:]
        for session in sessions where session.start >= cutoff {
            let signature = signature(of: session)
            guard !signature.isEmpty else { continue }
            counts[signature, default: 0] += 1
            if latest[signature] == nil { latest[signature] = session }
        }

        let popular = counts
            .filter { $0.value >= options.minimumRepeats }
            .sorted {
                $0.value != $1.value
                    ? $0.value > $1.value
                    : (latest[$0.key]?.start ?? .distantPast) > (latest[$1.key]?.start ?? .distantPast)
            }
            .prefix(options.maximumRoutines)

        var added = 0
        for (signature, _) in popular where routinesBySignature[signature] == nil {
            guard let template = latest[signature] else { continue }
            let exercises = exercisesInOrder(template)
            let routine = Routine(name: name(for: exercises))
            context.insert(routine)
            exercises.forEach(routine.append)
            routinesBySignature[signature] = routine
            added += 1
        }

        // Link past workouts to the routine they match, so History can show its name.
        for session in sessions where session.routine == nil {
            session.routine = routinesBySignature[signature(of: session)]
        }

        return added
    }

    /// The names of the exercises in a workout, ignoring order.
    static func signature(of session: WorkoutSession) -> Set<String> {
        Set(session.sets.compactMap { $0.exercise?.name })
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
