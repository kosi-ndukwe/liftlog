import Foundation
import SwiftData

struct FitbodImportSummary: Sendable, Equatable {
    var setsRead = 0
    var linesSkipped = 0
    var sessionsAdded = 0
    var sessionsAlreadyImported = 0
    var exercisesAdded = 0
    var routinesAdded = 0
}

/// Saves a Fitbod export into the database. It runs in the background
/// (a "model actor") so the screen doesn't freeze during a large import.
@ModelActor
actor FitbodImporter {
    func importFile(at url: URL, routineOptions: RoutineBuilder.Options = .init()) throws -> FitbodImportSummary {
        // Files picked from the Files app need permission to be opened.
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)
        return try importCSV(String(decoding: data, as: UTF8.self), routineOptions: routineOptions)
    }

    func importCSV(_ text: String, routineOptions: RoutineBuilder.Options = .init()) throws -> FitbodImportSummary {
        let parsed = try FitbodCSV.parse(text)
        var summary = FitbodImportSummary(setsRead: parsed.rows.count, linesSkipped: parsed.skippedLines)

        // Every set in a Fitbod workout shares the same timestamp, so group by it.
        var rowsByDate: [Date: [FitbodRow]] = [:]
        var dates: [Date] = []
        for row in parsed.rows {
            if rowsByDate[row.date] == nil { dates.append(row.date) }
            rowsByDate[row.date, default: []].append(row)
        }

        // Workouts already in the database are skipped, so importing twice is safe.
        let existingStarts = Set(try modelContext.fetch(FetchDescriptor<WorkoutSession>()).map(\.start))
        var exercisesByName = Dictionary(
            try modelContext.fetch(FetchDescriptor<Exercise>()).map { ($0.name, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        // The file is newest first; add the oldest workout first.
        for date in dates.reversed() {
            guard !existingStarts.contains(date) else {
                summary.sessionsAlreadyImported += 1
                continue
            }

            // Fitbod records one time per workout, so start and end are the same.
            let session = WorkoutSession(start: date, end: date)
            modelContext.insert(session)

            // Sets within a workout are also listed newest first, so reverse them.
            for (order, row) in (rowsByDate[date] ?? []).reversed().enumerated() {
                let exercise: Exercise
                if let existing = exercisesByName[row.exercise] {
                    exercise = existing
                } else {
                    exercise = Exercise(name: row.exercise)
                    modelContext.insert(exercise)
                    exercisesByName[row.exercise] = exercise
                    summary.exercisesAdded += 1
                }

                session.sets.append(SetEntry(
                    order: order,
                    exercise: exercise,
                    reps: row.reps,
                    weightKg: row.weightKg,
                    durationSeconds: row.durationSeconds,
                    distanceMeters: row.distanceMeters,
                    isWarmup: row.isWarmup,
                    note: row.note,
                    multiplier: row.multiplier
                ))
            }
            summary.sessionsAdded += 1
        }

        summary.routinesAdded = try RoutineBuilder.buildRoutines(in: modelContext, options: routineOptions)
        try modelContext.save()
        return summary
    }
}
