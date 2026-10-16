import Foundation
import SwiftData
import Testing
@testable import LiftLog

@MainActor
struct RoutineEditingTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let bench: Exercise
    let row: Exercise
    let squat: Exercise

    init() throws {
        container = try LiftLogSchema.makeInMemoryContainer()
        bench = Exercise(name: "Bench")
        row = Exercise(name: "Row")
        squat = Exercise(name: "Squat")
        [bench, row, squat].forEach(context.insert)
    }

    @Test func removingRenumbersTheRest() throws {
        let routine = Routine(name: "full")
        context.insert(routine)
        [bench, row, squat].forEach(routine.append)
        routine.remove(row, in: context)
        try context.save()
        #expect(routine.orderedExercises.map(\.name) == ["Bench", "Squat"])
        #expect(routine.entries.map(\.order).sorted() == [0, 1])
        #expect(try context.fetch(FetchDescriptor<RoutineExercise>()).count == 2)
    }

    @Test func movingKeepsTheOrderYouDragged() throws {
        let routine = Routine(name: "full")
        context.insert(routine)
        [bench, row, squat].forEach(routine.append)
        routine.move(from: IndexSet(integer: 2), to: 0)
        try context.save()
        #expect(routine.orderedExercises.map(\.name) == ["Squat", "Bench", "Row"])
    }

    @Test func replacingSetsExactlyThatList() throws {
        let routine = Routine(name: "push")
        context.insert(routine)
        [bench, row].forEach(routine.append)
        routine.replaceExercises(with: [squat, bench], in: context)
        try context.save()
        #expect(routine.orderedExercises.map(\.name) == ["Squat", "Bench"])
        #expect(try context.fetch(FetchDescriptor<RoutineExercise>()).count == 2)
    }

    @Test func deletingARoutineKeepsItsWorkouts() throws {
        let routine = Routine(name: "push")
        context.insert(routine)
        routine.append(bench)
        let session = WorkoutSession(start: .now, end: .now, routine: routine)
        context.insert(session)
        try context.save()
        context.delete(routine)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<WorkoutSession>()).count == 1)
        #expect(session.routine == nil)
        #expect(try context.fetch(FetchDescriptor<RoutineExercise>()).isEmpty)
    }
}
