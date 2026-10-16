import Foundation
import SwiftData

/// A movement you do, such as "Barbell Bench Press" or "Cycling".
@Model
final class Exercise {
    /// Matches the Fitbod export's Exercise column, so names must be unique.
    @Attribute(.unique) var name: String

    /// Muscle ids from `Muscle`, the ones the exercise mainly works.
    var primaryMuscles: [String] = []
    /// Muscles that help out.
    var secondaryMuscles: [String] = []
    /// "barbell", "dumbbell", "cable", "machine", "bodyweight", "cardio"… See `Equipment`.
    var equipment: String = ""
    /// How the exercise is logged: see `ExerciseKind`.
    var kind: String = ""

    // Kept on the exercise so the list doesn't have to load every set.
    // The importer updates them; `Startup` fills them in for older data.
    var loggedSetCount: Int = 0
    var lastLogged: Date?
    var statsVersion: Int = 0

    static let currentStatsVersion = 1

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

    /// Works out `loggedSetCount` and `lastLogged` from the sets.
    func refreshStats() {
        loggedSetCount = sets.count
        lastLogged = sets.compactMap { $0.session?.start }.max()
        statsVersion = Self.currentStatsVersion
    }

    var exerciseKind: ExerciseKind {
        ExerciseKind(rawValue: kind) ?? (name.hasPrefix("Assisted ") ? .assisted : .weight)
    }

    /// Assisted pull-ups and dips: the "weight" is help from the machine, so
    /// less is stronger.
    var isAssisted: Bool { exerciseKind == .assisted }

    var primary: [Muscle] { primaryMuscles.compactMap(Muscle.init(rawValue:)) }
    var secondary: [Muscle] { secondaryMuscles.compactMap(Muscle.init(rawValue:)) }

    /// The SF Symbol used where a photo would be.
    var symbolName: String {
        switch Equipment(rawValue: equipment) {
        case .barbell, .smithMachine: "figure.strengthtraining.traditional"
        case .dumbbell, .kettlebell: "dumbbell"
        case .cable, .machine: "figure.strengthtraining.functional"
        case .bodyweight: "figure.core.training"
        case .band: "figure.flexibility"
        case .cardio: "figure.run"
        case .other, .none:
            exerciseKind == .cardio ? "figure.run" : "figure.strengthtraining.traditional"
        }
    }
}

enum ExerciseKind: String, CaseIterable {
    /// Reps at a weight.
    case weight
    /// Reps only, like a push-up.
    case bodyweight
    /// Reps with help from a machine; the weight stored is the assistance.
    case assisted
    /// Held or timed, like a plank.
    case timed
    /// Time and distance.
    case cardio
}

enum Equipment: String, CaseIterable {
    case barbell, dumbbell, kettlebell, cable, machine, smithMachine, bodyweight, band, cardio, other

    var label: String {
        switch self {
        case .smithMachine: "Smith machine"
        default: rawValue.capitalized
        }
    }
}

/// The muscles the app knows about. The raw value is what's stored.
enum Muscle: String, CaseIterable, Identifiable {
    case chest, lats, upperBack, lowerBack, traps
    case frontDelts, sideDelts, rearDelts
    case biceps, triceps, forearms
    case abs, obliques
    case quads, hamstrings, glutes, adductors, abductors, calves, hipFlexors
    case fullBody

    var id: String { rawValue }

    var label: String {
        switch self {
        case .chest: "Chest"
        case .lats: "Lats"
        case .upperBack: "Upper back"
        case .lowerBack: "Lower back"
        case .traps: "Traps"
        case .frontDelts: "Front delts"
        case .sideDelts: "Side delts"
        case .rearDelts: "Rear delts"
        case .biceps: "Biceps"
        case .triceps: "Triceps"
        case .forearms: "Forearms"
        case .abs: "Abs"
        case .obliques: "Obliques"
        case .quads: "Quads"
        case .hamstrings: "Hamstrings"
        case .glutes: "Glutes"
        case .adductors: "Adductors"
        case .abductors: "Abductors"
        case .calves: "Calves"
        case .hipFlexors: "Hip flexors"
        case .fullBody: "Full body"
        }
    }

    /// Which day of a push / pull / legs split the muscle belongs to.
    var group: MuscleGroup {
        switch self {
        case .chest, .frontDelts, .sideDelts, .triceps: .push
        case .lats, .upperBack, .lowerBack, .traps, .rearDelts, .biceps, .forearms: .pull
        case .quads, .hamstrings, .glutes, .adductors, .abductors, .calves, .hipFlexors: .legs
        case .abs, .obliques: .core
        case .fullBody: .cardio
        }
    }
}

enum MuscleGroup: String, CaseIterable, Identifiable {
    case push, pull, legs, core, cardio

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    var symbolName: String {
        switch self {
        case .push: "figure.strengthtraining.traditional"
        case .pull: "figure.climbing"
        case .legs: "figure.walk"
        case .core: "figure.core.training"
        case .cardio: "figure.run"
        }
    }
}
