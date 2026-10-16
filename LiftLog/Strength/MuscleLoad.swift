import Foundation

/// How much each muscle was trained over some sets: working sets count 1 for
/// each primary muscle and ½ for each secondary one. Warm-ups don't count.
struct MuscleLoad {
    /// Sets per muscle.
    private(set) var sets: [Muscle: Double] = [:]

    static let secondaryWeight = 0.5

    init(sets entries: [SetEntry]) {
        for set in entries where !set.isWarmup {
            guard let exercise = set.exercise else { continue }
            for muscle in exercise.primary { sets[muscle, default: 0] += 1 }
            for muscle in exercise.secondary { sets[muscle, default: 0] += Self.secondaryWeight }
        }
    }

    init(sessions: [WorkoutSession]) {
        self.init(sets: sessions.flatMap(\.sets))
    }

    var isEmpty: Bool { sets.isEmpty }

    /// Each muscle's share of the most-trained muscle, 0…1, for shading.
    var shading: [Muscle: Double] {
        guard let top = sets.values.max(), top > 0 else { return [:] }
        return sets.mapValues { $0 / top }
    }

    /// Muscles from most to least trained.
    var ranked: [(muscle: Muscle, sets: Double)] {
        sets.map { ($0.key, $0.value) }.sorted { $0.1 == $1.1 ? $0.0.label < $1.0.label : $0.1 > $1.1 }
    }

    /// Sets per push / pull / legs / core group.
    var byGroup: [MuscleGroup: Double] {
        var groups: [MuscleGroup: Double] = [:]
        for (muscle, count) in sets { groups[muscle.group, default: 0] += count }
        return groups
    }
}
