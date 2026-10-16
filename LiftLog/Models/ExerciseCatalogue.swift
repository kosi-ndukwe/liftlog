import Foundation
import SwiftData

/// The built-in list of exercises (`Resources/ExerciseCatalogue.json`): a few
/// hundred common movements with the muscles they work. On launch it adds
/// any that are missing and fills in muscles for imported exercises that
/// don't have them yet.
enum ExerciseCatalogue {
    struct Entry: Decodable, Sendable {
        var name: String
        var equipment: String
        var primary: [String]
        var secondary: [String]
        var kind: String
    }

    static func load() throws -> [Entry] {
        guard let url = Bundle.main.url(forResource: "ExerciseCatalogue", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode([Entry].self, from: Data(contentsOf: url))
    }

    /// Returns how many exercises were added.
    @discardableResult
    static func seed(_ entries: [Entry], into context: ModelContext) throws -> Int {
        let existing = Dictionary(
            try context.fetch(FetchDescriptor<Exercise>()).map { ($0.name, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var added = 0
        for entry in entries {
            if let exercise = existing[entry.name] {
                // Only fill gaps, so edits you make later aren't overwritten.
                if exercise.primaryMuscles.isEmpty { exercise.primaryMuscles = entry.primary }
                if exercise.secondaryMuscles.isEmpty { exercise.secondaryMuscles = entry.secondary }
                if exercise.equipment.isEmpty { exercise.equipment = entry.equipment }
                if exercise.kind.isEmpty { exercise.kind = entry.kind }
            } else {
                let exercise = Exercise(name: entry.name)
                exercise.primaryMuscles = entry.primary
                exercise.secondaryMuscles = entry.secondary
                exercise.equipment = entry.equipment
                exercise.kind = entry.kind
                context.insert(exercise)
                added += 1
            }
        }
        if context.hasChanges { try context.save() }
        return added
    }
}
