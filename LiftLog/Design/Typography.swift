import SwiftUI

/// The handful of text styles the app uses. Big italic headings and big
/// numbers are what give the screens their look, so reach for these rather
/// than ad-hoc fonts.
extension Font {
    /// A workout's name on its own screen: "back day".
    static let heroTitle = Font.system(size: 38, weight: .black).italic()
    /// A screen or section heading: "Past Workouts", "8 Exercises".
    static let sectionTitle = Font.system(size: 28, weight: .black).italic()
    /// A smaller heading, for example a date inside a list: "Monday, Oct 12".
    static let subsectionTitle = Font.system(size: 22, weight: .black).italic()
    /// The headline number on a card: "79.4".
    static let statValue = Font.system(size: 48, weight: .black).italic().monospacedDigit()
    /// A number in a stat strip: "30,710 lb".
    static let statSmallValue = Font.system(size: 20, weight: .semibold).monospacedDigit()
    /// The small-caps label above a stat: "VOLUME".
    static let statLabel = Font.system(size: 12, weight: .medium)
    /// An exercise or routine name in a list.
    static let rowTitle = Font.system(size: 18, weight: .semibold)
    /// "10 reps x 135 lb".
    static let setLine = Font.system(size: 17, weight: .regular).monospacedDigit()
    /// Ordinary text.
    static let bodyText = Font.system(size: 16, weight: .regular)
    /// Smaller supporting text.
    static let caption = Font.system(size: 14, weight: .regular)
}

extension View {
    /// Spaced-out capitals for stat labels.
    func statLabelStyle() -> some View {
        font(.statLabel)
            .textCase(.uppercase)
            .tracking(1.5)
            .foregroundStyle(Palette.textSecondary)
    }
}
