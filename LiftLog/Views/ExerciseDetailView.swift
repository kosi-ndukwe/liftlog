import Charts
import SwiftData
import SwiftUI

/// One exercise: strength summary, chart over time, then every workout it was in.
struct ExerciseDetailView: View {
    let exercise: Exercise
    @State private var history: ExerciseHistory?
    @State private var range = ChartRange.year

    var body: some View {
        List {
            if let history {
                if history.points.isEmpty {
                    ContentUnavailableView("No Data Yet", systemImage: "chart.xyaxis.line")
                } else {
                    summarySection(history)
                    chartSection(history)
                }
                historySection(history)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Worked out once when the screen opens; an exercise can have thousands of sets.
            if history == nil { history = ExerciseHistory(exercise: exercise) }
        }
    }

    private func summarySection(_ history: ExerciseHistory) -> some View {
        let metric = history.metric
        return Section {
            if let latest = history.latest {
                LabeledContent("Latest", value: metric.format(latest.value))
            }
            if let best = history.best {
                LabeledContent("Best") {
                    Text("\(metric.format(best.value)) · \(best.date.formatted(.dateTime.month().year()))")
                }
            }
            if let trend = history.trend {
                LabeledContent("Trend", value: Self.formatChange(trend.perMonth, metric: metric) + " / month")
                LabeledContent("At this rate by \(trend.projectedDate.formatted(.dateTime.month().day()))") {
                    Text("≈ \(metric.format(trend.projectedValue))")
                }
            } else {
                Text("Not enough workouts in the last 6 months for a trend.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(metric.title)
        } footer: {
            if metric == .oneRepMax {
                Text("Estimated from your best working set of 1–12 reps in each workout. The trend is a straight line through the last 6 months, extended 3 months ahead.")
            }
        }
    }

    private func chartSection(_ history: ExerciseHistory) -> some View {
        let visible = history.points.filter { range.includes($0.date, newest: history.latest?.date) }
        let metric = history.metric
        return Section {
            Picker("Range", selection: $range) {
                ForEach(ChartRange.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            Chart {
                ForEach(visible) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value(metric.title, point.value),
                        series: .value("Series", "History")
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Color.accentColor)
                }
                if let trend = history.trend {
                    ForEach([(trend.startDate, trend.startValue), (trend.projectedDate, trend.projectedValue)], id: \.0) { date, value in
                        LineMark(x: .value("Date", date), y: .value(metric.title, value), series: .value("Series", "Trend"))
                            .foregroundStyle(Color.secondary)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
                    }
                }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 220)
            .padding(.vertical, 8)
        }
    }

    private func historySection(_ history: ExerciseHistory) -> some View {
        Section("Workouts (\(history.sessions.count))") {
            ForEach(history.sessions) { entry in
                NavigationLink(value: entry.session) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.date, format: .dateTime.day().month().year())
                                .font(.headline)
                            Spacer()
                            if let value = entry.value(for: history.metric) {
                                Text(history.metric.format(value))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(entry.sets.map { $0.isWarmup ? "(\($0.summary))" : $0.summary }.joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    static func formatChange(_ value: Double, metric: ExerciseMetric) -> String {
        let sign = value >= 0 ? "+" : "−"
        let amount = abs(value).formatted(.number.precision(.fractionLength(metric == .miles ? 1...1 : 0...1)))
        let unit = switch metric {
        case .oneRepMax: " lb"
        case .reps: " reps"
        case .minutes: " min"
        case .miles: " mi"
        }
        return sign + amount + unit
    }
}

enum ChartRange: String, CaseIterable, Identifiable {
    case threeMonths, year, all

    var id: Self { self }

    var label: String {
        switch self {
        case .threeMonths: "3M"
        case .year: "1Y"
        case .all: "All"
        }
    }

    /// Ranges count back from the newest workout, so old exercises still show something.
    func includes(_ date: Date, newest: Date?) -> Bool {
        guard let newest else { return true }
        return switch self {
        case .threeMonths: date >= newest.addingTimeInterval(-91 * 86_400)
        case .year: date >= newest.addingTimeInterval(-365 * 86_400)
        case .all: true
        }
    }
}

#Preview {
    NavigationStack {
        ExerciseDetailView(exercise: try! PreviewData.container.mainContext.fetch(FetchDescriptor<Exercise>()).first { $0.name == "Barbell Bench Press" }!)
    }
    .modelContainer(PreviewData.container)
}
