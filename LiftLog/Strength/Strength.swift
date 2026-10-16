import Foundation

/// Strength estimates. These describe your own history; they never suggest what to lift.
enum Strength {
    /// Above this many reps the estimate gets unreliable, so those sets are left out.
    static let maximumRepsForEstimate = 12

    /// Estimated one-rep max using the Epley formula: weight × (1 + reps ÷ 30).
    /// For example, 185 lb × 8 reps ≈ 234 lb.
    static func estimatedOneRepMax(pounds: Double, reps: Int) -> Double? {
        guard pounds > 0, (1...maximumRepsForEstimate).contains(reps) else { return nil }
        return reps == 1 ? pounds : pounds * (1 + Double(reps) / 30)
    }

    /// Fits a straight line through recent points and extends it forward.
    ///
    /// Uses points from the last `windowDays` before the newest point. Needs at
    /// least `minimumPoints` spread over at least four weeks, otherwise there
    /// isn't enough to go on and it returns nil.
    static func trend(
        _ points: [ChartPoint],
        windowDays: Double = 180,
        horizonDays: Double = 90,
        minimumPoints: Int = 4
    ) -> Trend? {
        guard let newest = points.map(\.date).max() else { return nil }
        let recent = points.filter { $0.date >= newest.addingTimeInterval(-windowDays * 86_400) }
        guard recent.count >= minimumPoints,
              let oldest = recent.map(\.date).min(),
              newest.timeIntervalSince(oldest) >= 28 * 86_400
        else { return nil }

        // Least-squares line: value = intercept + slope × days.
        let xs = recent.map { $0.date.timeIntervalSince(oldest) / 86_400 }
        let ys = recent.map(\.value)
        let meanX = xs.reduce(0, +) / Double(xs.count)
        let meanY = ys.reduce(0, +) / Double(ys.count)
        let spread = xs.map { ($0 - meanX) * ($0 - meanX) }.reduce(0, +)
        guard spread > 0 else { return nil }
        let slope = zip(xs, ys).map { ($0 - meanX) * ($1 - meanY) }.reduce(0, +) / spread
        let intercept = meanY - slope * meanX

        let newestX = newest.timeIntervalSince(oldest) / 86_400
        return Trend(
            perMonth: slope * 30.44,
            startDate: newest,
            startValue: intercept + slope * newestX,
            projectedDate: newest.addingTimeInterval(horizonDays * 86_400),
            projectedValue: max(0, intercept + slope * (newestX + horizonDays))
        )
    }

    struct Trend: Equatable {
        /// How much the value changes per month along the trend line.
        var perMonth: Double
        /// Where the trend line is at the newest point.
        var startDate: Date
        var startValue: Double
        /// Where the trend line would be `horizonDays` later if it carried on.
        var projectedDate: Date
        var projectedValue: Double
    }
}

struct ChartPoint: Equatable, Identifiable {
    var date: Date
    var value: Double
    var id: Date { date }
}
