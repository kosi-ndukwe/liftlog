import SwiftData
import SwiftUI

/// Make a new routine or change one: its name and its exercises, in order.
/// Drag the handles to reorder; swipe or tap the minus to remove.
struct RoutineEditorView: View {
    /// nil makes a new routine when you tap Save.
    let routine: Routine?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var exercises: [Exercise] = []
    @State private var isPickingExercise = false

    init(routine: Routine?) {
        self.routine = routine
        _name = State(initialValue: routine?.name ?? "")
        _exercises = State(initialValue: routine?.orderedExercises ?? [])
    }

    var body: some View {
        NavigationStack {
            // The name sits above the list because the list is always in edit
            // mode (for the drag handles), which would block a text field inside it.
            VStack(alignment: .leading, spacing: 8) {
                Text("Name").statLabelStyle()
                TextField("Routine name", text: $name)
                    .font(.subsectionTitle)
                    .foregroundStyle(Palette.textPrimary)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text("Short names work best: push, pull, legs, arms.")
                    .font(.caption)
                    .foregroundStyle(Palette.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .screenBackground()

            List {
                Section {
                    ForEach(exercises, id: \.persistentModelID) { exercise in
                        HStack(spacing: 14) {
                            MuscleThumbnail(exercise: exercise, size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name)
                                    .font(.bodyText)
                                    .foregroundStyle(Palette.textPrimary)
                                Text(exercise.primary.map(\.label).joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(Palette.textSecondary)
                            }
                        }
                        .listRowBackground(Palette.card)
                    }
                    .onMove { exercises.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { exercises.remove(atOffsets: $0) }

                    Button {
                        isPickingExercise = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus")
                            .font(.rowTitle)
                            .foregroundStyle(Palette.accent)
                    }
                    .listRowBackground(Palette.card)
                } header: {
                    Text("\(exercises.count) exercises").statLabelStyle()
                } footer: {
                    if !exercises.isEmpty {
                        Text("Drag the handles to change the order. Swipe left to remove.")
                            .foregroundStyle(Palette.textMuted)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .environment(\.editMode, .constant(.active))
            .navigationTitle(routine == nil ? "New Routine" : "Edit Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Palette.accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Palette.accent)
                        .disabled(trimmedName.isEmpty || exercises.isEmpty)
                }
            }
            .sheet(isPresented: $isPickingExercise) {
                ExercisePickerSheet(excluding: exercises) { exercises.append(contentsOf: $0) }
                    .presentationBackground(Palette.background)
            }
        }
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    private func save() {
        let target: Routine
        if let routine {
            target = routine
        } else {
            let last = (try? modelContext.fetch(FetchDescriptor<Routine>()))?.map(\.sortOrder).max() ?? -1
            target = Routine(name: trimmedName)
            target.sortOrder = last + 1
            modelContext.insert(target)
        }
        target.name = trimmedName
        target.replaceExercises(with: exercises, in: modelContext)
        try? modelContext.save()
        dismiss()
    }
}

extension Routine {
    /// Sets the routine's exercises to exactly this list, in this order.
    func replaceExercises(with exercises: [Exercise], in context: ModelContext) {
        for entry in entries { context.delete(entry) }
        entries.removeAll()
        for (index, exercise) in exercises.enumerated() {
            entries.append(RoutineExercise(order: index, exercise: exercise))
        }
    }
}

#Preview {
    RoutineEditorView(routine: try! PreviewData.container.mainContext.fetch(FetchDescriptor<Routine>()).first)
        .modelContainer(PreviewData.container)
        .preferredColorScheme(.dark)
}
