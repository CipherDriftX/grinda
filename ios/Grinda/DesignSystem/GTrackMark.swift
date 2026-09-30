import SwiftUI

/// The Grinda symbol as a live shape: a running track that reads as a G,
/// whose crossbar is the finish line. Same construction as brand/tools/final.py
/// (870 × 570 unit box, straights 300, bend radius 210, opening 42°, bar 190,
/// stroke 150), so it can draw itself on.
struct GTrackShape: Shape {
    var progress: Double = 1

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    static let aspect: CGFloat = 870 / 570
    static let strokeRatio: CGFloat = 150 / 870

    func path(in rect: CGRect) -> Path {
        let s = rect.width / 870
        let cx = rect.minX + 435 * s, cy = rect.minY + 285 * s
        let r = 210 * s, half = 150 * s, bar = 190 * s
        let xr = cx + half, xl = cx - half
        var pts: [CGPoint] = []
        func arc(_ c: CGPoint, from a0: Double, to a1: Double) {
            let n = 48
            for i in 0...n {
                let a = (a0 + (a1 - a0) * Double(i) / Double(n)) * .pi / 180
                pts.append(CGPoint(x: c.x + r * cos(a), y: c.y - r * sin(a)))
            }
        }
        arc(CGPoint(x: xr, y: cy), from: 42, to: 90)
        pts.append(CGPoint(x: xl, y: cy - r))
        arc(CGPoint(x: xl, y: cy), from: 90, to: 270)
        pts.append(CGPoint(x: xr, y: cy + r))
        arc(CGPoint(x: xr, y: cy), from: 270, to: 360)
        pts.append(CGPoint(x: xr + r - bar, y: cy))

        var full = Path()
        full.move(to: pts[0])
        for p in pts.dropFirst() { full.addLine(to: p) }
        return full.trimmedPath(from: 0, to: progress)
    }
}

struct GTrackMark: View {
    var color: Color = .white
    var animated = false
    @State private var progress: Double = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            GTrackShape(progress: progress)
                .stroke(color, style: StrokeStyle(lineWidth: geo.size.width * GTrackShape.strokeRatio,
                                                  lineCap: .butt, lineJoin: .miter))
        }
        .aspectRatio(GTrackShape.aspect, contentMode: .fit)
        .onAppear {
            guard animated, !reduceMotion else { return }
            progress = 0
            withAnimation(.timingCurve(0.77, 0, 0.175, 1, duration: 1.3).delay(0.2)) { progress = 1 }
        }
        .accessibilityLabel("Grinda")
    }
}
