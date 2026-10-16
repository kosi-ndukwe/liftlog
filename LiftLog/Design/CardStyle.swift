import SwiftUI

/// A rounded, slightly lighter panel on the dark background. No border or shadow.
struct CardStyle: ViewModifier {
    var fill: Color = Palette.card
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension View {
    func card(fill: Color = Palette.card, padding: CGFloat = 16) -> some View {
        modifier(CardStyle(fill: fill, padding: padding))
    }

    /// The dark app background behind a scrolling screen.
    func screenBackground() -> some View {
        background(Palette.background.ignoresSafeArea())
    }
}

/// A round 44pt button with an icon, for the top corners of a screen.
struct RoundIconButton: View {
    let systemImage: String
    var tint: Color = Palette.textPrimary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(Palette.card, in: Circle())
        }
        .buttonStyle(.plain)
    }
}

/// A full-width, pill-shaped button: "Start Workout".
struct PillButtonStyle: ButtonStyle {
    var fill: Color = Palette.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .bold).italic())
            .foregroundStyle(Palette.textOnAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(fill.opacity(configuration.isPressed ? 0.7 : 1), in: Capsule())
    }
}
