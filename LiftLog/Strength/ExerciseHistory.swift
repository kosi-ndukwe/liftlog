import Foundation
import SwiftData

/// What a chart shows for an exercise. Lifts use estimated 1RM; exercises
/// without weight fall back to reps, then time, then distance.
enum ExerciseMetric: Equatable {
    case oneRepMax
    case reps
    case minutes
    case miles

    var title: String {
        switch self {
        case .oneRepMax: "Estimated 1RM"
        case .reps: "Best set (reps)"
        case .minutes: "Time"
        case .miles: "Distance"
        }
    }

    func format(_ value: Double) -> String {
        switch self {
        case .oneRepMax: value.formatted(.number.precision(.fractionLength(0))) + " lb"
        case .reps: value.formatted(.number.precision(.fractionLength(0))) + " reps"
        case .minutes: value.formatted(.number.precision(.fractionLength(0))) + " min"
        case .miles: value.formatted(.number.precision(.fractionLength(1))) + " mi"
        }
    }
}

/// One workout's worth of sets for a single exercise.
struct ExerciseSession: Identifiable {
    let session: WorkoutSession
    /// This exercise's sets in the order done.
    let sets: [SetEntry]

    var id: PersistentIdentifier { session.persistentModelID }
    var date: Date { session.start }
    var workingSets: [SetEntry] { sets.filter { !$0.isWarmup } }

    var bestOneRepMax: Double? {
        workingSets.compactMap { Strength.estimatedOneRepMax(pounds: $0.weightLb, reps: $0.reps) }.max()
    }

    var bestReps: Int { workingSets.map(\.reps).max() ?? 0 }
    var minutes: Double { sets.map(\.durationSeconds).reduce(0, +) / 60 }
    var miles: Double { sets.map(\.distanceMeters).reduce(0, +) / 1_609.344 }

    func value(for metric: ExerciseMetric) -> Double? {
        let value: Double? = switch metric {
        case .oneRepMax: bestOneRepMax
        case .reps: Double(bestReps)
        case .minutes: minutes
        case .miles: miles
        }
        return value.flatMap { $0 > 0 ? $0 : nil }
    }
}

/// Everything the exercise screen shows, worked out once from the exercise's sets.
struct ExerciseHistory {
    /// Newest first.
    let sessions: [ExerciseSession]
    let metric: ExerciseMetric
    /// Oldest first, one point per workout.
    let points: [ChartPoint]
    let trend: Strength.Trend?

    init(exercise: Exercise) {
        self.init(sets: exercise.sets)
    }

    init(sets: [SetEntry]) {
        var setsBySession: [PersistentIdentifier: (session: WorkoutSession, sets: [SetEntry])] = [:]
        for set in sets {
            guard let session = set.session else { continue }
            setsBySession[session.persistentModelID, default: (session, [])].sets.append(set)
        }
        let sessions = setsBySession.values
            .map { ExerciseSession(session: $0.session, sets: $0.sets.sorted { $0.order < $1.order }) }
            .sorted { $0.date > $1.date }
        self.sessions = sessions

        let metric: ExerciseMetric =
            if sessions.contains(where: { $0.bestOneRepMax != nil }) { .oneRepMax }
            else if sessions.contains(where: { $0.bestReps > 0 }) { .reps }
            else if sessions.contains(where: { $0.minutes > 0 }) { .minutes }
            else { .miles }
        self.metric = metric

        let points = sessions.reversed().compactMap { session in
            session.value(for: metric).map { ChartPoint(date: session.date, value: $0) }
        }
        self.points = points
        self.trend = Strength.trend(points)
    }

    var latest: ChartPoint? { points.last }
    var best: ChartPoint? { points.max { $0.value < $1.value } }
}
