import Foundation
import SwiftData

/// One set of one exercise. Matches a row of the Fitbod export.
@Model
final class SetEntry {
    /// Position within the session.
    var order: Int
    var reps: Int
    /// Stored in kg, like Fitbod, to keep full precision. Use `weightLb` for display.
    var weightKg: Double
    var durationSeconds: Double
    var distanceMeters: Double
    var isWarmup: Bool
    var note: String
    /// Fitbod's multiplier column, kept as stored. 2.0 seems to mean the
    /// weight is per side or per dumbbell.
    var multiplier: Double

    var session: WorkoutSession?
    var exercise: Exercise?

    init(
        order: Int,
        exercise: Exercise?,
        reps: Int = 0,
        weightKg: Double = 0,
        durationSeconds: Double = 0,
        distanceMeters: Double = 0,
        isWarmup: Bool = false,
        note: String = "",
        multiplier: Double = 1
    ) {
        self.order = order
        self.exercise = exercise
        self.reps = reps
        self.weightKg = weightKg
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.isWarmup = isWarmup
        self.note = note
        self.multiplier = multiplier
    }

    /// The weight in lb, rounded to the nearest 0.5 lb. Setting it stores kg.
    var weightLb: Double {
        get { Weight.roundedToHalfPound(Weight.pounds(fromKg: weightKg)) }
        set { weightKg = Weight.kg(fromPounds: newValue) }
    }

    /// True for assisted pull-ups and dips, where the weight is the machine's help.
    var isAssisted: Bool {
        exercise?.isAssisted ?? (multiplier == 0 && weightKg > 0)
    }

    /// reps × weight × multiplier in lb, the way Fitbod counts volume. Per-side
    /// weights (multiplier 2 or 4) count every side; assisted sets count nothing.
    var volumeLb: Double {
        guard reps > 0, weightKg > 0, !isAssisted else { return 0 }
        return Double(reps) * Weight.pounds(fromKg: weightKg) * max(multiplier, 1)
    }

    /// "8 reps x 135 lb", "8 reps x 45 lb assist", "15 reps", or "30 min · 5.0 mi" for cardio.
    var summary: String {
        if weightKg > 0 && reps > 0 {
            let line = "\(reps) reps x \(Weight.formattedPounds(fromKg: weightKg))"
            return isAssisted ? line + " assist" : line
        }
        if reps > 0 {
            return "\(reps) reps"
        }
        var parts: [String] = []
        if durationSeconds > 0 {
            parts.append(durationSeconds < 60
                ? "\(Int(durationSeconds)) s"
                : (durationSeconds / 60).formatted(.number.precision(.fractionLength(0))) + " min")
        }
        if distanceMeters > 0 {
            parts.append((distanceMeters / 1_609.344).formatted(.number.precision(.fractionLength(1))) + " mi")
        }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }
}
