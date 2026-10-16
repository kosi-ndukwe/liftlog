import SwiftData
import SwiftUI

/// The Log tab: past workouts on a timeline, newest first. Tap one for details.
struct HistoryView: View {
    @Query(sort: \WorkoutSession.start, order: .reverse) private var sessions: [WorkoutSession]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    header
                    if sessions.isEmpty {
                        ContentUnavailableView(
                            "No Workouts Yet",
                            systemImage: "calendar",
                            description: Text("Finished workouts and imported Fitbod history will appear here.")
                        )
                        .card()
                        .padding(.horizontal, 16)
                    } else {
                        ForEach(sessions) { session in
                            TimelineEntry(session: session)
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: WorkoutSession.self) { WorkoutDetailView(session: $0) }
            .navigationDestination(for: Exercise.self) { ExerciseDetailView(exercise: $0) }
            .navigationDestination(for: LogRoute.self) { _ in MusclesView() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Log")
                .font(.sectionTitle)
                .foregroundStyle(Palette.textPrimary)
                .padding(.top, 8)

            StatStrip([
                StatTile(label: "Workouts", value: sessions.count.formatted()),
                StatTile(label: "This week", value: "\(thisWeek.count)"),
                StatTile(label: "This year", value: thisYear.formatted()),
            ])
            .card()

            WeekStrip(workoutDays: thisWeek)

            NavigationLink(value: LogRoute.muscles) {
                MusclesCard(sessions: thisWeekSessions)
            }
            .buttonStyle(.plain)

            Text("Past Workouts")
                .font(.sectionTitle)
                .foregroundStyle(Palette.textPrimary)
                .padding(.top, 8)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    /// Workouts since the start of this week (the list is newest first).
    private var thisWeekSessions: [WorkoutSession] {
        guard let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start else { return [] }
        return Array(sessions.prefix { $0.start >= weekStart })
    }

    /// The days this week that had a workout.
    private var thisWeek: Set<Int> {
        Set(thisWeekSessions.map { Calendar.current.component(.weekday, from: $0.start) })
    }

    private var thisYear: Int {
        let calendar = Calendar.current
        guard let yearStart = calendar.dateInterval(of: .year, for: .now)?.start else { return 0 }
        return sessions.prefix { $0.start >= yearStart }.count
    }
}

enum LogRoute: Hashable {
    case muscles
}

/// SU MO TU WE TH FR SA with today bold and a dot under days you trained.
private struct WeekStrip: View {
    let workoutDays: Set<Int>

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.component(.weekday, from: .now)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { offset in
                let date = calendar.date(byAdding: .day, value: offset, to: weekStart) ?? weekStart
                let weekday = calendar.component(.weekday, from: date)
                VStack(spacing: 8) {
                    Text(date.formatted(.dateTime.weekday(.short)).uppercased())
                        .font(.system(size: 12, weight: weekday == today ? .bold : .medium))
                        .foregroundStyle(weekday == today ? Palette.textPrimary : Palette.textSecondary)
                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(size: 17, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(weekday > today ? Palette.textMuted : Palette.textPrimary)
                    Circle()
                        .fill(workoutDays.contains(weekday) ? Palette.done : .clear)
                        .frame(width: 6, height: 6)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .card(padding: 12)
    }
}

/// One workout on the timeline: a date header on the line, then the card.
private struct TimelineEntry: View {
    let session: WorkoutSession

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // The vertical line with a dot at the date.
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(Palette.hairline)
                    .frame(width: 1)
                Circle()
                    .fill(Palette.textMuted)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
            }
            .frame(width: 24)
            .padding(.leading, 16)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(DateHeading.timelineText(for: session.start))
                        .statLabelStyle()
                    Spacer()
                    if let duration = session.duration, duration > 0 {
                        Text(formattedDuration(duration))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                NavigationLink(value: session) {
                    WorkoutCard(session: session)
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 4)
            .padding(.trailing, 16)
            .padding(.bottom, 20)
        }
    }
}

/// Title, three stats and the exercises done.
struct WorkoutCard: View {
    let session: WorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                MuscleGroupBadge(group: session.group, size: 40)
                Text(session.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(2)
            }
            StatStrip([
                StatTile(label: "Exercises", value: "\(session.exerciseNames.count)"),
                StatTile(label: "Sets", value: "\(session.setCount)"),
                StatTile(label: "Volume", value: formattedWhole(session.volumeLb), unit: "lb"),
            ])
            if !session.exerciseSummary.isEmpty {
                Text(session.exerciseSummary)
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(2)
            }
        }
        .card()
    }
}

#Preview {
    HistoryView()
        .modelContainer(PreviewData.container)
        .preferredColorScheme(.dark)
}
