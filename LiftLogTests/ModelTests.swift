import Foundation
import SwiftData
import Testing
@testable import LiftLog

struct WeightTests {
    @Test func fitbodKilogramsConvertToPounds() {
        // Value taken from the Fitbod export: 135 lb stored as kg.
        let pounds = Weight.roundedToHalfPound(Weight.pounds(fromKg: 61.235042773811365))
        #expect(pounds == 135)
    }

    @Test func roundsToNearestHalfPound() {
        #expect(Weight.roundedToHalfPound(137.3) == 137.5)
        #expect(Weight.roundedToHalfPound(137.2) == 137)
    }

    @Test func formatsPounds() {
        #expect(Weight.formattedPounds(fromKg: Weight.kg(fromPounds: 135)) == "135 lb")
        #expect(Weight.formattedPounds(fromKg: Weight.kg(fromPounds: 137.5)) == "137.5 lb")
    }
}

@MainActor
struct ModelTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try LiftLogSchema.makeInMemoryContainer()
    }

    @Test func routineKeepsExerciseOrder() throws {
        let routine = Routine(name: "Push Day")
        context.insert(routine)
        for name in ["Bench", "Shoulder Press", "Pushdown"] {
            routine.append(Exercise(name: name))
        }
        try context.save()

        #expect(routine.orderedExercises.map(\.name) == ["Bench", "Shoulder Press", "Pushdown"])
    }

    @Test func settingPoundsStoresKilograms() {
        let set = SetEntry(order: 0, exercise: nil)
        set.weightLb = 225
        #expect(abs(set.weightKg - 102.0582) < 0.001)
        #expect(set.weightLb == 225)
    }

    @Test func deletingSessionDeletesSetsButKeepsExercise() throws {
        let squat = Exercise(name: "Back Squat")
        context.insert(squat)
        let session = WorkoutSession(start: .now)
        context.insert(session)
        session.sets.append(SetEntry(order: 0, exercise: squat, reps: 5))
        session.sets.append(SetEntry(order: 1, exercise: squat, reps: 5))
        try context.save()

        context.delete(session)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<SetEntry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Exercise>()) == 1)
    }

    @Test func deletingRoutineKeepsItsSessions() throws {
        let routine = Routine(name: "Legs")
        context.insert(routine)
        let session = WorkoutSession(start: .now, routine: routine)
        context.insert(session)
        try context.save()

        context.delete(routine)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<WorkoutSession>()) == 1)
        #expect(session.routine == nil)
    }
}
