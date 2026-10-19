import Foundation
import Testing
@testable import LiftLog

struct TimerParsingTests {
    @Test func formatsClock() {
        #expect(ClockFormat.clock(0) == "0:00")
        #expect(ClockFormat.clock(90) == "1:30")
        #expect(ClockFormat.clock(725) == "12:05")
        #expect(ClockFormat.clock(3_661) == "1:01:01")
    }

    @Test func readsWhatPeopleType() {
        #expect(ClockFormat.parseClock("1:30") == 90)
        #expect(ClockFormat.parseClock("90") == 90)
        #expect(ClockFormat.parseClock("1.5") == 90)      // minutes
        #expect(ClockFormat.parseClock("1:01:01") == 3_661)
        #expect(ClockFormat.parseClock("") == 0)
        #expect(ClockFormat.parseClock("abc") == nil)
    }

    @MainActor @Test func catalogueEntriesCarryPhotosAndSteps() throws {
        let entries = try ExerciseCatalogue.load()
        #expect(entries.count > 1_200)
        let plank = try #require(entries.first { $0.name == "Plank" })
        #expect(plank.kind == "timed")
        #expect((plank.instructions ?? []).count >= 2)
        #expect(plank.images?.count == 2)
        // Every photo the catalogue names is in the app bundle (checked by file, not decoded).
        let bundled = Set((Bundle.main.urls(forResourcesWithExtension: "jpg", subdirectory: nil) ?? []).map(\.lastPathComponent))
        let missing = entries.flatMap { $0.images ?? [] }.filter { !bundled.contains($0) }
        #expect(missing.isEmpty, "\(missing.count) photos missing, e.g. \(missing.prefix(3))")
        #expect(ExercisePhoto.load("Plank__0.jpg") != nil)
    }
}
