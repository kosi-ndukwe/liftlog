import Foundation
import SwiftData
import Testing
@testable import LiftLog

@MainActor
struct WorkoutLoggerTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let bench: Exercise
    let row: Exercise
    let routine: Routine

    init() throws {
        container = try LiftLogSchema.makeInMemoryContainer()
        bench = Exercise(name: "Bench")
        row = Exercise(name: "Row")
        routine = Routine(name: "push")
        context.insert(bench)
        context.insert(row)
        context.insert(routine)
        routine.append(bench)

        // One finished bench workout a week ago: a warm-up and two working sets.
        let past = WorkoutSession(start: Date(timeIntervalSinceNow: -7 * 86_400), end: Date(timeIntervalSinceNow: -7 * 86_400 + 3_600))
        context.insert(past)
        for (order, (reps, pounds, warmup)) in [(10, 95.0, true), (8, 135.0, false), (6, 145.0, false)].enumerated() {
            let set = SetEntry(order: order, exercise: bench, reps: reps, isWarmup: warmup)
            set.weightLb = pounds
            past.sets.append(set)
        }
        try context.save()
    }

    @Test func startPlansSetsFromLastTime() throws {
        let session = try WorkoutLogger.start(routine: routine, in: context)
        #expect(session.end == nil)
        #expect(try WorkoutLogger.inProgress(in: context) == session)
        let sets = session.orderedSets
        #expect(sets.map(\.reps) == [10, 8, 6])
        #expect(sets.map(\.weightLb) == [95, 135, 145])
        #expect(sets.map(\.isWarmup) == [true, false, false])
        #expect(sets.allSatisfy { !$0.isCompleted })
    }

    @Test func newExerciseGetsThreeEmptySets() throws {
        let session = try WorkoutLogger.start(routine: nil, in: context)
        WorkoutLogger.add(row, to: session)
        let sets = session.orderedSets.filter { $0.exercise == row }
        #expect(sets.count == WorkoutLogger.defaultSetCount)
        #expect(sets.allSatisfy { $0.reps == 0 && $0.weightKg == 0 })
    }

    @Test func addSetCopiesTheLastOne() throws {
        let session = try WorkoutLogger.start(routine: routine, in: context)
        let added = WorkoutLogger.addSet(for: bench, to: session)
        #expect(added.reps == 6)
        #expect(added.weightLb == 145)
        #expect(added.order == 3)
        #expect(!added.isCompleted)
    }

    @Test func finishKeepsOnlyCompletedSets() throws {
        let session = try WorkoutLogger.start(routine: routine, in: context)
        let sets = session.orderedSets
        sets[0].isCompleted = true
        sets[1].isCompleted = true
        sets[1].weightLb = 140
        #expect(try WorkoutLogger.finish(session, in: context))
        #expect(session.end != nil)
        #expect(session.sets.count == 2)
        #expect(session.setCount == 2)
        #expect(session.volumeLb == 10 * 95 + 8 * 140)
        #expect(try WorkoutLogger.inProgress(in: context) == nil)
        #expect(bench.loggedSetCount == 5)
    }

    @Test func finishingWithNothingDoneDeletesTheWorkout() throws {
        let session = try WorkoutLogger.start(routine: routine, in: context)
        #expect(try !WorkoutLogger.finish(session, in: context))
        #expect(try context.fetch(FetchDescriptor<WorkoutSession>()).count == 1)
    }

    @Test func discardDeletesTheWorkoutAndItsSets() throws {
        let session = try WorkoutLogger.start(routine: routine, in: context)
        try WorkoutLogger.discard(session, in: context)
        #expect(try context.fetch(FetchDescriptor<WorkoutSession>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<SetEntry>()).count == 3)
    }
}
