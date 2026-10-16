import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Fitbod import. Managing routines and exercises comes in a later milestone.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var isPickingFile = false
    @State private var importState = ImportState.idle
    @AppStorage("restSeconds") private var restSeconds = 90

    enum ImportState {
        case idle
        case importing
        case finished(FitbodImportSummary)
        case failed(String)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Settings")
                        .font(.sectionTitle)
                        .foregroundStyle(Palette.textPrimary)
                        .padding(.top, 8)

                    Text("Data")
                        .statLabelStyle()
                    VStack(alignment: .leading, spacing: 14) {
                        Button {
                            isPickingFile = true
                        } label: {
                            Label("Import Fitbod CSV", systemImage: "square.and.arrow.down")
                                .font(.rowTitle)
                                .foregroundStyle(isImporting ? Palette.textMuted : Palette.accent)
                        }
                        .disabled(isImporting)
                        importStatus
                        Text("Export your workout history from Fitbod as a CSV file and save it to Files. Importing again later only adds new workouts.")
                            .font(.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    .card()

                    Text("Workouts")
                        .statLabelStyle()
                    HStack {
                        Text("Rest timer")
                            .font(.bodyText)
                            .foregroundStyle(Palette.textPrimary)
                        Spacer()
                        Picker("Rest timer", selection: $restSeconds) {
                            Text("Off").tag(0)
                            Text("1:00").tag(60)
                            Text("1:30").tag(90)
                            Text("2:00").tag(120)
                            Text("3:00").tag(180)
                        }
                        .tint(Palette.accent)
                    }
                    .card()
                    Text("Starts counting down each time you tick a set off.")
                        .font(.caption)
                        .foregroundStyle(Palette.textSecondary)

                    Text("Units")
                        .statLabelStyle()
                    HStack {
                        Text("Weight")
                            .font(.bodyText)
                            .foregroundStyle(Palette.textPrimary)
                        Spacer()
                        Text("lb")
                            .font(.bodyText)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    .card()

                    Text("About")
                        .statLabelStyle()
                    HStack {
                        Text("Version")
                            .font(.bodyText)
                            .foregroundStyle(Palette.textPrimary)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                            .font(.bodyText)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    .card()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .fileImporter(
                isPresented: $isPickingFile,
                allowedContentTypes: [.commaSeparatedText, .plainText]
            ) { result in
                switch result {
                case .success(let url):
                    startImport(from: url)
                case .failure(let error):
                    importState = .failed(error.localizedDescription)
                }
            }
        }
    }

    private var isImporting: Bool {
        if case .importing = importState { true } else { false }
    }

    @ViewBuilder
    private var importStatus: some View {
        switch importState {
        case .idle:
            EmptyView()
        case .importing:
            HStack {
                ProgressView()
                Text("Importing…")
                    .foregroundStyle(Palette.textSecondary)
            }
        case .finished(let summary):
            Text(Self.describe(summary))
                .font(.caption)
                .foregroundStyle(Palette.textPrimary)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(Palette.accent)
        }
    }

    private func startImport(from url: URL) {
        importState = .importing
        let container = modelContext.container
        Task {
            do {
                // Created off the main thread so the import really runs in the background.
                let summary = try await Task.detached {
                    try await FitbodImporter(modelContainer: container).importFile(at: url)
                }.value
                importState = .finished(summary)
            } catch {
                importState = .failed(error.localizedDescription)
            }
        }
    }

    nonisolated static func describe(_ summary: FitbodImportSummary) -> String {
        var lines = [
            "Added \(count(summary.sessionsAdded, "workout")), \(count(summary.exercisesAdded, "exercise")) and \(count(summary.routinesAdded, "routine"))."
        ]
        if summary.sessionsAlreadyImported > 0 {
            lines.append("\(count(summary.sessionsAlreadyImported, "workout")) already imported.")
        }
        if summary.linesSkipped > 0 {
            lines.append("\(count(summary.linesSkipped, "line")) couldn't be read and skipped.")
        }
        return lines.joined(separator: "\n")
    }

    /// "1 workout", "2 workouts", "1,234 workouts".
    private nonisolated static func count(_ number: Int, _ noun: String) -> String {
        "\(number.formatted()) \(noun)\(number == 1 ? "" : "s")"
    }
}

#Preview {
    SettingsView()
        .modelContainer(PreviewData.container)
        .preferredColorScheme(.dark)
}
