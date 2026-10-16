import Charts
import SwiftUI

/// A card for one measurement: its name, the latest value in big type, when
/// it was logged, and a small chart of the most recent workouts.
struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let logged: Date?
    /// Oldest first. Only the last `pointLimit` are drawn.
    let points: [ChartPoint]
    var style: ChartStyle = .line
    var pointLimit = 10

    enum ChartStyle { case line, bars }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.rowTitle)
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.textMuted)
            }
            BigStat(value: value, unit: unit, footnote: logged.map { "Logged " + $0.formatted(.dateTime.month().day().year()) })
            MiniChart(points: Array(points.suffix(pointLimit)), style: style)
                .frame(height: 150)
            Text("Most Recent Performances")
                .font(.caption)
                .foregroundStyle(Palette.textMuted)
                .frame(maxWidth: .infinity)
        }
        .card()
    }
}

/// The chart inside a `MetricCard`: evenly spaced workouts along the bottom,
/// values up the side, axis labels on the right.
struct MiniChart: View {
    let points: [ChartPoint]
    var style: MetricCard.ChartStyle

    var body: some View {
        Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                switch style {
                case .line:
                    LineMark(x: .value("Workout", index), y: .value("Value", point.value))
                        .foregroundStyle(Palette.accent)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                    PointMark(x: .value("Workout", index), y: .value("Value", point.value))
                        .foregroundStyle(Palette.accent)
                        .symbolSize(90)
                case .bars:
                    BarMark(x: .value("Workout", index), y: .value("Value", point.value), width: .ratio(0.7))
                        .foregroundStyle(Palette.accent)
                        .cornerRadius(2)
                }
            }
        }
        .chartXAxis(.hidden)
        .chartXScale(domain: -0.5...(Double(max(points.count, 1)) - 0.5))
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine().foregroundStyle(Palette.hairline)
                AxisValueLabel().foregroundStyle(Palette.textSecondary).font(.caption)
            }
        }
        .chartYScale(domain: .automatic(includesZero: style == .bars))
    }
}

/// How a workout's date reads as a heading: "Today", "Yesterday", "Monday, Oct 12".
enum DateHeading {
    static func text(for date: Date, relativeTo now: Date = .now, calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        return sameYear
            ? date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
            : date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
    }

    /// "THU, OCTOBER 15" for the timeline.
    static func timelineText(for date: Date, relativeTo now: Date = .now, calendar: Calendar = .current) -> String {
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        return sameYear
            ? date.formatted(.dateTime.weekday(.abbreviated).month(.wide).day())
            : date.formatted(.dateTime.weekday(.abbreviated).month(.wide).day().year())
    }
}

/// "1h 10m" or "54m".
func formattedDuration(_ seconds: TimeInterval) -> String {
    let minutes = Int(seconds / 60)
    return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
}

/// "30,710" with no decimals, for volume.
func formattedWhole(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0)))
}
