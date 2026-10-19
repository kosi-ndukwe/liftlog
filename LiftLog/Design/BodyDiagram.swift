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

/// The shapes that make up the diagram, in a 200 × 440 space. Everything is
/// drawn as smooth bezier curves through a few hand-placed points, on the left
/// half of the body and mirrored across x = 100 where it should be symmetric.
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

    private typealias Pt = (CGFloat, CGFloat)

    /// A smooth closed curve through the points (Catmull-Rom as cubic beziers).
    private static func blob(_ pts: [Pt]) -> Path {
        let p = pts.map { CGPoint(x: $0.0, y: $0.1) }
        let n = p.count
        var path = Path()
        guard n > 2 else { return path }
        path.move(to: p[0])
        for i in 0..<n {
            let p0 = p[(i + n - 1) % n], p1 = p[i], p2 = p[(i + 1) % n], p3 = p[(i + 2) % n]
            path.addCurve(
                to: p2,
                control1: CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6),
                control2: CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            )
        }
        path.closeSubpath()
        return path
    }

    /// A closed shape given by its left half, top to bottom along the centre line.
    private static func symmetric(_ half: [Pt]) -> Path {
        blob(half + half.dropFirst().dropLast().reversed().map { (width - $0.0, $0.1) })
    }

    private static func rounded(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> Path {
        Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r)
    }

    private static func join(_ paths: Path...) -> Path {
        var all = Path()
        for path in paths { all.addPath(path) }
        return all
    }

    /// The same shape on the left and right of the body.
    private static func mirrored(_ path: Path) -> Path {
        var both = path
        both.addPath(path.applying(CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: -width, y: 0)))
        return both
    }

    /// One smooth outline: head, neck, shoulders, arms held slightly away from
    /// the body, torso tapering to the waist, hips, legs and feet. Same from
    /// both sides.
    static func silhouette(_ side: BodyDiagram.Side) -> Path {
        // Left half, from the top of the head down the outside of the body and
        // back up the inside to the crotch.
        let half: [Pt] = [
            (100, 4), (90, 7), (84, 20), (87, 36), (93, 45),            // head
            (93, 55), (82, 60), (64, 65), (47, 71), (38, 82),          // neck, trapezius, shoulder
            (32, 106), (26, 136), (21, 168), (17, 196), (13, 230),     // outer arm
            (12, 248), (8, 264), (9, 278), (16, 284), (22, 276),       // hand
            (24, 260), (27, 246), (33, 224), (40, 190), (45, 166),     // inner forearm
            (49, 138), (54, 112), (57, 100),                           // inner arm to the armpit
            (60, 124), (63, 150), (67, 172), (65, 192), (60, 212),     // torso side to the hip
            (55, 236), (56, 266), (58, 296), (61, 322), (62, 344),     // outer leg to the knee
            (60, 368), (62, 394), (67, 418), (64, 430), (68, 438),     // calf, ankle, heel
            (94, 438), (93, 428), (92, 418), (92, 394), (94, 368),     // foot, inner calf
            (92, 344), (93, 322), (95, 296), (97, 266), (100, 238),    // inner leg to the crotch
        ]
        return symmetric(half)
    }

    // MARK: Front

    private static let front: [Region] = {
        let delt = blob([(52, 74), (63, 71), (66, 82), (61, 96), (54, 105), (50, 97), (51, 86)])
        let sideDelt = blob([(48, 75), (42, 83), (40, 97), (44, 108), (47, 98), (48, 86)])
        let pec = blob([(99, 78), (84, 74), (70, 77), (65, 90), (68, 106), (80, 116), (92, 118), (99, 112)])
        let bicep = blob([(50, 114), (43, 117), (38, 130), (36, 148), (39, 160), (44, 157), (46, 143), (49, 127)])
        let forearm = blob([(40, 168), (33, 168), (25, 177), (20, 198), (16, 226), (16, 242), (21, 242), (26, 226), (34, 204), (40, 184)])
        let abs = join(
            rounded(85, 122, 14, 16, 5), rounded(84, 141, 15, 16, 5), rounded(85, 160, 14, 16, 5)
        )
        let oblique = blob([(81, 124), (73, 127), (67, 142), (65, 162), (66, 180), (72, 190), (80, 190), (81, 172), (82, 148)])
        let hipFlexor = blob([(74, 194), (98, 198), (98, 214), (88, 224), (77, 214), (71, 202)])
        let abductor = blob([(63, 204), (69, 208), (70, 228), (66, 250), (60, 250), (59, 226)])
        let quad = blob([(74, 228), (83, 230), (88, 246), (89, 268), (90, 296), (91, 312), (86, 326), (77, 331), (70, 320), (65, 296), (62, 266), (64, 242)])
        let adductor = blob([(97, 240), (96, 262), (93, 290), (91, 300), (89, 290), (90, 262), (90, 246)])
        let calf = blob([(72, 350), (84, 350), (89, 366), (87, 388), (83, 410), (76, 414), (69, 398), (64, 372), (66, 356)])
        return [
            Region(muscle: .frontDelts, path: mirrored(delt)),
            Region(muscle: .sideDelts, path: mirrored(sideDelt)),
            Region(muscle: .chest, path: mirrored(pec)),
            Region(muscle: .biceps, path: mirrored(bicep)),
            Region(muscle: .forearms, path: mirrored(forearm)),
            Region(muscle: .abs, path: mirrored(abs)),
            Region(muscle: .obliques, path: mirrored(oblique)),
            Region(muscle: .hipFlexors, path: mirrored(hipFlexor)),
            Region(muscle: .abductors, path: mirrored(abductor)),
            Region(muscle: .quads, path: mirrored(quad)),
            Region(muscle: .adductors, path: mirrored(adductor)),
            Region(muscle: .calves, path: mirrored(calf)),
        ]
    }()

    // MARK: Back

    private static let back: [Region] = {
        let trap = symmetric([(100, 54), (88, 60), (70, 68), (77, 84), (89, 100), (100, 120)])
        let delt = blob([(52, 74), (63, 71), (66, 82), (61, 96), (54, 105), (50, 97), (51, 86)])
        let sideDelt = blob([(48, 75), (42, 83), (40, 97), (44, 108), (47, 98), (48, 86)])
        let upperBack = blob([(63, 90), (70, 88), (80, 100), (87, 112), (91, 124), (78, 126), (66, 118), (61, 104)])
        let lat = blob([(62, 124), (72, 130), (86, 138), (91, 156), (90, 178), (88, 198), (78, 196), (68, 180), (64, 150)])
        let lowerBack = symmetric([(100, 142), (95, 152), (95, 178), (93, 204), (100, 214)])
        let tricep = blob([(50, 108), (42, 112), (37, 130), (35, 150), (38, 164), (44, 160), (46, 142), (49, 124)])
        let forearm = blob([(40, 168), (33, 168), (25, 177), (20, 198), (16, 226), (16, 242), (21, 242), (26, 226), (34, 204), (40, 184)])
        let glute = blob([(98, 220), (86, 216), (72, 219), (62, 232), (63, 252), (78, 262), (94, 258), (99, 240)])
        let hamstring = blob([(74, 266), (86, 266), (93, 280), (94, 306), (90, 326), (79, 331), (68, 322), (62, 298), (62, 278)])
        let calfOuter = blob([(65, 350), (76, 348), (77, 372), (74, 396), (70, 404), (64, 388), (62, 364)])
        let calfInner = blob([(79, 348), (90, 350), (92, 366), (89, 390), (84, 402), (79, 392), (78, 370)])
        return [
            Region(muscle: .traps, path: trap),
            Region(muscle: .rearDelts, path: mirrored(delt)),
            Region(muscle: .sideDelts, path: mirrored(sideDelt)),
            Region(muscle: .upperBack, path: mirrored(upperBack)),
            Region(muscle: .lats, path: mirrored(lat)),
            Region(muscle: .lowerBack, path: lowerBack),
            Region(muscle: .triceps, path: mirrored(tricep)),
            Region(muscle: .forearms, path: mirrored(forearm)),
            Region(muscle: .glutes, path: mirrored(glute)),
            Region(muscle: .hamstrings, path: mirrored(hamstring)),
            Region(muscle: .calves, path: mirrored(join(calfOuter, calfInner))),
        ]
    }()
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
