import Foundation
import SwiftData

/// What a chart shows for an exercise. Lifts use estimated 1RM; exercises
/// without weight fall back to reps, then time, then distance.
enum ExerciseMetric: Equatable {
    case oneRepMax
    /// Assisted pull-ups and dips: how much help the machine gave. Less is stronger.
    case assistance
    case reps
    case minutes
    case miles

    var title: String {
        switch self {
        case .oneRepMax: "Est. 1 Rep Max"
        case .assistance: "Assistance"
        case .reps: "Best set"
        case .minutes: "Time"
        case .miles: "Distance"
        }
    }

    /// The unit shown small beside a big number.
    var unit: String {
        switch self {
        case .oneRepMax: "lb in 1 rep"
        case .assistance: "lb of help · less is stronger"
        case .reps: "reps in 1 set"
        case .minutes: "min"
        case .miles: "mi"
        }
    }

    /// For assistance a smaller number is the better one.
    var lowerIsBetter: Bool { self == .assistance }

    func format(_ value: Double) -> String {
        formatNumber(value) + " " + shortUnit
    }

    func formatNumber(_ value: Double) -> String {
        switch self {
        case .oneRepMax, .assistance: value.formatted(.number.precision(.fractionLength(0...1)))
        case .reps, .minutes: value.formatted(.number.precision(.fractionLength(0)))
        case .miles: value.formatted(.number.precision(.fractionLength(1)))
        }
    }

    var shortUnit: String {
        switch self {
        case .oneRepMax, .assistance: "lb"
        case .reps: "reps"
        case .minutes: "min"
        case .miles: "mi"
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
        workingSets.filter { !$0.isAssisted }
            .compactMap { Strength.estimatedOneRepMax(pounds: $0.weightLb, reps: $0.reps) }.max()
    }

    /// The least help used in a working set, for assisted exercises.
    var leastAssistance: Double? {
        workingSets.filter { $0.isAssisted && $0.reps > 0 }.map(\.weightLb).min()
    }

    /// The heaviest working set.
    var topWeight: Double? {
        workingSets.filter { !$0.isAssisted && $0.weightLb > 0 }.map(\.weightLb).max()
    }

    /// reps × weight over every set, in lb.
    var volumeLb: Double { sets.map(\.volumeLb).reduce(0, +) }

    var bestReps: Int { workingSets.map(\.reps).max() ?? 0 }
    var minutes: Double { sets.map(\.durationSeconds).reduce(0, +) / 60 }
    var miles: Double { sets.map(\.distanceMeters).reduce(0, +) / 1_609.344 }

    func value(for metric: ExerciseMetric) -> Double? {
        let value: Double? = switch metric {
        case .oneRepMax: bestOneRepMax
        case .assistance: leastAssistance
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
            else if sessions.contains(where: { $0.leastAssistance != nil }) { .assistance }
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
    /// The personal record: the biggest value, or the smallest for assistance.
    var best: ChartPoint? {
        metric.lowerIsBetter ? points.min { $0.value < $1.value } : points.max { $0.value < $1.value }
    }

    /// The mean of every point.
    var average: Double? {
        points.isEmpty ? nil : points.map(\.value).reduce(0, +) / Double(points.count)
    }
}
