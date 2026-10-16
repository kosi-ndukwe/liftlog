import Charts
import SwiftUI

/// The full chart for one measurement, over a week, month, 6 months or year,
/// with the personal record marked and the 6-month trend extended ahead.
struct ExerciseChartView: View {
    let exercise: Exercise
    let history: ExerciseHistory
    let metric: ExerciseMetric
    @State private var range = ChartRange.month

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SegmentedPill(options: ChartRange.allCases, selection: $range) { $0.label }

                HStack(spacing: 8) {
                    Text(metric.title)
                        .statLabelStyle()
                        .foregroundStyle(Palette.textPrimary)
                    RoundedRectangle(cornerRadius: 3).fill(Palette.accent).frame(width: 12, height: 12)
                }
                BigStat(value: rangeSummary, unit: metric.unit, footnote: rangeDates)

                chart
                    .frame(height: 260)

                if let best = history.best {
                    HStack {
                        Text("Personal Record")
                            .font(.rowTitle)
                        Spacer()
                        Text(metric.format(best.value))
                            .font(.rowTitle)
                            .monospacedDigit()
                    }
                    .foregroundStyle(Palette.textOnRecord)
                    .card(fill: Palette.recordFill)
                }
                if let average = history.average {
                    HStack {
                        Text("Your Average")
                            .font(.rowTitle)
                        Spacer()
                        Text(metric.format(average))
                            .font(.rowTitle)
                            .monospacedDigit()
                    }
                    .foregroundStyle(Palette.textPrimary)
                    .card()
                }
                if let trend = history.trend, metric == history.metric {
                    HStack {
                        Text("Trend")
                            .font(.rowTitle)
                        Spacer()
                        Text(ExerciseDetailView.formatChange(trend.perMonth, metric: metric) + " / month")
                            .font(.rowTitle)
                            .monospacedDigit()
                    }
                    .foregroundStyle(Palette.textPrimary)
                    .card()
                    Text("A straight line through the last 6 months, extended 3 months ahead (dashed). At this rate you'd be at \(metric.format(trend.projectedValue)) by \(trend.projectedDate.formatted(.dateTime.month().day())).")
                        .font(.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
                if metric == .oneRepMax {
                    Text("Estimated One Rep Max")
                        .font(.subsectionTitle)
                        .foregroundStyle(Palette.textPrimary)
                        .padding(.top, 8)
                    Text("An estimate of the most you could lift once, worked out from your best working set of 1–12 reps in each workout (Epley: weight × (1 + reps ÷ 30)). It describes what you've already done; it never suggests what to lift.")
                        .font(.bodyText)
                        .foregroundStyle(Palette.textSecondary)
                }
                if metric == .assistance {
                    Text("Assistance")
                        .font(.subsectionTitle)
                        .foregroundStyle(Palette.textPrimary)
                        .padding(.top, 8)
                    Text("For assisted pull-ups and dips the weight you choose is how much the machine helps, so a smaller number means you did more of the work yourself.")
                        .font(.bodyText)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .screenBackground()
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var points: [ChartPoint] {
        metric == history.metric ? history.points : history.points(for: { $0.value(for: metric) })
    }

    private var visible: [ChartPoint] {
        points.filter { range.includes($0.date, newest: history.latest?.date) }
    }

    /// "71.0–79.4" over the range, or the single value.
    private var rangeSummary: String {
        let values = visible.map(\.value)
        guard let low = values.min(), let high = values.max() else { return "—" }
        return low == high ? metric.formatNumber(low) : metric.formatNumber(low) + "–" + metric.formatNumber(high)
    }

    private var rangeDates: String? {
        guard let newest = history.latest?.date else { return nil }
        let oldest = range.start(newest: newest) ?? points.first?.date ?? newest
        return oldest.formatted(.dateTime.month().day()) + " – " + newest.formatted(.dateTime.month().day())
    }

    /// The whole range, even when only one workout falls in it.
    private var xDomain: ClosedRange<Date> {
        let newest = history.latest?.date ?? .now
        let start = range.start(newest: newest) ?? newest
        let end = (metric == history.metric && range != .week) ? (history.trend?.projectedDate ?? newest) : newest
        return start...max(end, newest.addingTimeInterval(86_400))
    }

    private var chart: some View {
        let showTrend = metric == history.metric
        return Chart {
            ForEach(visible) { point in
                LineMark(x: .value("Date", point.date), y: .value(metric.title, point.value), series: .value("Series", "History"))
                    .foregroundStyle(Palette.accent)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    .interpolationMethod(.linear)
                PointMark(x: .value("Date", point.date), y: .value(metric.title, point.value))
                    .foregroundStyle(history.best?.date == point.date ? Palette.record : Palette.accent)
                    .symbolSize(90)
            }
            if let best = history.best {
                RuleMark(y: .value("PR", best.value))
                    .foregroundStyle(Palette.record)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [3, 4]))
            }
            if showTrend, let trend = history.trend, range != .week {
                ForEach([(trend.startDate, trend.startValue), (trend.projectedDate, trend.projectedValue)], id: \.0) { date, value in
                    LineMark(x: .value("Date", date), y: .value(metric.title, value), series: .value("Series", "Trend"))
                        .foregroundStyle(Palette.textMuted)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
                }
            }
        }
        .chartXScale(domain: xDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine().foregroundStyle(Palette.hairline)
                AxisValueLabel().foregroundStyle(Palette.textSecondary).font(.caption)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine().foregroundStyle(Palette.hairline)
                AxisValueLabel().foregroundStyle(Palette.textSecondary).font(.caption)
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
    }
}

enum ChartRange: String, CaseIterable, Identifiable {
    case week, month, sixMonths, year

    var id: Self { self }

    var label: String {
        switch self {
        case .week: "Week"
        case .month: "Month"
        case .sixMonths: "6 Months"
        case .year: "Year"
        }
    }

    private var days: Double {
        switch self {
        case .week: 7
        case .month: 30
        case .sixMonths: 182
        case .year: 365
        }
    }

    /// Ranges count back from the newest workout, so old exercises still show something.
    func start(newest: Date) -> Date? {
        newest.addingTimeInterval(-days * 86_400)
    }

    func includes(_ date: Date, newest: Date?) -> Bool {
        guard let newest, let start = start(newest: newest) else { return true }
        return date >= start
    }
}
