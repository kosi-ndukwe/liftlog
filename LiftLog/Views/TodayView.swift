import SwiftData
import SwiftUI

/// Saved routines. Starting a workout and the step count come in later milestones.
struct TodayView: View {
    @Query(sort: \Routine.name) private var routines: [Routine]

    var body: some View {
        NavigationStack {
            Group {
                if routines.isEmpty {
                    ContentUnavailableView(
                        "No Routines Yet",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Import your Fitbod history in Settings to create routines.")
                    )
                } else {
                    List(routines) { routine in
                        VStack(alignment: .leading) {
                            Text(routine.name)
                                .font(.headline)
                            Text("\(routine.entries.count) exercises")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Today")
        }
    }
}

#Preview {
    TodayView()
        .modelContainer(PreviewData.container)
}
