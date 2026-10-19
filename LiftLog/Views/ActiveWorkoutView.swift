import SwiftData
import SwiftUI

/// The workout you're doing right now: a running clock, each exercise with
/// how many sets are done, and a sheet per exercise to log the sets.
struct ActiveWorkoutView: View {
    @Bindable var session: WorkoutSession
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("restSeconds") private var restSeconds = 90
    @State private var rest = RestTimer()
    @State private var editing: EditingExercise?

    /// Wraps the exercise so a sheet can be driven by it.
    struct EditingExercise: Identifiable {
        let exercise: Exercise
        var id: PersistentIdentifier { exercise.persistentModelID }
    }
    @State private var isPickingExercise = false
    @State private var isConfirmingCancel = false
    @State private var isConfirmingFinish = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    RestControls(rest: rest, restSeconds: $restSeconds)
                    ForEach(session.exercisesInOrder, id: \.persistentModelID) { exercise in
                        Button {
                            editing = EditingExercise(exercise: exercise)
                        } label: {
                            ExerciseRow(exercise: exercise, detail: progress(for: exercise))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        isPickingExercise = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus")
                            .font(.rowTitle)
                            .foregroundStyle(Palette.accent)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 120)
            }
            .screenBackground()
            .safeAreaInset(edge: .bottom) { bottomBar }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isConfirmingCancel = true }
                        .foregroundStyle(Palette.accent)
                }
                ToolbarItem(placement: .principal) {
                    Text(session.title)
                        .font(.system(size: 17, weight: .semibold))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Finish") { finish() }
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Palette.accent)
                        .disabled(session.completedCount == 0)
                }
            }
            .toolbarBackground(Palette.background, for: .navigationBar)
            .sheet(item: $editing) { item in
                ExerciseLogSheet(session: session, exercise: item.exercise, rest: rest, restSeconds: $restSeconds)
                    .presentationDetents([.large])
                    .presentationBackground(Palette.background)
            }
            .sheet(isPresented: $isPickingExercise) {
                ExercisePickerSheet(excluding: session.exercisesInOrder) { chosen in
                    for exercise in chosen { WorkoutLogger.add(exercise, to: session) }
                }
                .presentationBackground(Palette.background)
            }
            .confirmationDialog("Discard this workout?", isPresented: $isConfirmingCancel, titleVisibility: .visible) {
                Button("Discard Workout", role: .destructive) {
                    try? WorkoutLogger.discard(session, in: modelContext)
                    dismiss()
                }
            } message: {
                Text("Nothing from it will be saved.")
            }
            .confirmationDialog("Finish workout?", isPresented: $isConfirmingFinish, titleVisibility: .visible) {
                Button("Finish and Drop Unfinished Sets") { finish(force: true) }
            } message: {
                Text("\(session.sets.count - session.completedCount) planned sets weren't done and will be left out.")
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            TimelineView(.periodic(from: session.start, by: 1)) { timeline in
                HStack(spacing: 10) {
                    Circle().fill(Palette.accent).frame(width: 12, height: 12)
                    Text(elapsed(at: timeline.date))
                        .font(.system(size: 34, weight: .bold, design: .monospaced).italic())
                        .foregroundStyle(Palette.textPrimary)
                }
            }
            Spacer()
            Text("\(session.completedCount) / \(session.sets.count) sets")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var bottomBar: some View {
        if let endsAt = rest.endsAt {
            RestTimerBar(endsAt: endsAt, onAdjust: { rest.adjust(by: $0) }) { rest.stop() }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
    }

    private func elapsed(at date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(session.start)))
        return String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
    }

    /// "2 / 4 sets · 8 reps · 135 lb" for an exercise's row.
    private func progress(for exercise: Exercise) -> String {
        let sets = session.orderedSets.filter { $0.exercise == exercise }
        let done = sets.filter(\.isCompleted).count
        var parts = ["\(done) / \(sets.count) sets"]
        if let top = sets.filter({ !$0.isWarmup }).max(by: { $0.weightLb < $1.weightLb }) {
            if top.reps > 0 { parts.append("\(top.reps) reps") }
            if top.weightLb > 0 { parts.append(Weight.formattedPounds(fromKg: top.weightKg)) }
        }
        return parts.joined(separator: " · ")
    }

    private func finish(force: Bool = false) {
        if !force && session.completedCount < session.sets.count {
            isConfirmingFinish = true
            return
        }
        do {
            let saved = try WorkoutLogger.finish(session, in: modelContext)
            if saved {
                let context = modelContext
                Task { await WorkoutHealthSync.run(for: session, in: context) }
            }
            dismiss()
        } catch {
            print("Couldn't finish the workout: \(error)")
        }
    }
}

/// Reps and weight for each set of one exercise. Tap the hexagon when a set is done.
struct ExerciseLogSheet: View {
    @Bindable var session: WorkoutSession
    let exercise: Exercise
    var rest: RestTimer
    @Binding var restSeconds: Int
    @State private var stopwatch = SetStopwatch()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Field?

    enum Field: Hashable {
        case reps(PersistentIdentifier)
        case weight(PersistentIdentifier)
        case duration(PersistentIdentifier)
        case distance(PersistentIdentifier)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 14) {
                        MuscleThumbnail(exercise: exercise, size: 64)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.name)
                                .font(.subsectionTitle)
                                .foregroundStyle(Palette.textPrimary)
                            Text(exercise.primary.map(\.label).joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(Palette.textSecondary)
                        }
                    }
                    .padding(.top, 8)

                    HStack {
                        Spacer().frame(width: 44)
                        if exercise.isTimed {
                            Text("Time").statLabelStyle().frame(maxWidth: .infinity, alignment: .leading)
                            Text(exercise.exerciseKind == .cardio ? "Distance (mi)" : "Weight (lb)").statLabelStyle().frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text("Reps").statLabelStyle().frame(maxWidth: .infinity, alignment: .leading)
                            Text(exercise.isAssisted ? "Assist (lb)" : "Weight (lb)").statLabelStyle().frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Spacer().frame(width: 32)
                    }

                    let sets = session.orderedSets.filter { $0.exercise == exercise }
                    ForEach(sets) { set in
                        SetEditorRow(set: set, exercise: exercise, focused: $focused, stopwatch: stopwatch, onDone: { rest.start(seconds: restSeconds) }) {
                            modelContext.delete(set)
                            session.sets.removeAll { $0 == set }
                        }
                    }

                    Button {
                        let added = WorkoutLogger.addSet(for: exercise, to: session)
                        focused = .reps(added.persistentModelID)
                    } label: {
                        HStack(spacing: 12) {
                            HexBadge(systemImage: "plus", fill: .clear, foreground: Palette.accent, size: 32)
                                .overlay(Hexagon().stroke(Palette.accent, lineWidth: 2).frame(width: 32, height: 32))
                            Text("Add Set")
                                .font(.rowTitle)
                                .foregroundStyle(Palette.accent)
                        }
                    }
                    .padding(.top, 4)

                    Button(role: .destructive) {
                        WorkoutLogger.remove(exercise, from: session, in: modelContext)
                        dismiss()
                    } label: {
                        Label("Remove from workout", systemImage: "trash")
                            .font(.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    .padding(.top, 24)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    if let endsAt = rest.endsAt {
                        RestTimerBar(endsAt: endsAt, onAdjust: { rest.adjust(by: $0) }) { rest.stop() }
                    } else if !exercise.isTimed {
                        RestControls(rest: rest, restSeconds: $restSeconds)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Palette.accent)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focused = nil }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Palette.accent)
                }
            }
            .toolbarBackground(Palette.background, for: .navigationBar)
        }
    }
}

/// One set: a done hexagon, reps and weight fields.
struct SetEditorRow: View {
    @Bindable var set: SetEntry
    let exercise: Exercise
    var focused: FocusState<ExerciseLogSheet.Field?>.Binding
    var stopwatch: SetStopwatch
    var onDone: () -> Void
    var onDelete: () -> Void

    private var isRunning: Bool { stopwatch.runningSetID == set.persistentModelID }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                set.isCompleted.toggle()
                if set.isCompleted { onDone() }
            } label: {
                HexBadge(
                    systemImage: "checkmark",
                    fill: set.isCompleted ? Palette.done : Palette.cardRaised,
                    foreground: set.isCompleted ? Palette.background : Palette.textMuted,
                    size: 32
                )
            }
            .buttonStyle(.plain)
            .frame(width: 44)

            if exercise.isTimed {
                // Time: a stopwatch you start and stop, or type mm:ss.
                if isRunning, let startedAt = stopwatch.startedAt {
                    TimelineView(.periodic(from: startedAt, by: 1)) { timeline in
                        timedField(text: ClockFormat.clock(timeline.date.timeIntervalSince(startedAt)), running: true)
                    }
                } else {
                    field(text: durationBinding, placeholder: "0:00", field: .duration(set.persistentModelID), keyboard: .numbersAndPunctuation)
                }
                if exercise.exerciseKind == .cardio {
                    field(text: distanceBinding, placeholder: "0", field: .distance(set.persistentModelID), keyboard: .decimalPad)
                } else {
                    field(text: weightBinding, placeholder: "0", field: .weight(set.persistentModelID), keyboard: .decimalPad)
                }
                Button {
                    if isRunning {
                        set.durationSeconds = (stopwatch.stop()).rounded()
                        set.isCompleted = true
                        onDone()
                    } else {
                        focused.wrappedValue = nil
                        stopwatch.start(set.persistentModelID)
                    }
                } label: {
                    Image(systemName: isRunning ? "stop.fill" : "play.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(isRunning ? Palette.background : Palette.accent)
                        .frame(width: 44, height: 44)
                        .background(isRunning ? Palette.accent : Palette.cardRaised, in: Circle())
                }
                .buttonStyle(.plain)
            } else {
                field(text: repsBinding, placeholder: "0", field: .reps(set.persistentModelID), keyboard: .numberPad)
                field(text: weightBinding, placeholder: "0", field: .weight(set.persistentModelID), keyboard: .decimalPad)
            }

            Menu {
                Toggle("Warm-up", isOn: $set.isWarmup)
                Button("Delete Set", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: 32, height: 44)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if set.isWarmup {
                Text("warm-up")
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.textMuted)
                    .offset(x: 56, y: 6)
            }
        }
    }

    private func field(text: Binding<String>, placeholder: String, field: ExerciseLogSheet.Field, keyboard: UIKeyboardType) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .font(.system(size: 24, weight: .semibold, design: .monospaced).italic())
            .foregroundStyle(set.isCompleted ? Palette.done : Palette.textPrimary)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(focused.wrappedValue == field ? Palette.textPrimary : Palette.hairline, lineWidth: 1))
            .focused(focused, equals: field)
    }

    /// The time field while the stopwatch runs: same look, not editable.
    private func timedField(text: String, running: Bool) -> some View {
        Text(text)
            .font(.system(size: 24, weight: .semibold, design: .monospaced).italic())
            .foregroundStyle(Palette.accent)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Palette.accent, lineWidth: 1))
    }

    private var durationBinding: Binding<String> {
        Binding(
            get: { set.durationSeconds == 0 ? "" : ClockFormat.clock(set.durationSeconds) },
            set: { if let seconds = ClockFormat.parseClock($0) { set.durationSeconds = seconds } }
        )
    }

    private var distanceBinding: Binding<String> {
        Binding(
            get: { set.distanceMeters == 0 ? "" : (set.distanceMeters / 1_609.344).formatted(.number.precision(.fractionLength(0...2))) },
            set: { text in
                if let miles = Double(text.replacingOccurrences(of: ",", with: ".")) { set.distanceMeters = miles * 1_609.344 } else if text.isEmpty { set.distanceMeters = 0 }
            }
        )
    }

    private var repsBinding: Binding<String> {
        Binding(
            get: { set.reps == 0 ? "" : "\(set.reps)" },
            set: { set.reps = Int($0.filter(\.isNumber)) ?? 0 }
        )
    }

    private var weightBinding: Binding<String> {
        Binding(
            get: { set.weightKg == 0 ? "" : set.weightLb.formatted(.number.precision(.fractionLength(0...1))) },
            set: { text in
                if let pounds = Double(text.replacingOccurrences(of: ",", with: ".")) { set.weightLb = pounds } else if text.isEmpty { set.weightKg = 0 }
            }
        )
    }
}

/// The rest countdown, shared by the workout screen and the set sheet so
/// both show the same timer.
@Observable
final class RestTimer {
    var endsAt: Date?

    func start(seconds: Int) {
        guard seconds > 0 else { return }
        endsAt = Date.now.addingTimeInterval(TimeInterval(seconds))
    }

    func stop() { endsAt = nil }

    /// Adds or takes away time from a running countdown.
    func adjust(by seconds: Int) {
        guard let endsAt else { return }
        self.endsAt = max(Date.now, endsAt.addingTimeInterval(TimeInterval(seconds)))
    }
}

/// Which set's stopwatch is running, for timed exercises.
@Observable
final class SetStopwatch {
    var runningSetID: PersistentIdentifier?
    var startedAt: Date?

    func start(_ id: PersistentIdentifier) {
        runningSetID = id
        startedAt = .now
    }

    /// Stops and returns the seconds that passed.
    @discardableResult
    func stop() -> TimeInterval {
        defer { runningSetID = nil; startedAt = nil }
        return startedAt.map { Date.now.timeIntervalSince($0) } ?? 0
    }
}

/// Pick the rest length and start a rest by hand, right where you log sets.
struct RestControls: View {
    var rest: RestTimer
    @Binding var restSeconds: Int

    static let choices = [0, 30, 60, 90, 120, 180, 300]

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "timer")
                .foregroundStyle(Palette.textSecondary)
            Text("Rest")
                .font(.bodyText)
                .foregroundStyle(Palette.textPrimary)
            Spacer()
            Menu {
                Picker("Rest", selection: $restSeconds) {
                    ForEach(Self.choices, id: \.self) { seconds in
                        Text(seconds == 0 ? "Off" : ClockFormat.clock(TimeInterval(seconds))).tag(seconds)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(restSeconds == 0 ? "Off" : ClockFormat.clock(TimeInterval(restSeconds)))
                        .monospacedDigit()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Palette.cardRaised, in: Capsule())
            }
            Button {
                rest.start(seconds: restSeconds)
            } label: {
                Text("Start")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.textOnAccent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Palette.accent, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(restSeconds == 0)
            .opacity(restSeconds == 0 ? 0.4 : 1)
        }
        .card(padding: 12)
    }
}

/// A countdown pill after a set: "Rest 1:30", with a skip button.
struct RestTimerBar: View {
    let endsAt: Date
    var onAdjust: ((Int) -> Void)? = nil
    let onDismiss: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let remaining = max(0, Int(endsAt.timeIntervalSince(timeline.date).rounded()))
            HStack {
                Image(systemName: "timer")
                Text(remaining > 0 ? String(format: "Rest %d:%02d", remaining / 60, remaining % 60) : "Rest over")
                    .monospacedDigit()
                Spacer()
                if remaining > 0, let onAdjust {
                    Button("+30s") { onAdjust(30) }
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.trailing, 8)
                }
                Button(remaining > 0 ? "Skip" : "OK", action: onDismiss)
                    .font(.system(size: 16, weight: .bold))
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(remaining > 0 ? Palette.textPrimary : Palette.background)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(remaining > 0 ? Palette.cardRaised : Palette.done, in: Capsule())
            .onChange(of: remaining == 0) { _, over in
                if over { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            }
        }
    }
}

/// Reads and writes "m:ss" times. Plain functions, safe from any thread
/// (the view they used to live in is main-actor only, which tests tripped on).
enum ClockFormat {
    /// "1:30" or "12:05".
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return total >= 3600
            ? String(format: "%d:%02d:%02d", total / 3600, total / 60 % 60, total % 60)
            : String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Reads "1:30", "90" (seconds) or "1.5" (minutes) into seconds.
    static func parseClock(_ text: String) -> TimeInterval? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return 0 }
        let parts = trimmed.split(separator: ":").map { Double($0.trimmingCharacters(in: .whitespaces)) }
        if parts.contains(where: { $0 == nil }) { return nil }
        let numbers = parts.compactMap { $0 }
        switch numbers.count {
        case 1: return trimmed.contains(".") ? numbers[0] * 60 : numbers[0]
        case 2: return numbers[0] * 60 + numbers[1]
        case 3: return numbers[0] * 3600 + numbers[1] * 60 + numbers[2]
        default: return nil
        }
    }

}
