import Foundation
import SwiftData
import Testing
@testable import LiftLog

private let header = "Date,Exercise,Reps,Weight(kg),Duration(s),Distance(m),Incline,Resistance,isWarmup,Note,multiplier"

/// Builds one CSV line in Fitbod's format, including its leading spaces.
private func line(
    _ date: String,
    _ exercise: String,
    reps: Int = 10,
    kg: Double = 61.235042773811365,
    warmup: Bool = false,
    note: String = ""
) -> String {
    "\(date),\(exercise), \(reps),\(kg),0.0,0.0,0.0,0.0,\(warmup),\(note), 1.0"
}

private func csv(_ lines: [String]) -> String {
    ([header] + lines).joined(separator: "\n")
}

struct FitbodCSVTests {
    @Test func parsesARow() throws {
        let result = try FitbodCSV.parse(csv([line("2026-10-15 21:33:03 +0000", "Deadlift", warmup: true)]))
        let row = try #require(result.rows.first)

        #expect(row.exercise == "Deadlift")
        #expect(row.reps == 10)
        #expect(Weight.roundedToHalfPound(Weight.pounds(fromKg: row.weightKg)) == 135)
        #expect(row.isWarmup)
        #expect(row.multiplier == 1)
        #expect(row.date == Date(timeIntervalSince1970: 1_792_099_983))
        #expect(result.skippedLines == 0)
    }

    @Test func toleratesStrayQuotesInNotes() throws {
        let note = #"2x @ 42"  1x @ (walk up) "48"#
        let result = try FitbodCSV.parse(csv([line("2026-10-15 21:33:03 +0000", "Box Jump", note: note)]))
        #expect(result.rows.first?.note == note)
    }

    @Test func toleratesNoteStartingWithUnclosedQuote() throws {
        let result = try FitbodCSV.parse(csv([line("2026-10-15 21:33:03 +0000", "Box Jump", note: #""48 box"#)]))
        #expect(result.rows.first?.note == #""48 box"#)
        #expect(result.rows.first?.multiplier == 1)
    }

    @Test func keepsUnquotedCommasInNotes() throws {
        let result = try FitbodCSV.parse(csv([line("2026-10-15 21:33:03 +0000", "Squat", note: "felt good, slow tempo")]))
        #expect(result.rows.first?.note == "felt good, slow tempo")
        #expect(result.rows.first?.multiplier == 1)
    }

    @Test func readsQuotedFields() throws {
        let result = try FitbodCSV.parse(csv([line("2026-10-15 21:33:03 +0000", "Squat", note: #""said ""wow"", then left""#)]))
        #expect(result.rows.first?.note == #"said "wow", then left"#)
    }

    @Test func handlesWindowsLineEndingsAndByteOrderMark() throws {
        let text = "\u{FEFF}" + csv([line("2026-10-15 21:33:03 +0000", "Squat")]).replacingOccurrences(of: "\n", with: "\r\n") + "\r\n"
        let result = try FitbodCSV.parse(text)
        #expect(result.rows.count == 1)
    }

    @Test func skipsBadLines() throws {
        let result = try FitbodCSV.parse(csv([
            line("not a date", "Squat"),
            line("2026-10-15 21:33:03 +0000", ""),
            "2026-10-15 21:33:03 +0000,Squat",
            line("2026-10-15 21:33:03 +0000", "Squat"),
        ]))
        #expect(result.rows.count == 1)
        #expect(result.skippedLines == 3)
    }

    @Test func rejectsFilesThatArentFitbodExports() {
        #expect(throws: FitbodCSVError.missingColumns(["Date", "Exercise", "Reps", "Weight(kg)"])) {
            try FitbodCSV.parse("Name,Email\nKosi,k@example.com")
        }
        #expect(throws: FitbodCSVError.empty) {
            try FitbodCSV.parse("")
        }
    }
}

struct ImportSummaryTextTests {
    @Test func describesSummaryInPlainEnglish() {
        let summary = FitbodImportSummary(
            setsRead: 29_406, linesSkipped: 1, sessionsAdded: 1_234,
            sessionsAlreadyImported: 0, exercisesAdded: 159, routinesAdded: 1
        )
        #expect(SettingsView.describe(summary) == """
            Added 1,234 workouts, 159 exercises and 1 routine.
            1 line couldn't be read and skipped.
            """)
    }
}

@MainActor
struct FitbodImporterTests {
    let container: ModelContainer
    let importer: FitbodImporter
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try LiftLogSchema.makeInMemoryContainer()
        importer = FitbodImporter(modelContainer: container)
    }

    /// Two workouts, newest first, like Fitbod's export.
    private let twoWorkouts = csv([
        line("2026-10-15 21:33:03 +0000", "Cable Row", reps: 12),
        line("2026-10-15 21:33:03 +0000", "Deadlift", reps: 5),
        line("2026-10-15 21:33:03 +0000", "Deadlift", reps: 8, warmup: true),
        line("2026-10-13 20:00:00 +0000", "Back Squat", reps: 5),
    ])

    @Test func groupsSetsIntoWorkouts() async throws {
        let summary = try await importer.importCSV(twoWorkouts)

        #expect(summary.sessionsAdded == 2)
        #expect(summary.exercisesAdded == 3)
        #expect(summary.setsRead == 4)

        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.start)]))
        #expect(sessions.map(\.sets.count) == [1, 3])

        // Sets are stored oldest first: the warm-up came before the working set.
        let latest = try #require(sessions.last)
        #expect(latest.orderedSets.map(\.reps) == [8, 5, 12])
        #expect(latest.orderedSets.first?.isWarmup == true)
    }

    @Test func importingTwiceAddsNothing() async throws {
        _ = try await importer.importCSV(twoWorkouts)
        let second = try await importer.importCSV(twoWorkouts)

        #expect(second.sessionsAdded == 0)
        #expect(second.sessionsAlreadyImported == 2)
        #expect(second.exercisesAdded == 0)
        #expect(try context.fetchCount(FetchDescriptor<WorkoutSession>()) == 2)
        #expect(try context.fetchCount(FetchDescriptor<SetEntry>()) == 4)
        #expect(try context.fetchCount(FetchDescriptor<Exercise>()) == 3)
    }

    @Test func buildsRoutinesFromRepeatedWorkouts() async throws {
        var lines: [String] = []
        // "Push" done 3 times, newest with press first; "Legs" done once.
        for day in [20, 18, 16] {
            let date = "2026-10-\(day) 18:00:00 +0000"
            let order = day == 20 ? ["Pushdown", "Shoulder Press", "Bench Press"] : ["Pushdown", "Bench Press", "Shoulder Press"]
            lines += order.map { line(date, $0) }
        }
        lines.append(line("2026-10-14 18:00:00 +0000", "Leg Press"))

        let summary = try await importer.importCSV(csv(lines))
        #expect(summary.routinesAdded == 1)

        let routine = try #require(try context.fetch(FetchDescriptor<Routine>()).first)
        // Order comes from the most recent workout (file lines are newest last within a workout).
        #expect(routine.orderedExercises.map(\.name) == ["Bench Press", "Shoulder Press", "Pushdown"])
        #expect(routine.name == "Bench Press, Shoulder Press + 1 more")
        #expect(routine.sessions.count == 3)

        let again = try await importer.importCSV(csv(lines))
        #expect(again.routinesAdded == 0)
        #expect(try context.fetchCount(FetchDescriptor<Routine>()) == 1)
    }

    @Test func importsAFullSizeExportQuickly() async throws {
        // About the size of a real export: 1,234 workouts × 24 sets.
        let exercises = (1...15).map { "Exercise \($0)" }
        var lines: [String] = []
        let start = Date(timeIntervalSince1970: 1_792_099_983)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        for workout in 0..<1_234 {
            let date = formatter.string(from: start.addingTimeInterval(-Double(workout) * 86_400 * 1.5))
            let names = Array(exercises[(workout % 3 * 5)..<(workout % 3 * 5 + 5)])
            for set in 0..<24 {
                lines.append(line(date, names[set % 5], reps: 8))
            }
        }

        let clock = ContinuousClock()
        var summary = FitbodImportSummary()
        let elapsed = try await clock.measure {
            summary = try await importer.importCSV(csv(lines))
        }
        print("Imported \(lines.count) rows in \(elapsed)")

        #expect(summary.sessionsAdded == 1_234)
        #expect(summary.routinesAdded == 3)
        #expect(elapsed < .seconds(60))
    }
}
