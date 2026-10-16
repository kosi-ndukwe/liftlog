import SwiftUI

/// A simple front or back view of a body, drawn by the app itself, with each
/// muscle a separate region that can be shaded. `shading` maps a muscle to
/// 0…1 (how much it was trained); muscles not in the map stay unshaded.
struct BodyDiagram: View {
    enum Side { case front, back }

    let side: Side
    var shading: [Muscle: Double] = [:]
    var tint: Color = Palette.accent
    var base: Color = Palette.cardRaised

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / BodyShapes.width, size.height / BodyShapes.height)
            let offset = CGSize(
                width: (size.width - BodyShapes.width * scale) / 2,
                height: (size.height - BodyShapes.height * scale) / 2
            )
            var transform = CGAffineTransform(translationX: offset.width, y: offset.height)
            transform = transform.scaledBy(x: scale, y: scale)

            // The body outline, then each muscle on top.
            context.fill(BodyShapes.silhouette(side).applying(transform), with: .color(base.opacity(0.55)))
            for region in BodyShapes.regions(for: side) {
                let path = region.path.applying(transform)
                if let amount = shading[region.muscle], amount > 0 {
                    context.fill(path, with: .color(tint.opacity(0.3 + 0.7 * min(amount, 1))))
                } else {
                    context.fill(path, with: .color(base))
                }
                // A thin dark edge keeps neighbouring muscles apart.
                context.stroke(path, with: .color(Palette.background.opacity(0.8)), lineWidth: 1.2)
            }
        }
        .aspectRatio(BodyShapes.width / BodyShapes.height, contentMode: .fit)
        .accessibilityLabel(side == .front ? "Front of body" : "Back of body")
    }
}

/// Front and back side by side.
struct BodyPair: View {
    var shading: [Muscle: Double] = [:]
    var tint: Color = Palette.accent

    var body: some View {
        HStack(spacing: 24) {
            BodyDiagram(side: .front, shading: shading, tint: tint)
            BodyDiagram(side: .back, shading: shading, tint: tint)
        }
    }
}

/// A small rounded square showing the side of the body where the exercise's
/// main muscles are, with those muscles lit up. Stands in for a photo.
struct MuscleThumbnail: View {
    let exercise: Exercise
    var size: CGFloat = 56

    var body: some View {
        let primary = exercise.primary
        let shading = Dictionary(uniqueKeysWithValues: primary.map { ($0, 1.0) })
            .merging(exercise.secondary.map { ($0, 0.4) }, uniquingKeysWith: max)
        let side: BodyDiagram.Side = BodyShapes.isMostlyOnBack(primary) ? .back : .front
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Palette.card)
            .frame(width: size, height: size)
            .overlay {
                if primary.isEmpty {
                    Image(systemName: exercise.symbolName)
                        .font(.system(size: size * 0.42, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                } else {
                    BodyDiagram(side: side, shading: shading, tint: .white, base: Palette.cardRaised)
                        .padding(size * 0.1)
                }
            }
    }
}

/// The shapes that make up the diagram, in a 200 × 440 space.
enum BodyShapes {
    static let width: CGFloat = 200
    static let height: CGFloat = 440

    struct Region {
        let muscle: Muscle
        let path: Path
    }

    /// Muscles you see from behind.
    static let backMuscles: Set<Muscle> = [.traps, .rearDelts, .upperBack, .lats, .lowerBack, .triceps, .glutes, .hamstrings, .calves]

    static func isMostlyOnBack(_ muscles: [Muscle]) -> Bool {
        let back = muscles.filter(backMuscles.contains).count
        return back > muscles.count - back
    }

    static func regions(for side: BodyDiagram.Side) -> [Region] {
        side == .front ? front : back
    }

    // MARK: Building blocks

    private static func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ h: CGFloat, rotation: CGFloat = 0) -> Path {
        var path = Path(ellipseIn: CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
        path = path.applying(CGAffineTransform(rotationAngle: rotation * .pi / 180))
        return path.applying(CGAffineTransform(translationX: cx, y: cy))
    }

    private static func rounded(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> Path {
        Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r)
    }

    private static func polygon(_ points: [(CGFloat, CGFloat)]) -> Path {
        var path = Path()
        for (index, point) in points.enumerated() {
            index == 0 ? path.move(to: CGPoint(x: point.0, y: point.1)) : path.addLine(to: CGPoint(x: point.0, y: point.1))
        }
        path.closeSubpath()
        return path
    }

    /// The same shape on the left and right of the body.
    private static func mirrored(_ path: Path) -> Path {
        var both = path
        both.addPath(path.applying(CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: -width, y: 0)))
        return both
    }

    /// Head, torso, arms and legs behind the muscles. Same from both sides.
    static func silhouette(_ side: BodyDiagram.Side) -> Path {
        var path = Path()
        path.addPath(ellipse(100, 30, 44, 50))                          // head
        path.addPath(rounded(90, 50, 20, 20, 6))                        // neck
        path.addPath(polygon([(54, 64), (146, 64), (136, 215), (64, 215)]))  // torso
        path.addPath(mirrored(ellipse(44, 140, 30, 110, rotation: 12)))   // upper arms
        path.addPath(mirrored(ellipse(30, 220, 24, 90, rotation: 10)))    // forearms
        path.addPath(mirrored(ellipse(24, 272, 18, 26, rotation: 10)))    // hands
        path.addPath(mirrored(rounded(62, 205, 40, 150, 18)))             // thighs
        path.addPath(mirrored(rounded(64, 340, 34, 90, 14)))              // lower legs
        path.addPath(mirrored(rounded(62, 422, 36, 16, 6)))               // feet
        return path
    }

    // MARK: Front

    private static let front: [Region] = [
        Region(muscle: .frontDelts, path: mirrored(ellipse(60, 84, 24, 26))),
        Region(muscle: .sideDelts, path: mirrored(ellipse(46, 92, 14, 26, rotation: 15))),
        Region(muscle: .chest, path: mirrored(polygon([(68, 76), (100, 80), (100, 118), (76, 124), (64, 110)]))),
        Region(muscle: .biceps, path: mirrored(ellipse(46, 148, 18, 54, rotation: 12))),
        Region(muscle: .forearms, path: mirrored(ellipse(31, 222, 16, 70, rotation: 10))),
        Region(muscle: .abs, path: rounded(84, 128, 32, 64, 8)),
        Region(muscle: .obliques, path: mirrored(polygon([(68, 126), (80, 128), (80, 192), (72, 196), (64, 170)]))),
        Region(muscle: .hipFlexors, path: mirrored(polygon([(74, 199), (98, 197), (97, 211), (76, 212)]))),
        Region(muscle: .quads, path: mirrored(ellipse(78, 266, 28, 100))),
        Region(muscle: .adductors, path: mirrored(ellipse(96, 242, 10, 54))),
        Region(muscle: .abductors, path: mirrored(ellipse(60, 228, 10, 40))),
        Region(muscle: .calves, path: mirrored(ellipse(80, 384, 22, 70))),
    ]

    // MARK: Back

    private static let back: [Region] = [
        Region(muscle: .traps, path: polygon([(100, 56), (134, 72), (112, 112), (100, 122), (88, 112), (66, 72)])),
        Region(muscle: .rearDelts, path: mirrored(ellipse(58, 86, 22, 26))),
        Region(muscle: .sideDelts, path: mirrored(ellipse(45, 92, 14, 26, rotation: 15))),
        Region(muscle: .upperBack, path: mirrored(polygon([(68, 78), (86, 90), (86, 122), (66, 118)]))),
        Region(muscle: .lats, path: mirrored(polygon([(64, 122), (84, 128), (96, 146), (88, 198), (76, 196), (62, 160)]))),
        Region(muscle: .lowerBack, path: rounded(90, 150, 20, 56, 8)),
        Region(muscle: .triceps, path: mirrored(ellipse(46, 148, 18, 54, rotation: 12))),
        Region(muscle: .forearms, path: mirrored(ellipse(31, 222, 16, 70, rotation: 10))),
        Region(muscle: .glutes, path: mirrored(ellipse(80, 236, 36, 50))),
        Region(muscle: .hamstrings, path: mirrored(ellipse(79, 300, 30, 90))),
        Region(muscle: .calves, path: mirrored(ellipse(80, 384, 24, 74))),
    ]
}

#Preview {
    VStack {
        BodyPair(shading: [.chest: 1, .frontDelts: 0.6, .triceps: 0.4, .lats: 0.8, .quads: 0.2])
            .frame(height: 320)
        BodyPair()
            .frame(height: 160)
    }
    .padding()
    .background(Palette.background)
    .preferredColorScheme(.dark)
}
