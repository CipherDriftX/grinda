import SwiftUI

// MARK: - Model

enum GrinMood: String, CaseIterable {
    case happy, calm, cheer, roar, worried, sleep, wink, proud
}

enum GrinPose: String, CaseIterable {
    case idle, cheer, wave, hold, flex
}

// MARK: - Path data

/// Parses the absolute M/L/C/Q/Z path strings in MascotArt into SwiftUI Paths, once.
enum MascotPaths {
    private static var cache: [String: Path] = [:]
    private static let lock = NSLock()

    static func path(_ d: String) -> Path {
        lock.lock(); defer { lock.unlock() }
        if let p = cache[d] { return p }
        let p = parse(d)
        cache[d] = p
        return p
    }

    private static func parse(_ d: String) -> Path {
        var path = Path()
        var nums: [CGFloat] = []
        var cmd: Character = "M"
        var token = ""

        func flushToken() {
            if !token.isEmpty, let v = Double(token) { nums.append(CGFloat(v)) }
            token = ""
        }
        func apply() {
            switch cmd {
            case "M": if nums.count >= 2 { path.move(to: CGPoint(x: nums[0], y: nums[1])) }
            case "L": if nums.count >= 2 { path.addLine(to: CGPoint(x: nums[0], y: nums[1])) }
            case "C": if nums.count >= 6 {
                path.addCurve(to: CGPoint(x: nums[4], y: nums[5]),
                              control1: CGPoint(x: nums[0], y: nums[1]),
                              control2: CGPoint(x: nums[2], y: nums[3]))
            }
            case "Q": if nums.count >= 4 {
                path.addQuadCurve(to: CGPoint(x: nums[2], y: nums[3]), control: CGPoint(x: nums[0], y: nums[1]))
            }
            case "Z": path.closeSubpath()
            default: break
            }
            nums.removeAll(keepingCapacity: true)
        }

        for ch in d {
            if "MLCQZ".contains(ch) {
                flushToken()
                if !nums.isEmpty { apply() }
                cmd = ch
                if ch == "Z" { apply() }
            } else if ch == "," || ch == " " {
                flushToken()
            } else if ch == "-" && !token.isEmpty {
                flushToken(); token = "-"
            } else {
                token.append(ch)
            }
        }
        flushToken()
        if !nums.isEmpty { apply() }
        return path
    }
}

/// Draws a list of mascot parts in the 400 × 460 canvas, scaled to fit.
struct MascotLayer: View {
    let parts: [MascotArt.Part]

    var body: some View {
        Canvas { ctx, size in
            ctx.scaleBy(x: size.width / MascotArt.canvas.width, y: size.height / MascotArt.canvas.height)
            for p in parts {
                let path = MascotPaths.path(p.d)
                var layer = ctx
                layer.opacity = p.opacity
                if let fill = p.fill {
                    layer.fill(path, with: .color(Color(hex: fill)))
                }
                if let stroke = p.stroke {
                    layer.stroke(path, with: .color(Color(hex: stroke)),
                                 style: StrokeStyle(lineWidth: p.width, lineCap: p.butt ? .butt : .round,
                                                    lineJoin: p.butt ? .miter : .round))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private func unit(_ p: CGPoint) -> UnitPoint {
    UnitPoint(x: p.x / MascotArt.canvas.width, y: p.y / MascotArt.canvas.height)
}

// MARK: - Grin

/// Grin, the Grinda lion. Layered vector parts so every limb and expression
/// animates natively.
///
/// Motion budget (he lives on screens people see many times a day):
/// - idle is near-imperceptible: a slow 1.5% breath, a blink every few seconds;
/// - `react` (tap or a real moment like hitting the goal) is a squash-and-stretch hop;
/// - Reduce Motion: no loops, no hops; expressions cross-fade.
struct GrinView: View {
    var mood: GrinMood = .happy
    var pose: GrinPose = .idle
    var mane: Int = 2
    /// Increment to make Grin hop (celebrations, taps).
    var hop: Int = 0
    var animated = true

    @State private var blink = false
    @State private var breathe = false
    @State private var swish = false
    @State private var waveFlip = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var live: Bool { animated && !reduceMotion }

    var body: some View {
        let arms = MascotArt.arms(pose.rawValue)
        ZStack {
            MascotLayer(parts: MascotArt.tail)
                .rotationEffect(.degrees(live && swish ? 7 : -3), anchor: unit(MascotArt.tailBase))
            MascotLayer(parts: MascotArt.body)
                .scaleEffect(x: 1, y: live && breathe ? 1.015 : 1, anchor: .bottom)
            head
                .offset(y: live && breathe ? -1.5 : 0)
            MascotLayer(parts: MascotArt.armL)
                .rotationEffect(.degrees(arms.0), anchor: unit(MascotArt.shoulderL))
            MascotLayer(parts: MascotArt.armR)
                .rotationEffect(.degrees(arms.1 + (pose == .wave && live && waveFlip ? 18 : 0)), anchor: unit(MascotArt.shoulderR))
        }
        .aspectRatio(MascotArt.canvas.width / MascotArt.canvas.height, contentMode: .fit)
        .animation(pose == .idle ? Motion.standard : Motion.snap, value: pose)
        .keyframeAnimator(initialValue: Hop(), trigger: hop) { content, v in
            content
                .scaleEffect(x: v.sx, y: v.sy, anchor: .bottom)
                .offset(y: v.y)
        } keyframes: { _ in
            KeyframeTrack(\.y) {
                CubicKeyframe(0, duration: 0.09)
                CubicKeyframe(-38, duration: 0.22)
                CubicKeyframe(0, duration: 0.2)
                SpringKeyframe(0, duration: 0.3, spring: .bouncy)
            }
            KeyframeTrack(\.sy) {
                CubicKeyframe(0.88, duration: 0.09)
                CubicKeyframe(1.07, duration: 0.18)
                CubicKeyframe(1.0, duration: 0.2)
                CubicKeyframe(0.93, duration: 0.07)
                SpringKeyframe(1.0, duration: 0.3, spring: .bouncy)
            }
            KeyframeTrack(\.sx) {
                CubicKeyframe(1.1, duration: 0.09)
                CubicKeyframe(0.96, duration: 0.18)
                CubicKeyframe(1.0, duration: 0.2)
                CubicKeyframe(1.06, duration: 0.07)
                SpringKeyframe(1.0, duration: 0.3, spring: .bouncy)
            }
        }
        .overlay(alignment: .topTrailing) {
            if mood == .sleep && live { Snooze().offset(x: -4, y: 6) }
        }
        .task(id: live) { await idleLoop() }
        .accessibilityElement()
        .accessibilityLabel("Grin the lion, \(mood.accessibilityText)")
    }

    private var head: some View {
        ZStack {
            MascotLayer(parts: MascotArt.manes[max(0, min(mane, 3))])
            MascotLayer(parts: MascotArt.head)
            ZStack {
                MascotLayer(parts: MascotArt.eyes(mood.rawValue))
                    .scaleEffect(x: 1, y: blink && mood != .sleep && mood != .wink ? 0.08 : 1, anchor: unit(MascotArt.eyeLine))
                MascotLayer(parts: MascotArt.brows(mood.rawValue))
                MascotLayer(parts: MascotArt.mouth(mood.rawValue))
            }
            .id(mood)
            .transition(.opacity.animation(.easeOut(duration: 0.16)))
        }
        .rotationEffect(.degrees(mood == .worried ? -4 : (mood == .proud ? 3 : 0)), anchor: unit(MascotArt.neck))
        .animation(Motion.standard, value: mood)
    }

    private func idleLoop() async {
        guard live else { breathe = false; swish = false; return }
        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) { breathe = true }
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { swish = true }
        withAnimation(.easeInOut(duration: 0.32).repeatForever(autoreverses: true)) { waveFlip = true }
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(Int.random(in: 2600...5200)))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.06)) { blink = true }
            try? await Task.sleep(for: .milliseconds(110))
            withAnimation(.easeOut(duration: 0.12)) { blink = false }
        }
    }
}

private struct Hop {
    var y: CGFloat = 0
    var sx: CGFloat = 1
    var sy: CGFloat = 1
}

extension GrinMood {
    var accessibilityText: String {
        switch self {
        case .happy, .calm: "smiling"
        case .cheer: "cheering"
        case .roar: "roaring"
        case .worried: "looking a little worried"
        case .sleep: "asleep"
        case .wink: "winking"
        case .proud: "looking proud"
        }
    }
}

/// Three small z's drifting up while Grin sleeps.
private struct Snooze: View {
    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Text("z")
                    .font(BrandFont.numerals(CGFloat(14 + i * 5)))
                    .foregroundStyle(Palette.cobalt.opacity(0.8))
                    .phaseAnimator([false, true]) { view, up in
                        view
                            .offset(x: up ? CGFloat(10 + i * 6) : 0, y: up ? -CGFloat(26 + i * 10) : 0)
                            .opacity(up ? 0 : 1)
                    } animation: { _ in
                        .easeOut(duration: 2.4).delay(Double(i) * 0.8)
                    }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Speech bubble

struct GrinBubble: View {
    let text: String
    var onField = false

    var body: some View {
        Text(text)
            .font(.system(.subheadline, weight: .semibold))
            .foregroundStyle(onField ? Palette.cobalt : Palette.ink)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                BubbleShape()
                    .fill(onField ? Color.white : Palette.tyvek)
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
            }
            .id(text)
            .transition(.asymmetric(insertion: .scale(scale: 0.94, anchor: .leading).combined(with: .opacity),
                                    removal: .opacity))
    }
}

/// Rounded bubble with a small tail pointing left, toward Grin.
struct BubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path(roundedRect: rect, cornerRadius: 16, style: .continuous)
        let y = rect.midY
        p.move(to: CGPoint(x: rect.minX + 1, y: y - 7))
        p.addLine(to: CGPoint(x: rect.minX - 8, y: y + 2))
        p.addLine(to: CGPoint(x: rect.minX + 1, y: y + 7))
        p.closeSubpath()
        return p
    }
}

// MARK: - Confetti

/// One-shot confetti burst in brand colours. Skipped entirely under Reduce Motion.
struct ConfettiBurst: View {
    var count = 70
    var duration: Double = 2.4
    @State private var start = Date.now
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Piece {
        let vx: Double, vy: Double, spin: Double, size: CGFloat, color: Color, round: Bool, delay: Double
    }

    @State private var pieces: [Piece] = []

    var body: some View {
        if reduceMotion {
            Color.clear
        } else {
            TimelineView(.animation) { tl in
                Canvas { ctx, size in
                    let t = tl.date.timeIntervalSince(start)
                    guard t < duration + 0.6 else { return }
                    let origin = CGPoint(x: size.width / 2, y: size.height * 0.35)
                    for p in pieces {
                        let tt = max(0, t - p.delay)
                        let x = origin.x + p.vx * tt
                        let y = origin.y + p.vy * tt + 620 * tt * tt / 2
                        let fade = max(0, 1 - tt / duration)
                        var c = ctx
                        c.opacity = fade
                        c.translateBy(x: x, y: y)
                        c.rotate(by: .radians(p.spin * tt))
                        let r = CGRect(x: -p.size / 2, y: -p.size / 4, width: p.size, height: p.round ? p.size : p.size / 2)
                        c.fill(p.round ? Path(ellipseIn: r) : Path(r), with: .color(p.color))
                    }
                }
            }
            .allowsHitTesting(false)
            .onAppear {
                start = .now
                let colors: [Color] = [Palette.volt, .white, Color(hex: 0xF0781E), Color(hex: 0xFFBE3D), Color(hex: Palette.cobaltNightHex)]
                pieces = (0..<count).map { i in
                    let a = Double.random(in: -Double.pi * 0.95 ... -Double.pi * 0.05)
                    let speed = Double.random(in: 260...620)
                    return Piece(vx: cos(a) * speed, vy: sin(a) * speed, spin: Double.random(in: -9...9),
                                 size: CGFloat.random(in: 7...13), color: colors[i % colors.count],
                                 round: i % 4 == 0, delay: Double.random(in: 0...0.12))
                }
            }
            .accessibilityHidden(true)
        }
    }
}

// MARK: - Coach lines

/// What Grin says. Specific, warm, never shaming. Variety is the variable reward.
enum GrinCoach {
    struct Context {
        var steps: Int
        var goal: Int
        var stake: Money?
        var streak: Int
        var pacerSteps: Int
        var hour: Int
    }

    static func mood(_ c: Context) -> GrinMood {
        if c.steps >= c.goal { return .cheer }
        if (c.hour >= 23 || c.hour < 6) && c.steps < 200 { return .sleep }
        if c.hour >= 12 && c.pacerSteps - c.steps > c.goal / 6 { return .worried }
        return .happy
    }

    static func line(_ c: Context, seed: Int) -> String {
        let left = max(c.goal - c.steps, 0)
        _ = Estimate.minutes(steps: left)
        let options: [String]
        if c.steps >= c.goal {
            options = [
                "Goal hit. That's how lions walk.",
                "Roar! \(c.steps.formatted()) steps today.",
                c.streak > 1 ? "\(c.streak) days in a row. My mane has never looked better." : "That's the lap. Same time tomorrow?",
                c.stake.map { "Your \($0.formatted) is safe today. Proud of you." } ?? "Done for today. Go enjoy that dinner.",
            ]
        } else if (c.hour >= 23 || c.hour < 6) && c.steps < 200 {
            options = ["Zzz… big walk tomorrow.", "Resting the paws. You should too."]
        } else if c.hour < 11 && c.steps < c.goal / 4 {
            options = [
                "New day, fresh laps. \(c.goal.formatted()) today?",
                "Coffee, then a walk. In that order.",
                "Morning! The track's empty. Let's own it.",
            ]
        } else if c.pacerSteps - c.steps > c.goal / 6 {
            let gap = c.pacerSteps - c.steps
            options = [
                "We're \(gap.formatted()) behind the pacer. One lap around the block fixes it.",
                c.stake.map { "\($0.formatted) says we walk tonight. I'll pace you." } ?? "Let's go for a lap. I'll pace you.",
                "Take the long way home. Every step counts.",
            ]
        } else {
            options = [
                "Nice stride today. Keep it rolling.",
                c.steps * 2 >= c.goal ? "Past halfway. The second half is the easy half." : "Nice rhythm. Phone calls count as walks, by the way.",
                "Stairs count double in my book. Not in Apple's, though.",
            ]
        }
        return options[abs(seed) % options.count]
    }

    static let tapLines = [
        "Hey, that tickles.",
        "Roooar!",
        "Every step is a paw print.",
        "Mane goal: walk.",
        "Lions rest 20 hours a day. You can't. Sorry.",
        "Walk it off. Keep your money.",
    ]

    /// Mane grows with consistency: goal days in the last 14.
    static func maneLevel(goalDaysOf14 n: Int) -> Int {
        switch n {
        case ..<4: 0
        case 4..<8: 1
        case 8..<12: 2
        default: 3
        }
    }

    static let maneNames = ["Cub", "Young lion", "Lion", "King of the track"]
    static let maneThresholds = [0, 4, 8, 12]
}
