import SwiftData
import SwiftUI

/// Pick one or more exercises to add to a workout. Search, tick, Add.
struct ExercisePickerSheet: View {
    var excluding: [Exercise] = []
    let onAdd: ([Exercise]) -> Void
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var chosen: Set<PersistentIdentifier> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(shown) { exercise in
                        Button {
                            if chosen.contains(exercise.persistentModelID) {
                                chosen.remove(exercise.persistentModelID)
                            } else {
                                chosen.insert(exercise.persistentModelID)
                            }
                        } label: {
                            HStack(spacing: 14) {
                                MuscleThumbnail(exercise: exercise, size: 48)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name)
                                        .font(.rowTitle)
                                        .foregroundStyle(Palette.textPrimary)
                                        .multilineTextAlignment(.leading)
                                    Text(exercise.primary.map(\.label).joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundStyle(Palette.textSecondary)
                                }
                                Spacer()
                                let isChosen = chosen.contains(exercise.persistentModelID)
                                Image(systemName: isChosen ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 24))
                                    .foregroundStyle(isChosen ? Palette.textPrimary : Palette.textMuted)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(chosen.contains(exercise.persistentModelID) ? Palette.card : .clear)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 100)
            }
            .screenBackground()
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("All Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Palette.accent)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !chosen.isEmpty {
                    Button(chosen.count == 1 ? "Add Exercise" : "Add \(chosen.count) Exercises") {
                        onAdd(exercises.filter { chosen.contains($0.persistentModelID) })
                        dismiss()
                    }
                    .buttonStyle(PillButtonStyle())
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
        }
    }

    /// Logged exercises first so your usual ones are near the top, then the rest alphabetically.
    private var shown: [Exercise] {
        let excluded = Set(excluding.map(\.persistentModelID))
        let matching = exercises.filter { !excluded.contains($0.persistentModelID) && (searchText.isEmpty || $0.name.localizedStandardContains(searchText)) }
        return matching.sorted { ($0.loggedSetCount > 0 ? 0 : 1, $0.name) < ($1.loggedSetCount > 0 ? 0 : 1, $1.name) }
    }
}
