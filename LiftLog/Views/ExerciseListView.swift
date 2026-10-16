import SwiftData
import SwiftUI

/// Every exercise you've done. Tap one for its chart and history.
struct ExerciseListView: View {
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var searchText = ""

    var body: some View {
        List(filtered) { exercise in
            NavigationLink(value: exercise) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                    Text("\(exercise.sets.count) sets")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .overlay {
            if filtered.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .searchable(text: $searchText, prompt: "Search exercises")
        .navigationTitle("Exercises")
    }

    private var filtered: [Exercise] {
        searchText.isEmpty ? exercises : exercises.filter { $0.name.localizedStandardContains(searchText) }
    }
}

#Preview {
    NavigationStack {
        ExerciseListView()
    }
    .modelContainer(PreviewData.container)
}
