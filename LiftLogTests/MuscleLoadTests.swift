import Foundation
import SwiftData
import Testing
@testable import LiftLog

@MainActor
struct MuscleLoadTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try LiftLogSchema.makeInMemoryContainer()
    }

    @Test func countsWorkingSetsPerMuscle() throws {
        let bench = Exercise(name: "Bench")
        bench.primaryMuscles = ["chest"]
        bench.secondaryMuscles = ["triceps", "frontDelts"]
        let row = Exercise(name: "Row")
        row.primaryMuscles = ["lats", "upperBack"]
        context.insert(bench)
        context.insert(row)
        let session = WorkoutSession(start: .now)
        context.insert(session)
        session.sets.append(SetEntry(order: 0, exercise: bench, reps: 10, isWarmup: true))
        session.sets.append(SetEntry(order: 1, exercise: bench, reps: 8))
        session.sets.append(SetEntry(order: 2, exercise: bench, reps: 8))
        session.sets.append(SetEntry(order: 3, exercise: row, reps: 10))
        try context.save()

        let load = MuscleLoad(sessions: [session])
        // Two working bench sets; the warm-up doesn't count. Secondary muscles count half.
        #expect(load.sets[.chest] == 2)
        #expect(load.sets[.triceps] == 1)
        #expect(load.sets[.frontDelts] == 1)
        #expect(load.sets[.lats] == 1)
        #expect(load.sets[.upperBack] == 1)
        #expect(load.shading[.chest] == 1)
        #expect(load.shading[.triceps] == 0.5)
        #expect(load.ranked.first?.muscle == .chest)
        #expect(load.byGroup[.push] == 4)
        #expect(load.byGroup[.pull] == 2)
        #expect(load.byGroup[.legs] == nil)
    }

    @Test func emptyWithNoSets() {
        let load = MuscleLoad(sets: [])
        #expect(load.isEmpty)
        #expect(load.shading.isEmpty)
        #expect(load.ranked.isEmpty)
    }

    @Test func picksTheSideThatShowsTheMuscles() {
        #expect(BodyShapes.isMostlyOnBack([.lats, .biceps, .upperBack]))
        #expect(!BodyShapes.isMostlyOnBack([.chest, .triceps]))
        #expect(!BodyShapes.isMostlyOnBack([]))
        // Every muscle has a region on at least one side.
        let drawn = Set(BodyShapes.regions(for: .front).map(\.muscle) + BodyShapes.regions(for: .back).map(\.muscle))
        for muscle in Muscle.allCases where muscle != .fullBody {
            #expect(drawn.contains(muscle), "\(muscle) isn't drawn")
        }
    }
}
