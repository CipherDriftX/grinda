import SwiftUI

// Particle and light effects. Every effect is decorative, skipped entirely
// under Reduce Motion, and never blocks touches. Loud effects are rationed to
// rare moments (pinning, goal hit, finish, shoe box); everyday screens get the
// quiet ones (sparkle, shimmer, rays at low opacity).

// MARK: - Confetti

/// One-shot confetti burst in brand colours: rectangles, circles and streamers
/// that flutter (their width oscillates as they spin, like paper in air).
struct ConfettiBurst: View {
    var count = 80
    var duration: Double = 2.6
    var origin = UnitPoint(x: 0.5, y: 0.35)
    @State private var start = Date.now
    @State private var pieces: [Piece] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Piece {
        let vx: Double, vy: Double, spin: Double, flutter: Double, size: CGFloat, color: Color, shape: Int, delay: Double
    }

    var body: some View {
        if reduceMotion {
            Color.clear
        } else {
            TimelineView(.animation) { tl in
                Canvas { ctx, size in
                    let t = tl.date.timeIntervalSince(start)
                    guard t < duration + 0.6 else { return }
                    let o = CGPoint(x: size.width * origin.x, y: size.height * origin.y)
                    for p in pieces {
                        let tt = max(0, t - p.delay)
                        // air drag: velocity decays, gravity wins
                        let drag = 1 - exp(-tt * 1.6)
                        let x = o.x + p.vx * drag / 1.6 + sin(tt * p.flutter) * 14
                        let y = o.y + p.vy * drag / 1.6 + 320 * tt * tt / 2
                        var c = ctx
                        c.opacity = max(0, 1 - tt / duration)
                        c.translateBy(x: x, y: y)
                        c.rotate(by: .radians(p.spin * tt))
                        let w = p.size * CGFloat(abs(cos(tt * p.flutter)) * 0.8 + 0.2)
                        switch p.shape {
                        case 0: c.fill(Path(ellipseIn: CGRect(x: -p.size / 2, y: -p.size / 2, width: p.size, height: p.size)), with: .color(p.color))
                        case 1: c.fill(Path(CGRect(x: -w / 2, y: -p.size / 4, width: w, height: p.size / 2)), with: .color(p.color))
                        default:
                            var s = Path()
                            s.move(to: CGPoint(x: -w / 2, y: -p.size))
                            s.addQuadCurve(to: CGPoint(x: w / 2, y: p.size), control: CGPoint(x: w * 1.4, y: 0))
                            c.stroke(s, with: .color(p.color), lineWidth: 3)
                        }
                    }
                }
            }
            .allowsHitTesting(false)
            .onAppear {
                start = .now
                let colors: [Color] = [Palette.volt, .white, Color(hex: 0xF0781E), Color(hex: 0xFFBE3D), Color(hex: Palette.cobaltNightHex), Color(hex: 0x7C5CFF), Color(hex: 0x22B37A)]
                pieces = (0..<count).map { i in
                    let a = Double.random(in: -Double.pi * 0.95 ... -Double.pi * 0.05)
                    let speed = Double.random(in: 420...980)
                    return Piece(vx: cos(a) * speed, vy: sin(a) * speed, spin: Double.random(in: -10...10),
                                 flutter: Double.random(in: 6...14), size: CGFloat.random(in: 7...14),
                                 color: colors[i % colors.count], shape: i % 3, delay: Double.random(in: 0...0.12))
                }
            }
            .accessibilityHidden(true)
        }
    }
}

// MARK: - Coins

/// Money coming home: coins arc up and into a target point, spinning on their
/// edge (x-scale by cos), staggered like a payout counter. One-shot.
struct CoinRain: View {
    var count = 26
    var duration: Double = 1.8
    var from = UnitPoint(x: 0.5, y: 1.05)
    var to = UnitPoint(x: 0.5, y: 0.32)
    @State private var start = Date.now
    @State private var coins: [(dx: Double, lift: Double, spin: Double, delay: Double, size: CGFloat)] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            Color.clear
        } else {
            TimelineView(.animation) { tl in
                Canvas { ctx, size in
                    let t = tl.date.timeIntervalSince(start)
                    guard t < duration + 1 else { return }
                    let a = CGPoint(x: size.width * from.x, y: size.height * from.y)
                    let b = CGPoint(x: size.width * to.x, y: size.height * to.y)
                    for c in coins {
                        let p = min(max((t - c.delay) / 0.9, 0), 1)
                        guard p > 0, p < 1 else { continue }
                        let e = 1 - pow(1 - p, 3)
                        let x = a.x + (b.x - a.x) * e + c.dx * sin(.pi * p)
                        let y = a.y + (b.y - a.y) * e - c.lift * sin(.pi * p)
                        let edge = CGFloat(abs(cos(t * c.spin)))
                        var g = ctx
                        g.opacity = p > 0.85 ? (1 - p) / 0.15 : 1
                        g.translateBy(x: x, y: y)
                        g.scaleBy(x: max(edge, 0.15), y: 1)
                        let r = CGRect(x: -c.size / 2, y: -c.size / 2, width: c.size, height: c.size)
                        g.fill(Path(ellipseIn: r), with: .color(Color(hex: 0xE0A21E)))
                        g.fill(Path(ellipseIn: r.insetBy(dx: c.size * 0.12, dy: c.size * 0.12)), with: .color(Color(hex: 0xFFC83D)))
                        g.fill(Path(ellipseIn: CGRect(x: -c.size * 0.22, y: -c.size * 0.3, width: c.size * 0.18, height: c.size * 0.3)), with: .color(.white.opacity(0.6)))
                    }
                }
            }
            .allowsHitTesting(false)
            .onAppear {
                start = .now
                coins = (0..<count).map { i in
                    (dx: Double.random(in: -160...160), lift: Double.random(in: 60...220), spin: Double.random(in: 8...16),
                     delay: Double(i) * 0.045, size: CGFloat.random(in: 18...28))
                }
            }
            .accessibilityHidden(true)
        }
    }
}

// MARK: - Sparkles

/// Four-point stars that twinkle in and out at random spots. Quiet enough for
/// everyday screens.
struct SparkleField: View {
    var count = 10
    var color: Color = .white
    @State private var seeds: [(x: CGFloat, y: CGFloat, phase: Double, size: CGFloat)] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            Color.clear
        } else {
            TimelineView(.animation(minimumInterval: 1 / 30)) { tl in
                Canvas { ctx, size in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    for s in seeds {
                        let v = max(0, sin(t * 1.6 + s.phase))
                        guard v > 0.05 else { continue }
                        var g = ctx
                        g.opacity = v
                        g.translateBy(x: s.x * size.width, y: s.y * size.height)
                        g.rotate(by: .radians(t * 0.8 + s.phase))
                        g.fill(Self.star(s.size * CGFloat(0.6 + v * 0.4)), with: .color(color))
                    }
                }
            }
            .allowsHitTesting(false)
            .onAppear {
                seeds = (0..<count).map { _ in
                    (x: CGFloat.random(in: 0.04...0.96), y: CGFloat.random(in: 0.04...0.96), phase: Double.random(in: 0...(2 * .pi)), size: CGFloat.random(in: 5...11))
                }
            }
            .accessibilityHidden(true)
        }
    }

    static func star(_ r: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: -r))
        p.addQuadCurve(to: CGPoint(x: r, y: 0), control: .zero)
        p.addQuadCurve(to: CGPoint(x: 0, y: r), control: .zero)
        p.addQuadCurve(to: CGPoint(x: -r, y: 0), control: .zero)
        p.addQuadCurve(to: CGPoint(x: 0, y: -r), control: .zero)
        return p
    }
}

// MARK: - Rays

/// A slow-turning sunburst behind a hero (finish, shoe box, medals).
struct RaysBackground: View {
    var color: Color = .white
    var opacity: Double = 0.08
    var rays = 18
    @State private var turn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let r = max(geo.size.width, geo.size.height)
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                var p = Path()
                for i in 0..<rays {
                    let a0 = Double(i) / Double(rays) * 2 * .pi
                    let a1 = a0 + .pi / Double(rays) * 0.9
                    p.move(to: c)
                    p.addLine(to: CGPoint(x: c.x + r * cos(a0), y: c.y + r * sin(a0)))
                    p.addLine(to: CGPoint(x: c.x + r * cos(a1), y: c.y + r * sin(a1)))
                    p.closeSubpath()
                }
                ctx.fill(p, with: .color(color.opacity(opacity)))
            }
            .frame(width: r * 2, height: r * 2)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
            .rotationEffect(.degrees(turn ? 360 : 0))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 60).repeatForever(autoreverses: false)) { turn = true }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Dust

/// Little puffs kicked up behind a runner.
struct DustPuffs: View {
    var color: Color = .white
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            Color.clear
        } else {
            TimelineView(.animation(minimumInterval: 1 / 30)) { tl in
                Canvas { ctx, size in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    for i in 0..<4 {
                        let p = (t * 1.6 + Double(i) / 4).truncatingRemainder(dividingBy: 1)
                        let r = CGFloat(3 + p * 7)
                        var g = ctx
                        g.opacity = (1 - p) * 0.55
                        let x = size.width / 2 - CGFloat(p) * size.width * 0.45
                        let y = size.height - r - CGFloat(sin(p * .pi)) * 6
                        g.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(color))
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

// MARK: - Modifiers

/// A diagonal glint that sweeps across a call to action every few seconds.
struct Shimmer: ViewModifier {
    var active = true
    var period: Double = 3.2
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay {
            if active && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1 / 30)) { tl in
                    GeometryReader { geo in
                        let p = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
                        let x = (p * 3 - 1) * geo.size.width
                        LinearGradient(colors: [.clear, .white.opacity(0.42), .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: geo.size.width * 0.35)
                            .rotationEffect(.degrees(20))
                            .offset(x: x)
                    }
                }
                .allowsHitTesting(false)
                .mask(content)
            }
        }
    }
}

/// A soft ring that breathes out from a view, inviting a tap.
struct PulseHalo: ViewModifier {
    var color: Color = Palette.volt
    var cornerRadius: CGFloat = 16
    @State private var on = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.background {
            if !reduceMotion {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(color, lineWidth: 3)
                    .scaleEffect(on ? 1.08 : 1)
                    .opacity(on ? 0 : 0.8)
                    .onAppear {
                        withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { on = true }
                    }
            }
        }
    }
}

/// A short, decaying horizontal shake (a roar, a near miss).
struct Shake: GeometryEffect {
    var amount: CGFloat = 8
    var shakes: CGFloat = 4
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let decay = max(0, 1 - animatableData.truncatingRemainder(dividingBy: 1))
        return ProjectionTransform(CGAffineTransform(translationX: amount * decay * sin(animatableData * .pi * shakes * 2), y: 0))
    }
}

extension View {
    func shimmer(_ active: Bool = true) -> some View { modifier(Shimmer(active: active)) }
    func pulseHalo(_ color: Color = Palette.volt, cornerRadius: CGFloat = 16) -> some View { modifier(PulseHalo(color: color, cornerRadius: cornerRadius)) }
    func shake(_ trigger: Int) -> some View { modifier(Shake(animatableData: CGFloat(trigger))) }
}
