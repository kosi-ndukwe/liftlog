import SwiftData
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Today", systemImage: "figure.strengthtraining.traditional") {
                TodayView()
            }
            Tab("Log", systemImage: "calendar") {
                HistoryView()
            }
            Tab("Exercises", systemImage: "chart.xyaxis.line") {
                NavigationStack {
                    ExerciseListView()
                        .navigationDestination(for: Exercise.self) { ExerciseDetailView(exercise: $0) }
                        .navigationDestination(for: WorkoutSession.self) { WorkoutDetailView(session: $0) }
                }
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewData.container)
        .preferredColorScheme(.dark)
}
