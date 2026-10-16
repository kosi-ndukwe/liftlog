import SwiftData
import SwiftUI

/// One workout: each exercise in order with its sets. Tap an exercise for its chart.
struct WorkoutDetailView: View {
    let session: WorkoutSession

    var body: some View {
        List {
            Section {
                LabeledContent("Date") {
                    Text(session.start, format: .dateTime.weekday(.wide).day().month().year().hour().minute())
                }
                if let duration = session.duration, duration > 0 {
                    LabeledContent("Duration", value: Duration.seconds(duration).formatted(.units(allowed: [.hours, .minutes])))
                }
                if let average = session.averageHeartRate {
                    LabeledContent("Average heart rate", value: "\(Int(average)) bpm")
                }
                if let peak = session.peakHeartRate {
                    LabeledContent("Peak heart rate", value: "\(Int(peak)) bpm")
                }
            }

            ForEach(groupedSets, id: \.exercise.persistentModelID) { group in
                Section {
                    // Links in section headers don't respond to taps, so the exercise is the first row.
                    NavigationLink(value: group.exercise) {
                        Label(group.exercise.name, systemImage: "chart.xyaxis.line")
                            .font(.headline)
                    }
                    ForEach(group.sets) { set in
                        SetRow(set: set)
                    }
                }
            }
        }
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Sets grouped by exercise, in the order the exercises were done.
    private var groupedSets: [(exercise: Exercise, sets: [SetEntry])] {
        let ordered = session.orderedSets
        return session.exercisesInOrder.map { exercise in
            (exercise, ordered.filter { $0.exercise == exercise })
        }
    }
}

struct SetRow: View {
    let set: SetEntry

    var body: some View {
        HStack {
            Text(set.summary)
                .monospacedDigit()
            if set.isWarmup {
                Text("Warm-up")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
            Spacer()
            if !set.isWarmup, let estimate = Strength.estimatedOneRepMax(pounds: set.weightLb, reps: set.reps), set.reps > 1 {
                Text("≈ \(ExerciseMetric.oneRepMax.format(estimate)) 1RM")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        WorkoutDetailView(session: try! PreviewData.container.mainContext.fetch(FetchDescriptor<WorkoutSession>()).first!)
    }
    .modelContainer(PreviewData.container)
}
