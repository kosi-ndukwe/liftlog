import SwiftData
import SwiftUI

/// Past workouts, newest first. Tap one for details, or open Exercises for charts.
struct HistoryView: View {
    @Query(sort: \WorkoutSession.start, order: .reverse) private var sessions: [WorkoutSession]

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No Workouts Yet",
                        systemImage: "clock",
                        description: Text("Finished workouts and imported Fitbod history will appear here.")
                    )
                } else {
                    List {
                        Section {
                            NavigationLink(value: HistoryRoute.exercises) {
                                Label("Exercises", systemImage: "chart.xyaxis.line")
                            }
                        }
                        Section("Workouts") {
                            ForEach(sessions) { session in
                                NavigationLink(value: session) {
                                    WorkoutRow(session: session)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: HistoryRoute.self) { _ in ExerciseListView() }
            .navigationDestination(for: WorkoutSession.self) { WorkoutDetailView(session: $0) }
            .navigationDestination(for: Exercise.self) { ExerciseDetailView(exercise: $0) }
        }
    }
}

enum HistoryRoute: Hashable {
    case exercises
}

private struct WorkoutRow: View {
    let session: WorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(session.title)
                .font(.headline)
                .lineLimit(2)
            Text(session.start, format: .dateTime.weekday().day().month().year())
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(session.sets.count) sets")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    HistoryView()
        .modelContainer(PreviewData.container)
}
