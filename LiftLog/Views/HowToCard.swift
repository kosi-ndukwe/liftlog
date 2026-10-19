import SwiftUI

/// Photos of the start and end position, and the steps. Collapsed to the
/// photos until you tap "How to do it".
struct HowToCard: View {
    let exercise: Exercise
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !exercise.imageNames.isEmpty {
                HStack(spacing: 10) {
                    ForEach(exercise.imageNames.prefix(2), id: \.self) { name in
                        ExercisePhoto(name: name)
                    }
                }
            }
            if !exercise.instructions.isEmpty {
                Button {
                    withAnimation(.snappy(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    HStack {
                        Text("How to do it")
                            .font(.rowTitle)
                            .foregroundStyle(Palette.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Palette.textMuted)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                }
                .buttonStyle(.plain)
                if isExpanded {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                HexBadge(text: "\(index + 1)", size: 24)
                                Text(step)
                                    .font(.bodyText)
                                    .foregroundStyle(Palette.textSecondary)
                            }
                        }
                    }
                }
            }
        }
        .card()
    }
}

/// A bundled exercise photo, or nothing if the file is missing.
struct ExercisePhoto: View {
    let name: String

    var body: some View {
        if let image = Self.load(name) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .aspectRatio(3 / 2, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    static func load(_ name: String) -> UIImage? {
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension.isEmpty ? "jpg" : (name as NSString).pathExtension
        let url = Bundle.main.url(forResource: base, withExtension: ext, subdirectory: "ExerciseImages")
            ?? Bundle.main.url(forResource: base, withExtension: ext)
        return url.flatMap { UIImage(contentsOfFile: $0.path) }
    }
}
