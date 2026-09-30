import SwiftUI

/// Geometry of a stadium track seen from above. Parameterised by arc length so
/// the progress stroke, the runner and the pacer all agree on positions.
/// t = 0 is the finish line at the centre of the home straight (bottom),
/// running counter-clockwise on screen like a real race.
struct TrackGeometry {
    let rect: CGRect

    var r: CGFloat { rect.height / 2 }
    var straight: CGFloat { max(rect.width - rect.height, 0) }
    var perimeter: CGFloat { 2 * straight + 2 * .pi * r }

    func point(at t: Double) -> CGPoint {
        let t = t.truncatingRemainder(dividingBy: 1) + (t < 0 ? 1 : 0)
        var d = CGFloat(t) * perimeter
        let midX = rect.midX, midY = rect.midY
        let half = straight / 2
        // 1. home straight, centre to right end
        if d <= half { return CGPoint(x: midX + d, y: rect.maxY) }
        d -= half
        // 2. right bend, bottom to top
        let arc = .pi * r
        if d <= arc {
            let a = CGFloat.pi / 2 - d / r
            return CGPoint(x: midX + half + r * cos(a), y: midY + r * sin(a))
        }
        d -= arc
        // 3. back straight, right to left
        if d <= straight { return CGPoint(x: midX + half - d, y: rect.minY) }
        d -= straight
        // 4. left bend, top to bottom
        if d <= arc {
            let a = -CGFloat.pi / 2 - d / r
            return CGPoint(x: midX - half + r * cos(a), y: midY + r * sin(a))
        }
        d -= arc
        // 5. home straight, left end to centre
        return CGPoint(x: midX - half + min(d, half), y: rect.maxY)
    }

    func path(from start: Double = 0, to end: Double = 1) -> Path {
        var p = Path()
        let steps = max(Int(perimeter / 2), 90)
        let lo = max(0, min(start, 1)), hi = max(lo, min(end, 1))
        guard hi > lo else { return p }
        let n = max(Int(Double(steps) * (hi - lo)), 2)
        p.move(to: point(at: lo))
        for i in 1...n { p.addLine(to: point(at: lo + (hi - lo) * Double(i) / Double(n))) }
        return p
    }
}

struct TrackShape: Shape {
    var progress: Double = 1
    var inset: CGFloat = 0

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        TrackGeometry(rect: rect.insetBy(dx: inset, dy: inset)).path(to: progress)
    }
}

/// Moves a view along the track as `progress` animates.
struct FollowTrack: ViewModifier, Animatable {
    var progress: Double
    let size: CGSize
    let inset: CGFloat

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let rect = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
        let p = TrackGeometry(rect: rect).point(at: progress)
        return content.position(p)
    }
}

/// Today's steps as laps on a floodlit cobalt track: a lane band, lane lines,
/// a finish line, the progress stroke, a runner and a ghost pacer.
struct TrackView: View {
    let steps: Int
    let goal: Int
    var pacer: Double? = nil
    var laneWidth: CGFloat = 30

    @State private var drawn = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var target: Double { goal > 0 ? min(Double(steps) / Double(goal), 1) : 0 }
    private var complete: Bool { steps >= goal }

    var body: some View {
        GeometryReader { geo in
            let inset = laneWidth / 2 + 14
            ZStack {
                // Lane band
                TrackShape(inset: inset)
                    .stroke(Palette.lane, style: StrokeStyle(lineWidth: laneWidth, lineJoin: .round))
                // Lane lines
                TrackShape(inset: inset - laneWidth / 2)
                    .stroke(.white.opacity(0.28), lineWidth: 1.2)
                TrackShape(inset: inset + laneWidth / 2)
                    .stroke(.white.opacity(0.28), lineWidth: 1.2)
                // Finish line across the lane at t = 0
                Rectangle()
                    .fill(.white)
                    .frame(width: 3, height: laneWidth + 6)
                    .position(x: geo.size.width / 2, y: geo.size.height - inset)
                // Progress
                TrackShape(progress: drawn, inset: inset)
                    .stroke(complete ? Palette.volt : .white,
                            style: StrokeStyle(lineWidth: laneWidth * 0.56, lineCap: .round, lineJoin: .round))
                // Pacer ghost
                if let pacer, !complete, pacer > 0.02 {
                    Circle()
                        .strokeBorder(.white.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                        .frame(width: 18, height: 18)
                        .modifier(FollowTrack(progress: pacer, size: geo.size, inset: inset))
                        .accessibilityHidden(true)
                }
                // Runner
                Runner(complete: complete)
                    .modifier(FollowTrack(progress: max(drawn, 0.0001), size: geo.size, inset: inset))
            }
        }
        .onAppear { animate(to: target, initial: true) }
        .onChange(of: target) { _, new in animate(to: new, initial: false) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(steps.formatted()) of \(goal.formatted()) steps")
        .accessibilityValue(complete ? "Goal reached" : "\((goal - steps).formatted()) to go")
    }

    private func animate(to value: Double, initial: Bool) {
        if reduceMotion { drawn = value; return }
        if initial { drawn = 0 }
        withAnimation(Motion.draw.delay(initial ? 0.15 : 0)) { drawn = value }
    }
}

private struct Runner: View {
    let complete: Bool

    var body: some View {
        ZStack {
            Circle().fill(complete ? Palette.volt : .white)
            Image(systemName: complete ? "checkmark" : "figure.walk")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(complete ? Palette.onVolt : Color(hex: Palette.cobaltHex))
        }
        .frame(width: 30, height: 30)
        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
    }
}
