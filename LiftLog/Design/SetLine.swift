import SwiftUI

/// One set on one line: "10 reps x 135 lb". Optionally numbered with a
/// hexagon badge, the way an exercise's history shows its working sets.
struct SetLine: View {
    let text: String
    /// Set number shown in a badge; nil for no badge.
    var number: Int? = nil
    var isWarmup = false
    /// Text at the trailing edge, for example an estimated 1RM.
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            if let number {
                HexBadge(text: "\(number)")
            }
            Text(text)
                .font(.setLine)
                .foregroundStyle(isWarmup ? Palette.textMuted : (number == nil ? Palette.textSecondary : Palette.textPrimary))
            if isWarmup {
                Text("warm-up")
                    .font(.caption)
                    .foregroundStyle(Palette.textMuted)
            }
            Spacer(minLength: 0)
            if let trailing {
                Text(trailing)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }
}

/// A small hexagon with text or a symbol inside, used for set numbers and "done" marks.
struct HexBadge: View {
    var text: String? = nil
    var systemImage: String? = nil
    var fill: Color = Palette.cardRaised
    var foreground: Color = Palette.textPrimary
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            Hexagon()
                .fill(fill)
                .frame(width: size, height: size)
            if let text {
                Text(text)
                    .font(.system(size: size * 0.5, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(foreground)
            } else if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.45, weight: .bold))
                    .foregroundStyle(foreground)
            }
        }
    }
}

/// A pointy-top hexagon.
struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        for index in 0..<6 {
            let angle = Double(index) * .pi / 3 - .pi / 2
            let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

/// A rounded square with a symbol, standing in for an exercise photo.
struct ExerciseThumbnail: View {
    let exercise: Exercise?
    var size: CGFloat = 56

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Palette.cardRaised)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: exercise?.symbolName ?? "figure.strengthtraining.traditional")
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
            }
    }
}
