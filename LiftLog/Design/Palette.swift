import SwiftUI

/// The app's colours, named by what they're for rather than what they look like.
///
/// The app runs dark by default (see `LiftLogApp`), but every token has a light
/// value too so nothing breaks if that changes.
enum Palette {
    /// The screen behind everything.
    static let background = dynamic(dark: 0x131319, light: 0xF4F4F7)
    /// Cards and grouped rows.
    static let card = dynamic(dark: 0x1F1F27, light: 0xFFFFFF)
    /// A card inside a card, or a pressed / selected pill.
    static let cardRaised = dynamic(dark: 0x2C2C36, light: 0xE9E9EF)
    /// Thin separators.
    static let hairline = dynamic(dark: 0x2E2E39, light: 0xDCDCE3)

    /// The one highlight colour: active tab, chart lines, "+" buttons.
    static let accent = dynamic(dark: 0xF0405E, light: 0xE0304E)
    /// A finished set.
    static let done = dynamic(dark: 0x8EE8C8, light: 0x1FA67A)
    /// A personal record.
    static let record = dynamic(dark: 0xFCF3A0, light: 0xE0B800)
    /// The pale fill behind a record banner.
    static let recordFill = dynamic(dark: 0xFCF3A0, light: 0xFFF6B3)

    static let textPrimary = dynamic(dark: 0xFFFFFF, light: 0x111115)
    static let textSecondary = dynamic(dark: 0x9A9AAA, light: 0x6B6B78)
    static let textMuted = dynamic(dark: 0x6E6E7C, light: 0x9A9AA6)
    /// Text on top of `accent` or `recordFill`.
    static let textOnAccent = Color.white
    static let textOnRecord = dynamic(dark: 0x1A1A10, light: 0x1A1A10)

    /// A colour that picks its value from the current light / dark setting.
    private static func dynamic(dark: UInt32, light: UInt32) -> Color {
        Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    /// `UIColor(hex: 0xF0405E)`.
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
