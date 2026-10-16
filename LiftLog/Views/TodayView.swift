import SwiftData
import SwiftUI

/// Today's steps, a workout in progress, and the saved routines to start one from.
struct TodayView: View {
    @AppStorage(HealthSettings.readStepsKey) private var readSteps = false
    @State private var steps: Int?
    @Query(sort: [SortDescriptor(\Routine.sortOrder), SortDescriptor(\Routine.createdAt)]) private var routines: [Routine]
    @Query(filter: #Predicate<WorkoutSession> { $0.end == nil }, sort: \WorkoutSession.start, order: .reverse)
    private var inProgress: [WorkoutSession]
    @Environment(\.modelContext) private var modelContext
    @State private var active: WorkoutSession?
    @State private var isMakingRoutine = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Today")
                        .font(.sectionTitle)
                        .foregroundStyle(Palette.textPrimary)
                        .padding(.top, 8)

                    if readSteps {
                        HStack(spacing: 14) {
                            Image(systemName: "figure.walk")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Palette.accent)
                                .frame(width: 44, height: 44)
                                .background(Palette.cardRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Steps").statLabelStyle()
                                Text(steps.map { $0.formatted() } ?? "—")
                                    .font(.statSmallValue)
                                    .foregroundStyle(Palette.textPrimary)
                            }
                            Spacer()
                            Text("from Apple Health")
                                .font(.caption)
                                .foregroundStyle(Palette.textMuted)
                        }
                        .card()
                        .task(id: readSteps) { await loadSteps() }
                    }

                    if let session = inProgress.first {
                        Button {
                            active = session
                        } label: {
                            HStack(spacing: 14) {
                                Circle().fill(Palette.accent).frame(width: 12, height: 12)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Workout in progress")
                                        .font(.rowTitle)
                                        .foregroundStyle(Palette.textPrimary)
                                    Text("\(session.title) · started " + session.start.formatted(.dateTime.hour().minute()) + " · \(session.completedCount) sets done")
                                        .font(.caption)
                                        .foregroundStyle(Palette.textSecondary)
                                }
                                Spacer()
                                Text("Resume")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Palette.accent)
                            }
                            .card()
                        }
                        .buttonStyle(.plain)
                    }

                    if routines.isEmpty {
                        ContentUnavailableView(
                            "No Routines Yet",
                            systemImage: "list.bullet.rectangle",
                            description: Text("Import your Fitbod history in Settings to create routines.")
                        )
                        .card()
                    } else {
                        Text("Routines")
                            .statLabelStyle()
                        ForEach(Array(routines.enumerated()), id: \.element.persistentModelID) { index, routine in
                            NavigationLink(value: routine) {
                                RoutineCard(routine: routine)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                if index > 0 {
                                    Button { move(routine, by: -1) } label: { Label("Move Up", systemImage: "arrow.up") }
                                }
                                if index < routines.count - 1 {
                                    Button { move(routine, by: 1) } label: { Label("Move Down", systemImage: "arrow.down") }
                                }
                            }
                        }
                    }

                    Button {
                        isMakingRoutine = true
                    } label: {
                        Label("New Routine", systemImage: "plus")
                            .font(.rowTitle)
                            .foregroundStyle(Palette.accent)
                            .padding(.vertical, 8)
                    }

                    Button {
                        start(routine: nil)
                    } label: {
                        Label("Start an empty workout", systemImage: "figure.strengthtraining.traditional")
                            .font(.rowTitle)
                            .foregroundStyle(Palette.accent)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isMakingRoutine) {
                RoutineEditorView(routine: nil)
                    .presentationBackground(Palette.background)
            }
            .fullScreenCover(item: $active, onDismiss: { Task { await loadSteps() } }) { session in
                ActiveWorkoutView(session: session)
                    .preferredColorScheme(.dark)
            }
            .navigationDestination(for: Routine.self) { RoutineDetailView(routine: $0, onStart: start) }
            .navigationDestination(for: Exercise.self) { ExerciseDetailView(exercise: $0) }
            .navigationDestination(for: WorkoutSession.self) { WorkoutDetailView(session: $0) }
        }
    }

    /// Swaps the routine with its neighbour on the Today screen.
    private func move(_ routine: Routine, by offset: Int) {
        guard let index = routines.firstIndex(where: { $0 == routine }),
              routines.indices.contains(index + offset) else { return }
        // Give every routine an explicit position first, then swap two.
        for (position, each) in routines.enumerated() { each.sortOrder = position }
        routines[index].sortOrder = index + offset
        routines[index + offset].sortOrder = index
        try? modelContext.save()
    }

    private func loadSteps() async {
        guard readSteps else { return }
        steps = try? await HealthStore.shared.stepsToday()
    }

    private func start(routine: Routine?) {
        if let session = inProgress.first {
            active = session
            return
        }
        do {
            active = try WorkoutLogger.start(routine: routine, in: modelContext)
        } catch {
            print("Couldn't start the workout: \(error)")
        }
    }
}

private struct RoutineCard: View {
    let routine: Routine

    var body: some View {
        HStack(spacing: 14) {
            MuscleGroupBadge(group: routine.suggestedName.flatMap(MuscleGroup.init(rawValue:)))
            VStack(alignment: .leading, spacing: 4) {
                Text(routine.name)
                    .font(.rowTitle)
                    .foregroundStyle(Palette.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.textMuted)
        }
        .card()
    }

    private var subtitle: String {
        var parts = ["\(routine.entries.count) exercises"]
        if let last = routine.lastDone {
            let when = Calendar.current.isDateInToday(last) ? "today"
                : Calendar.current.isDateInYesterday(last) ? "yesterday"
                : last.formatted(.dateTime.month().day())
            parts.append("last done " + when)
        }
        return parts.joined(separator: " · ")
    }
}

/// A rounded square with a figure for push / pull / legs.
struct MuscleGroupBadge: View {
    let group: MuscleGroup?
    var size: CGFloat = 56

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Palette.cardRaised)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: group?.symbolName ?? "list.bullet.rectangle")
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
            }
    }
}

/// A routine's exercises, each with what you did last time, and a Start button.
struct RoutineDetailView: View {
    let routine: Routine
    var onStart: (Routine?) -> Void = { _ in }
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var isConfirmingDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(routine.name)
                        .font(.heroTitle)
                        .foregroundStyle(Palette.textPrimary)
                    Text("\(routine.entries.count) exercises")
                        .font(.bodyText)
                        .foregroundStyle(Palette.textSecondary)
                }
                .padding(.top, 8)

                let last = routine.sessions.max { $0.start < $1.start }
                ForEach(routine.orderedExercises) { exercise in
                    NavigationLink(value: exercise) {
                        ExerciseRow(exercise: exercise, detail: lastTime(exercise, in: last))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { isEditing = true } label: { Label("Edit Routine", systemImage: "pencil") }
                    Button(role: .destructive) { isConfirmingDelete = true } label: { Label("Delete Routine", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            RoutineEditorView(routine: routine)
                .presentationBackground(Palette.background)
        }
        .confirmationDialog("Delete \(routine.name)?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete Routine", role: .destructive) {
                modelContext.delete(routine)
                try? modelContext.save()
                dismiss()
            }
        } message: {
            Text("Past workouts stay in your Log; they just lose the routine's name.")
        }
        .safeAreaInset(edge: .bottom) {
            Button("Start Workout") { onStart(routine) }
                .buttonStyle(PillButtonStyle())
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
    }

    /// "4 sets · 8 reps · 135 lb" from the most recent workout of this routine,
    /// or from wherever the exercise was last done.
    private func lastTime(_ exercise: Exercise, in session: WorkoutSession?) -> String {
        var sets = session?.orderedSets.filter { $0.exercise == exercise && !$0.isWarmup } ?? []
        if sets.isEmpty, let latest = exercise.sets.compactMap(\.session).max(by: { $0.start < $1.start }) {
            sets = latest.orderedSets.filter { $0.exercise == exercise && !$0.isWarmup }
        }
        guard let top = sets.max(by: { $0.weightLb < $1.weightLb }) else { return "Not done yet" }
        var parts = ["\(sets.count) sets"]
        if top.reps > 0 { parts.append("\(top.reps) reps") }
        if top.weightLb > 0 { parts.append(Weight.formattedPounds(fromKg: top.weightKg)) }
        return parts.joined(separator: " · ")
    }
}

/// Thumbnail, name and a line of detail, with a chevron.
struct ExerciseRow: View {
    let exercise: Exercise
    var detail: String

    var body: some View {
        HStack(spacing: 14) {
            MuscleThumbnail(exercise: exercise)
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.rowTitle)
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.leading)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.textMuted)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    TodayView()
        .modelContainer(PreviewData.container)
        .preferredColorScheme(.dark)
}
