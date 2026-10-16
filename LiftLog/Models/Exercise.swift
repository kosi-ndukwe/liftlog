import Foundation
import SwiftData

/// A movement you do, such as "Barbell Bench Press" or "Cycling".
@Model
final class Exercise {
    /// Matches the Fitbod export's Exercise column, so names must be unique.
    @Attribute(.unique) var name: String

    /// Every set ever logged for this exercise. Deleting an exercise keeps
    /// the history (the sets just lose their link) rather than erasing it.
    @Relationship(deleteRule: .nullify, inverse: \SetEntry.exercise)
    var sets: [SetEntry] = []

    /// The places this exercise appears in routines.
    @Relationship(deleteRule: .cascade, inverse: \RoutineExercise.exercise)
    var routineEntries: [RoutineExercise] = []

    init(name: String) {
        self.name = name
    }
}
