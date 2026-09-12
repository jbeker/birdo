//
//  AmbientBackgroundView.swift
//  birdoSaver
//
//  A slowly drifting mesh gradient in muted dawn-sky tones. All motion
//  runs on sinusoids with periods of 40–90 seconds, so the background
//  breathes rather than animates.
//

import SwiftUI

struct AmbientBackgroundView: View {
    // A muted landscape, top to bottom: sky blues over forest greens over
    // earth browns. Each band cycles only within its own family so the
    // sky stays sky and the ground stays ground.
    private static let sky: [(Double, Double, Double)] = [
        (0.42, 0.56, 0.70),  // soft daylight blue
        (0.29, 0.42, 0.58),  // deeper blue
        (0.55, 0.66, 0.75),  // pale horizon blue
    ]
    private static let forest: [(Double, Double, Double)] = [
        (0.23, 0.35, 0.24),  // forest green
        (0.33, 0.43, 0.27),  // moss
        (0.17, 0.28, 0.21),  // pine shadow
    ]
    private static let earth: [(Double, Double, Double)] = [
        (0.36, 0.28, 0.20),  // soil
        (0.46, 0.37, 0.25),  // loam
        (0.27, 0.21, 0.16),  // dark humus
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 10)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            MeshGradient(
                width: 3,
                height: 3,
                points: Self.points(at: t),
                colors: Self.colors(at: t)
            )
        }
        .ignoresSafeArea()
    }

    /// 3×3 control points: corners pinned, edge midpoints sliding along
    /// their edges, center wandering. Keeps the mesh valid (no fold-overs).
    static func points(at t: TimeInterval) -> [SIMD2<Float>] {
        func drift(_ period: Double, _ phase: Double, _ amplitude: Double) -> Float {
            Float(amplitude * sin(t * 2 * .pi / period + phase))
        }
        return [
            [0, 0], [0.5 + drift(59, 0.0, 0.16), 0], [1, 0],
            [0, 0.5 + drift(71, 1.3, 0.16)],
            [0.5 + drift(43, 2.1, 0.14), 0.5 + drift(67, 4.2, 0.14)],
            [1, 0.5 + drift(83, 5.0, 0.16)],
            [0, 1], [0.5 + drift(53, 3.4, 0.16), 1], [1, 1],
        ]
    }

    /// Each grid slot blends between two shades of its row's family on its
    /// own slow cycle, so hues migrate along each band over a minute or two.
    static func colors(at t: TimeInterval) -> [Color] {
        let bands = [sky, forest, earth]  // mesh rows run top to bottom
        return (0..<9).map { slot in
            let family = bands[slot / 3]
            let a = family[slot % family.count]
            let b = family[(slot + 1) % family.count]
            let period = 60.0 + Double(slot) * 7
            let f = 0.5 + 0.5 * sin(t * 2 * .pi / period + Double(slot) * 1.7)
            return Color(
                red: a.0 + (b.0 - a.0) * f,
                green: a.1 + (b.1 - a.1) * f,
                blue: a.2 + (b.2 - a.2) * f
            )
        }
    }
}
