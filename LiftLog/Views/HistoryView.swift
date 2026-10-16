import SwiftData
import SwiftUI

/// Past workouts, newest first. Charts come in milestone 3.
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
                    List(sessions) { session in
                        VStack(alignment: .leading) {
                            Text(session.routine?.name ?? "Workout")
                                .font(.headline)
                            Text(session.start, format: .dateTime.weekday().day().month().year())
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("\(session.sets.count) sets")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("History")
        }
    }
}

#Preview {
    HistoryView()
        .modelContainer(PreviewData.container)
}
