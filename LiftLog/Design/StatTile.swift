import SwiftUI

/// A small-caps label with a number under it: "VOLUME / 30,710 lb".
struct StatTile: View {
    let label: String
    let value: String
    /// Shown smaller after the value: "lb", "kCal".
    var unit: String? = nil
    var alignment: HorizontalAlignment = .center

    var body: some View {
        VStack(alignment: alignment, spacing: 6) {
            Text(label)
                .statLabelStyle()
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.statSmallValue)
                    .foregroundStyle(Palette.textPrimary)
                if let unit {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Two or three `StatTile`s in a row, separated by hairlines.
struct StatStrip: View {
    let tiles: [StatTile]

    init(_ tiles: [StatTile]) {
        self.tiles = tiles
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tiles.enumerated()), id: \.offset) { index, tile in
                if index > 0 {
                    Rectangle()
                        .fill(Palette.hairline)
                        .frame(width: 1, height: 36)
                }
                tile
            }
        }
    }
}

/// The headline number on a card: a huge value with its unit beside it,
/// and a line underneath saying when it was logged.
struct BigStat: View {
    let value: String
    var unit: String? = nil
    var footnote: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(value)
                    .font(.statValue)
                    .foregroundStyle(Palette.textPrimary)
                if let unit {
                    Text(unit)
                        .font(.bodyText)
                        .foregroundStyle(Palette.textPrimary)
                }
            }
            if let footnote {
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }
}
