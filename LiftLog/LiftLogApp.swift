import SwiftData
import SwiftUI

@main
struct LiftLogApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Creates the on-device database and shares it with every screen.
        .modelContainer(for: LiftLogSchema.models)
    }
}
