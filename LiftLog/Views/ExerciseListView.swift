import SwiftData
import SwiftUI

/// Every exercise, built-in and imported. Tap one for its chart and history.
struct ExerciseListView: View {
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var searchText = ""
    @State private var grouping = Grouping.all
    @State private var sort = Sort.alphabetical

    enum Grouping: CaseIterable { case all, byMuscle, logged }
    enum Sort: CaseIterable { case alphabetical, mostLogged }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Exercises")
                        .font(.sectionTitle)
                        .foregroundStyle(Palette.textPrimary)
                        .padding(.top, 8)
                    SegmentedPill(options: Grouping.allCases, selection: $grouping) { option in
                        switch option {
                        case .all: "All"
                        case .byMuscle: "By Muscle"
                        case .logged: "Logged"
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                let sections = sections
                if sections.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                        .padding(.top, 40)
                }
                ForEach(sections, id: \.title) { section in
                    Section {
                        ForEach(section.exercises) { exercise in
                            NavigationLink(value: exercise) {
                                ExerciseRow(exercise: exercise, detail: detail(for: exercise))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                        }
                    } header: {
                        Text(section.title)
                            .font(.subsectionTitle)
                            .foregroundStyle(Palette.textSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Palette.background)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .screenBackground()
        .searchable(text: $searchText, prompt: "Search exercises")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort", selection: $sort) {
                        Label("Alphabetically", systemImage: "textformat").tag(Sort.alphabetical)
                        Label("Most logged", systemImage: "arrow.up.right").tag(Sort.mostLogged)
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                }
            }
        }
        .toolbarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.background, for: .navigationBar)
    }

    private func detail(for exercise: Exercise) -> String {
        var parts: [String] = []
        let muscles = exercise.primary.map(\.label)
        if !muscles.isEmpty { parts.append(muscles.prefix(2).joined(separator: ", ")) }
        parts.append(exercise.loggedSetCount > 0 ? "\(exercise.loggedSetCount.formatted()) sets" : "never logged")
        return parts.joined(separator: " · ")
    }

    private var filtered: [Exercise] {
        var result = searchText.isEmpty ? exercises : exercises.filter { $0.name.localizedStandardContains(searchText) }
        if grouping == .logged { result = result.filter { $0.loggedSetCount > 0 } }
        if sort == .mostLogged {
            result.sort { ($0.loggedSetCount, $1.name) > ($1.loggedSetCount, $0.name) }
        }
        return result
    }

    struct ListSection {
        var title: String
        var exercises: [Exercise]
    }

    private var sections: [ListSection] {
        let items = filtered
        switch grouping {
        case .byMuscle:
            return MuscleGroup.allCases.compactMap { group in
                let matching = items.filter { $0.primary.contains { $0.group == group } }
                return matching.isEmpty ? nil : ListSection(title: group.label, exercises: matching)
            }
        case .all, .logged:
            if sort == .mostLogged {
                return items.isEmpty ? [] : [ListSection(title: "Most logged", exercises: items)]
            }
            // Letter headers like a contacts list.
            var order: [String] = []
            var byLetter: [String: [Exercise]] = [:]
            for exercise in items {
                let first = exercise.name.first.map { $0.isLetter ? String($0).uppercased() : "#" } ?? "#"
                if byLetter[first] == nil { order.append(first) }
                byLetter[first, default: []].append(exercise)
            }
            return order.map { ListSection(title: $0, exercises: byLetter[$0] ?? []) }
        }
    }
}

#Preview {
    NavigationStack {
        ExerciseListView()
    }
    .modelContainer(PreviewData.container)
    .preferredColorScheme(.dark)
}
