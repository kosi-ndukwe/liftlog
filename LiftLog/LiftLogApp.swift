import SwiftData
import SwiftUI

@main
struct LiftLogApp: App {
    // Creates the on-device database and shares it with every screen.
    let container: ModelContainer = {
        do {
            return try ModelContainer(for: Schema(LiftLogSchema.models))
        } catch {
            fatalError("Couldn't open the database: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                // The app is dark like a gym app should be; Palette has light values for later.
                .preferredColorScheme(.dark)
                .tint(Palette.accent)
                .task {
                    await Startup.run(container: container)
                }
        }
        .modelContainer(container)
    }
}

/// Housekeeping done in the background each launch: add any built-in
/// exercises that are missing, and work out totals for workouts that don't
/// have them yet (ones imported before the totals existed).
enum Startup {
    static func run(container: ModelContainer) async {
        await Task.detached(priority: .utility) {
            let context = ModelContext(container)
            do {
                try ExerciseCatalogue.seed(ExerciseCatalogue.load(), into: context)
                try backfillSummaries(in: context)
                try backfillExerciseStats(in: context)
                try nameRoutines(in: context)
            } catch {
                print("Startup housekeeping failed: \(error)")
            }
        }.value
    }

    static func backfillSummaries(in context: ModelContext) throws {
        let version = WorkoutSession.currentSummaryVersion
        let stale = try context.fetch(FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.summaryVersion < version }
        ))
        guard !stale.isEmpty else { return }
        for (index, session) in stale.enumerated() {
            session.refreshSummary()
            if index % 200 == 199 { try context.save() }
        }
        try context.save()
    }

    static func backfillExerciseStats(in context: ModelContext) throws {
        let version = Exercise.currentStatsVersion
        let stale = try context.fetch(FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.statsVersion < version }
        ))
        guard !stale.isEmpty else { return }
        stale.forEach { $0.refreshStats() }
        try context.save()
    }

    /// Routines made from the import were named after their first two
    /// exercises ("Deadlift, Cable Row + 7 more"). Now that exercises know
    /// their muscles, give those a short name like "pull" instead.
    static func nameRoutines(in context: ModelContext) throws {
        let routines = try context.fetch(FetchDescriptor<Routine>(sortBy: [SortDescriptor(\.createdAt)]))
        var taken = Set(routines.map(\.name))
        for routine in routines where RoutineBuilder.isGeneratedName(routine.name) {
            guard let base = routine.suggestedName else { continue }
            var candidate = base
            var number = 2
            while taken.contains(candidate) {
                candidate = "\(base) \(number)"
                number += 1
            }
            taken.remove(routine.name)
            taken.insert(candidate)
            routine.name = candidate
        }
        if context.hasChanges { try context.save() }
    }
}
