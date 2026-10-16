import Foundation
import SwiftData

/// Sample data for Xcode previews. Never used by the real app.
@MainActor
enum PreviewData {
    static let container: ModelContainer = {
        do {
            let container = try LiftLogSchema.makeInMemoryContainer()
            let context = container.mainContext

            let bench = Exercise(name: "Barbell Bench Press")
            let press = Exercise(name: "Barbell Shoulder Press")
            let pushdown = Exercise(name: "Cable Tricep Pushdown")

            let push = Routine(name: "Push Day")
            context.insert(push)
            [bench, press, pushdown].forEach(push.append)

            // Sixteen weekly push days, getting a little stronger each week.
            for week in 0..<16 {
                let start = Date.now.addingTimeInterval(-Double(15 - week) * 7 * 86_400)
                let session = WorkoutSession(start: start, end: start.addingTimeInterval(3_600), routine: push)
                context.insert(session)
                var order = 0
                for (exercise, top) in [(bench, 175.0), (press, 95.0), (pushdown, 50.0)] {
                    let warmup = SetEntry(order: order, exercise: exercise, reps: 10, isWarmup: true)
                    warmup.weightLb = (top * 0.6).rounded()
                    session.sets.append(warmup)
                    order += 1
                    for _ in 0..<3 {
                        let set = SetEntry(order: order, exercise: exercise, reps: 8)
                        set.weightLb = top + Double(week / 2) * 5
                        session.sets.append(set)
                        order += 1
                    }
                }
            }

            return container
        } catch {
            fatalError("Couldn't create preview data: \(error)")
        }
    }()
}
