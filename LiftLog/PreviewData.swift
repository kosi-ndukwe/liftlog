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

            let session = WorkoutSession(start: .now.addingTimeInterval(-86_400), routine: push)
            session.end = session.start.addingTimeInterval(3_600)
            context.insert(session)
            for (order, pounds) in [135.0, 155, 175].enumerated() {
                let set = SetEntry(order: order, exercise: bench, reps: 8)
                set.weightLb = pounds
                session.sets.append(set)
            }

            return container
        } catch {
            fatalError("Couldn't create preview data: \(error)")
        }
    }()
}
