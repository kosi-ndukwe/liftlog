import SwiftUI

/// Fitbod import and routine management come in later milestones.
struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Data") {
                    Label("Import Fitbod CSV", systemImage: "square.and.arrow.down")
                        .foregroundStyle(.secondary)
                }
                Section("Units") {
                    LabeledContent("Weight", value: "lb")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
