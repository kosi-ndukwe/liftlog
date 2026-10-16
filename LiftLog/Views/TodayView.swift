import SwiftData
import SwiftUI

/// Saved routines. Starting a workout and the step count come in later milestones.
struct TodayView: View {
    @Query(sort: \Routine.createdAt) private var routines: [Routine]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Today")
                        .font(.sectionTitle)
                        .foregroundStyle(Palette.textPrimary)
                        .padding(.top, 8)

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
                        ForEach(routines) { routine in
                            NavigationLink(value: routine) {
                                RoutineCard(routine: routine)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Routine.self) { RoutineDetailView(routine: $0) }
            .navigationDestination(for: Exercise.self) { ExerciseDetailView(exercise: $0) }
            .navigationDestination(for: WorkoutSession.self) { WorkoutDetailView(session: $0) }
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

/// A routine's exercises, each with what you did last time.
struct RoutineDetailView: View {
    let routine: Routine

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
            ExerciseThumbnail(exercise: exercise)
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
