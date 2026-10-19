import Charts
import SwiftData
import SwiftUI

/// One exercise. Results: every workout's sets, newest first. Trends: a card
/// per measurement with a small chart; tap one for the full chart.
struct ExerciseDetailView: View {
    let exercise: Exercise
    @State private var history: ExerciseHistory?
    @State private var tab = Tab.results
    @State private var shownSessions = 20

    enum Tab: CaseIterable { case results, trends }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !exercise.primary.isEmpty {
                    musclesCard
                }
                if !exercise.imageNames.isEmpty || !exercise.instructions.isEmpty {
                    HowToCard(exercise: exercise)
                }
                SegmentedPill(options: Tab.allCases, selection: $tab) { $0 == .results ? "Results" : "Trends" }
                    .padding(.top, 4)

                if let history {
                    if history.sessions.isEmpty {
                        ContentUnavailableView("Not Logged Yet", systemImage: "chart.xyaxis.line", description: Text(exercise.primary.map(\.label).joined(separator: ", ")))
                            .card()
                    } else {
                        switch tab {
                        case .results: results(history)
                        case .trends: trends(history)
                        }
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .screenBackground()
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: ChartRoute.self) { route in
            if let history { ExerciseChartView(exercise: exercise, history: history, metric: route.metric) }
        }
        .task {
            // Worked out once when the screen opens; an exercise can have thousands of sets.
            if history == nil { history = ExerciseHistory(exercise: exercise) }
        }
    }

    /// Front and back with this exercise's muscles lit up, and their names.
    private var musclesCard: some View {
        let shading = Dictionary(uniqueKeysWithValues: exercise.primary.map { ($0, 1.0) })
            .merging(exercise.secondary.map { ($0, 0.4) }, uniquingKeysWith: max)
        return HStack(spacing: 16) {
            BodyPair(shading: shading)
                .frame(height: 120)
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Works").statLabelStyle()
                    Text(exercise.primary.map(\.label).joined(separator: ", "))
                        .font(.bodyText)
                        .foregroundStyle(Palette.textPrimary)
                }
                if !exercise.secondary.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Also").statLabelStyle()
                        Text(exercise.secondary.map(\.label).joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                if let equipment = Equipment(rawValue: exercise.equipment), equipment != .other {
                    Text(equipment.label)
                        .font(.caption)
                        .foregroundStyle(Palette.textMuted)
                }
            }
            Spacer(minLength: 0)
        }
        .card()
        .padding(.top, 4)
    }

    // MARK: Results

    @ViewBuilder
    private func results(_ history: ExerciseHistory) -> some View {
        ForEach(history.sessions.prefix(shownSessions)) { entry in
            VStack(alignment: .leading, spacing: 12) {
                NavigationLink(value: entry.session) {
                    HStack {
                        Text(DateHeading.text(for: entry.date))
                            .font(.subsectionTitle)
                            .foregroundStyle(Palette.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Palette.textMuted)
                    }
                }
                .buttonStyle(.plain)

                let warmups = entry.sets.filter(\.isWarmup)
                if !warmups.isEmpty {
                    ForEach(warmups) { set in
                        SetLine(text: set.summary, isWarmup: true)
                    }
                }
                Text("Working sets")
                    .font(.bodyText)
                    .foregroundStyle(Palette.textSecondary)
                ForEach(Array(entry.workingSets.enumerated()), id: \.element.id) { index, set in
                    SetLine(text: set.summary, number: index + 1)
                }
                if let value = entry.value(for: history.metric), history.metric != .reps {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(history.metric.title)
                            .font(.bodyText)
                            .foregroundStyle(Palette.textSecondary)
                        HStack(spacing: 10) {
                            Image(systemName: history.metric == .assistance ? "arrow.down.right" : "chart.line.uptrend.xyaxis")
                                .foregroundStyle(Palette.textSecondary)
                            Text(history.metric.formatNumber(value) + " " + history.metric.shortUnit)
                                .font(.rowTitle)
                                .monospacedDigit()
                                .foregroundStyle(Palette.textPrimary)
                            if history.best?.date == entry.date {
                                Tag(text: "PR", fill: Palette.recordFill, foreground: Palette.textOnRecord)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
        if history.sessions.count > shownSessions {
            Button("Show \(min(50, history.sessions.count - shownSessions)) more") {
                shownSessions += 50
            }
            .buttonStyle(PillButtonStyle(fill: Palette.cardRaised))
        }
    }

    // MARK: Trends

    @ViewBuilder
    private func trends(_ history: ExerciseHistory) -> some View {
        let metric = history.metric
        if let latest = history.latest {
            NavigationLink(value: ChartRoute(metric: metric)) {
                MetricCard(
                    title: metric.title,
                    value: metric.formatNumber(latest.value),
                    unit: metric.unit,
                    logged: latest.date,
                    points: history.points
                )
            }
            .buttonStyle(.plain)
        }
        if metric == .oneRepMax || metric == .assistance {
            let weights = history.points(for: \.topWeight)
            if let latest = weights.last {
                MetricCard(title: "Weight", value: ExerciseMetric.oneRepMax.formatNumber(latest.value), unit: "lb in 1 set", logged: latest.date, points: weights)
            }
        }
        if metric != .minutes && metric != .miles {
            let volume = history.points(for: { $0.volumeLb > 0 ? $0.volumeLb : nil })
            if let latest = volume.last {
                MetricCard(title: "Volume", value: formattedWhole(latest.value), unit: "lb", logged: latest.date, points: volume, style: .bars)
            }
            let reps = history.points(for: { $0.bestReps > 0 ? Double($0.bestReps) : nil })
            if let latest = reps.last, metric != .reps {
                MetricCard(title: "Reps", value: "\(Int(latest.value))", unit: "reps in 1 set", logged: latest.date, points: reps)
            }
        }
        if metric == .minutes {
            let miles = history.points(for: { $0.miles > 0 ? $0.miles : nil })
            if let latest = miles.last {
                MetricCard(title: "Distance", value: ExerciseMetric.miles.formatNumber(latest.value), unit: "mi", logged: latest.date, points: miles)
            }
        }
    }

    /// "+5 lb", "−0.4 reps".
    static func formatChange(_ value: Double, metric: ExerciseMetric) -> String {
        let sign = value >= 0 ? "+" : "−"
        let amount = abs(value).formatted(.number.precision(.fractionLength(metric == .miles ? 1...1 : 0...1)))
        return sign + amount + " " + metric.shortUnit
    }
}

struct ChartRoute: Hashable {
    let metric: ExerciseMetric
}

extension ExerciseMetric: Hashable {}

extension ExerciseHistory {
    /// One point per workout for any per-workout number, oldest first.
    func points(for value: (ExerciseSession) -> Double?) -> [ChartPoint] {
        sessions.reversed().compactMap { session in
            value(session).map { ChartPoint(date: session.date, value: $0) }
        }
    }
}

#Preview {
    NavigationStack {
        ExerciseDetailView(exercise: try! PreviewData.container.mainContext.fetch(FetchDescriptor<Exercise>()).first { $0.name == "Barbell Bench Press" }!)
    }
    .modelContainer(PreviewData.container)
    .preferredColorScheme(.dark)
}
