import SwiftData
import SwiftUI

/// One workout: a big header, then each exercise in order with its sets.
/// Tap an exercise for its chart.
struct WorkoutDetailView: View {
    let session: WorkoutSession
    /// Exercises where this workout set a new best, with the value.
    @State private var records: [PersistentIdentifier: String] = [:]
    @State private var checkedRecords = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                let groups = groupedSets
                Text("\(groups.count) Exercises")
                    .font(.sectionTitle)
                    .foregroundStyle(Palette.textPrimary)
                ForEach(groups, id: \.exercise.persistentModelID) { group in
                    exerciseBlock(group)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .screenBackground()
        .navigationTitle(session.start.formatted(.dateTime.month().day().year().hour().minute()))
        .navigationBarTitleDisplayMode(.inline)
        .task { await findRecords() }
    }

    private var header: some View {
        VStack(spacing: 10) {
            let groups = muscleGroups
            if !groups.isEmpty {
                HStack(spacing: 8) {
                    ForEach(groups) { group in
                        MuscleGroupBadge(group: group, size: 48)
                    }
                }
            }
            Text(session.title)
                .font(.heroTitle)
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.bodyText)
                .foregroundStyle(Palette.textSecondary)
            StatStrip([
                StatTile(label: "Sets", value: "\(session.setCount)"),
                StatTile(label: "Volume", value: formattedWhole(session.volumeLb), unit: "lb"),
                StatTile(label: "Records", value: checkedRecords ? "\(records.count)" : "…"),
            ])
            .padding(.top, 8)
            if let average = session.averageHeartRate {
                Text("♥ \(Int(average)) bpm average" + (session.peakHeartRate.map { ", \(Int($0)) peak" } ?? ""))
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    private var subtitle: String {
        var parts = [session.start.formatted(.dateTime.weekday(.wide).month().day().year())]
        if let duration = session.duration, duration > 0 { parts.append(formattedDuration(duration)) }
        return parts.joined(separator: " · ")
    }

    private func exerciseBlock(_ group: (exercise: Exercise, sets: [SetEntry])) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink(value: group.exercise) {
                HStack(alignment: .top, spacing: 14) {
                    ExerciseThumbnail(exercise: group.exercise)
                        .overlay(alignment: .bottomTrailing) {
                            HexBadge(systemImage: "checkmark", fill: Palette.done, foreground: Palette.background, size: 24)
                                .offset(x: 6, y: 6)
                        }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.exercise.name)
                            .font(.rowTitle)
                            .foregroundStyle(Palette.textPrimary)
                            .multilineTextAlignment(.leading)
                        ForEach(group.sets) { set in
                            SetLine(text: set.summary, isWarmup: set.isWarmup)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            if let record = records[group.exercise.persistentModelID] {
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(Palette.record)
                    Text(group.exercise.isAssisted ? "Least assistance" : "Est. 1 Rep Max")
                        .font(.bodyText)
                        .foregroundStyle(Palette.textPrimary)
                    Spacer()
                    Text(record)
                        .font(.bodyText)
                        .monospacedDigit()
                        .foregroundStyle(Palette.textPrimary)
                }
                .card(fill: Palette.cardRaised, padding: 14)
                .padding(.leading, 70)
            }
        }
    }

    /// Sets grouped by exercise, in the order the exercises were done.
    private var groupedSets: [(exercise: Exercise, sets: [SetEntry])] {
        let ordered = session.orderedSets
        return session.exercisesInOrder.map { exercise in
            (exercise, ordered.filter { $0.exercise == exercise })
        }
    }

    /// Push / pull / legs / core, in the order they first appear.
    private var muscleGroups: [MuscleGroup] {
        var seen = Set<MuscleGroup>()
        return session.exercisesInOrder
            .flatMap { $0.primary.map(\.group) }
            .filter { seen.insert($0).inserted }
    }

    /// An exercise's best-ever value that was set in this workout. Worked out
    /// after the screen appears because it reads every set of each exercise.
    private func findRecords() async {
        guard !checkedRecords else { return }
        var found: [PersistentIdentifier: String] = [:]
        for exercise in session.exercisesInOrder {
            let history = ExerciseHistory(exercise: exercise)
            guard history.metric == .oneRepMax || history.metric == .assistance,
                  let best = history.best, best.date == session.start
            else { continue }
            found[exercise.persistentModelID] = history.metric.format(best.value)
            await Task.yield()
        }
        records = found
        checkedRecords = true
    }
}

#Preview {
    NavigationStack {
        WorkoutDetailView(session: try! PreviewData.container.mainContext.fetch(FetchDescriptor<WorkoutSession>()).first!)
    }
    .modelContainer(PreviewData.container)
    .preferredColorScheme(.dark)
}
