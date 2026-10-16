import Foundation
import SwiftData
import Testing
@testable import LiftLog

struct StrengthTests {
    @Test func epleyEstimate() throws {
        #expect(Strength.estimatedOneRepMax(pounds: 300, reps: 1) == 300)
        let estimate = try #require(Strength.estimatedOneRepMax(pounds: 185, reps: 8))
        #expect(abs(estimate - 234.33) < 0.01)
    }

    @Test func skipsSetsTheEstimateCantUse() {
        #expect(Strength.estimatedOneRepMax(pounds: 100, reps: 13) == nil)
        #expect(Strength.estimatedOneRepMax(pounds: 100, reps: 0) == nil)
        #expect(Strength.estimatedOneRepMax(pounds: 0, reps: 10) == nil)
    }

    @Test func trendFollowsSteadyProgress() throws {
        // +1 lb every week for 12 weeks.
        let start = Date(timeIntervalSince1970: 1_790_000_000)
        let points = (0..<12).map { ChartPoint(date: start.addingTimeInterval(Double($0) * 7 * 86_400), value: 200 + Double($0)) }
        let trend = try #require(Strength.trend(points))

        #expect(abs(trend.perMonth - 30.44 / 7) < 0.01)
        #expect(abs(trend.startValue - 211) < 0.01)
        #expect(abs(trend.projectedValue - (211 + 90.0 / 7)) < 0.01)
    }

    @Test func noTrendWithoutEnoughData() {
        let start = Date(timeIntervalSince1970: 1_790_000_000)
        let fewPoints = (0..<3).map { ChartPoint(date: start.addingTimeInterval(Double($0) * 14 * 86_400), value: 200) }
        #expect(Strength.trend(fewPoints) == nil)

        let sameWeek = (0..<6).map { ChartPoint(date: start.addingTimeInterval(Double($0) * 86_400), value: 200) }
        #expect(Strength.trend(sameWeek) == nil)
    }

    @Test func trendIgnoresOldPoints() throws {
        let start = Date(timeIntervalSince1970: 1_790_000_000)
        // A year ago you were much weaker; the last 6 months are flat.
        var points = (0..<5).map { ChartPoint(date: start.addingTimeInterval(Double($0) * 7 * 86_400), value: 100) }
        let recentStart = start.addingTimeInterval(365 * 86_400)
        points += (0..<8).map { ChartPoint(date: recentStart.addingTimeInterval(Double($0) * 14 * 86_400), value: 250) }

        let trend = try #require(Strength.trend(points))
        #expect(abs(trend.perMonth) < 0.001)
    }
}

@MainActor
struct ExerciseHistoryTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try LiftLogSchema.makeInMemoryContainer()
    }

    @Test func usesBestWorkingSetPerWorkout() throws {
        let bench = Exercise(name: "Bench")
        context.insert(bench)
        let day1 = WorkoutSession(start: Date(timeIntervalSince1970: 1_790_000_000))
        let day2 = WorkoutSession(start: Date(timeIntervalSince1970: 1_790_604_800))
        context.insert(day1)
        context.insert(day2)
        for (session, sets) in [(day1, [(135.0, 10, true), (185, 8, false), (205, 3, false)]), (day2, [(190.0, 8, false)])] {
            for (order, (pounds, reps, warmup)) in sets.enumerated() {
                let set = SetEntry(order: order, exercise: bench, reps: reps, isWarmup: warmup)
                set.weightLb = pounds
                session.sets.append(set)
            }
        }
        try context.save()

        let history = ExerciseHistory(exercise: bench)
        #expect(history.metric == .oneRepMax)
        #expect(history.sessions.map(\.date) == [day2.start, day1.start])
        // Day 1: 185 × 8 ≈ 234.3 beats 205 × 3 = 225.5, and the 135 lb warm-up doesn't count.
        #expect(history.points.map { ($0.value * 10).rounded() / 10 } == [234.3, 240.7])
        #expect(history.best?.date == day2.start)
    }

    @Test func cardioChartsTime() throws {
        let cycling = Exercise(name: "Cycling")
        context.insert(cycling)
        let ride = WorkoutSession(start: .now)
        context.insert(ride)
        ride.sets.append(SetEntry(order: 0, exercise: cycling, durationSeconds: 1_800, distanceMeters: 8_046.72))
        try context.save()

        let history = ExerciseHistory(exercise: cycling)
        #expect(history.metric == .minutes)
        #expect(history.latest?.value == 30)
        #expect(ride.sets.first?.summary == "30 min · 5.0 mi")
    }

    @Test func formatsSets() {
        let set = SetEntry(order: 0, exercise: nil, reps: 8)
        set.weightLb = 135
        #expect(set.summary == "8 reps x 135 lb")
        #expect(SetEntry(order: 0, exercise: nil, reps: 15).summary == "15 reps")
    }
}
