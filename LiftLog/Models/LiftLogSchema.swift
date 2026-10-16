import Foundation
import SwiftData

/// Every type the app saves. Add new model types here.
enum LiftLogSchema {
    static var models: [any PersistentModel.Type] {
        [Exercise.self, Routine.self, RoutineExercise.self, WorkoutSession.self, SetEntry.self]
    }

    /// A throwaway store that lives only in memory, for previews and tests.
    static func makeInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
