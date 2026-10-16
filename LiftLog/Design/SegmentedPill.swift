import SwiftUI

/// A pill with two to four options; the chosen one gets a lighter pill behind it.
struct SegmentedPill<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> String
    @Namespace private var highlight

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation(.snappy(duration: 0.2)) { selection = option }
                } label: {
                    Text(label(option))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background {
                            if selection == option {
                                Capsule()
                                    .fill(Palette.cardRaised)
                                    .matchedGeometryEffect(id: "pill", in: highlight)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Palette.card, in: Capsule())
    }
}

/// A small rounded tag: "warm-up", "PR", a muscle group.
struct Tag: View {
    let text: String
    var fill: Color = Palette.cardRaised
    var foreground: Color = Palette.textSecondary

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(fill, in: Capsule())
    }
}
