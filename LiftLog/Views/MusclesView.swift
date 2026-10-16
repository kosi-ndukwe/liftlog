import SwiftData
import SwiftUI

/// Which muscles you've trained lately, shaded on a body diagram, with the
/// sets per muscle underneath. Describes the past only.
struct MusclesView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var period = Period.week
    @State private var load: MuscleLoad?
    @State private var workoutCount = 0

    enum Period: CaseIterable {
        case week, month, sixMonths

        var label: String {
            switch self {
            case .week: "Week"
            case .month: "Month"
            case .sixMonths: "6 Months"
            }
        }

        var days: Int {
            switch self {
            case .week: 7
            case .month: 30
            case .sixMonths: 182
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SegmentedPill(options: Period.allCases, selection: $period) { $0.label }
                    .padding(.top, 4)

                if let load {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Palette.textSecondary)

                    BodyPair(shading: load.shading)
                        .frame(height: 300)
                        .frame(maxWidth: .infinity)
                        .card()

                    let groups = load.byGroup
                    StatStrip([
                        StatTile(label: "Push", value: formattedWhole(groups[.push] ?? 0), unit: "sets"),
                        StatTile(label: "Pull", value: formattedWhole(groups[.pull] ?? 0), unit: "sets"),
                        StatTile(label: "Legs", value: formattedWhole(groups[.legs] ?? 0), unit: "sets"),
                        StatTile(label: "Core", value: formattedWhole(groups[.core] ?? 0), unit: "sets"),
                    ])
                    .card()

                    if load.isEmpty {
                        ContentUnavailableView("No Workouts", systemImage: "figure.strengthtraining.traditional", description: Text("Nothing logged in the last \(period.days) days."))
                            .card()
                    } else {
                        Text("Sets by Muscle")
                            .font(.sectionTitle)
                            .foregroundStyle(Palette.textPrimary)
                            .padding(.top, 8)
                        let top = load.ranked.first?.sets ?? 1
                        VStack(spacing: 14) {
                            ForEach(load.ranked, id: \.muscle) { entry in
                                MuscleBar(muscle: entry.muscle, sets: entry.sets, fraction: entry.sets / top)
                            }
                        }
                        .card()
                        Text("A working set counts once for each muscle the exercise mainly works and half for each one it also works. Warm-ups don't count.")
                            .font(.caption)
                            .foregroundStyle(Palette.textSecondary)
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
        .navigationTitle("Muscles")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: period) { reload() }
    }

    private var subtitle: String {
        let start = Calendar.current.date(byAdding: .day, value: -period.days, to: .now) ?? .now
        let range = start.formatted(.dateTime.month().day()) + " – " + Date.now.formatted(.dateTime.month().day())
        return "\(workoutCount) workouts · \(range)"
    }

    private func reload() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -period.days, to: .now) ?? .now
        let sessions = (try? modelContext.fetch(FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.start >= cutoff && $0.end != nil }
        ))) ?? []
        workoutCount = sessions.count
        load = MuscleLoad(sessions: sessions)
    }
}

/// A muscle's name, a bar for how much it was trained, and the set count.
private struct MuscleBar: View {
    let muscle: Muscle
    let sets: Double
    let fraction: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(muscle.label)
                    .font(.bodyText)
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                Text(sets.formatted(.number.precision(.fractionLength(0...1))) + " sets")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Palette.textSecondary)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.cardRaised)
                    Capsule().fill(Palette.accent).frame(width: max(6, geometry.size.width * fraction))
                }
            }
            .frame(height: 6)
        }
    }
}

/// The card on the Log tab that leads to `MusclesView`: this week's muscles.
struct MusclesCard: View {
    let sessions: [WorkoutSession]

    var body: some View {
        let load = MuscleLoad(sessions: sessions)
        HStack(spacing: 16) {
            BodyPair(shading: load.shading)
                .frame(height: 110)
            VStack(alignment: .leading, spacing: 6) {
                Text("Muscles")
                    .font(.rowTitle)
                    .foregroundStyle(Palette.textPrimary)
                Text(load.isEmpty ? "Nothing trained yet this week" : "This week: " + load.ranked.prefix(3).map(\.muscle.label).joined(separator: ", ").lowercased())
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.textMuted)
        }
        .card()
    }
}

#Preview {
    NavigationStack {
        MusclesView()
    }
    .modelContainer(PreviewData.container)
    .preferredColorScheme(.dark)
}
