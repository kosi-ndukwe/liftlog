import Foundation

/// Converts between kg (how weights are stored) and lb (how they're shown).
enum Weight {
    static let kgPerPound = 0.45359237

    static func pounds(fromKg kg: Double) -> Double {
        kg / kgPerPound
    }

    static func kg(fromPounds pounds: Double) -> Double {
        pounds * kgPerPound
    }

    static func roundedToHalfPound(_ pounds: Double) -> Double {
        (pounds * 2).rounded() / 2
    }

    /// "135 lb" or "137.5 lb".
    static func formattedPounds(fromKg kg: Double) -> String {
        let pounds = roundedToHalfPound(pounds(fromKg: kg))
        return pounds.formatted(.number.precision(.fractionLength(0...1))) + " lb"
    }
}
