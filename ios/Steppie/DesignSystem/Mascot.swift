import SwiftUI

// MARK: - Model

enum SteppieMood: String, CaseIterable {
    case happy, calm, cheer, roar, worried, sleep, wink, proud, focus
}

enum SteppiePose: String, CaseIterable {
    case idle, cheer, wave, hold, flex, point, run
}

/// Who's on stage. Steppie leads; each of the cast owns one mechanic.
enum CastMember: String, CaseIterable, Identifiable {
    case steppie, dash, shelly, pip, bo

    var id: String { rawValue }

    var rig: MascotArt.Rig {
        switch self {
        case .steppie: MascotArt.steppie
        case .dash: MascotArt.dash
        case .shelly: MascotArt.shelly
        case .pip: MascotArt.pip
        case .bo: MascotArt.bo
        }
    }

    var name: String {
        switch self {
        case .steppie: "Steppie"
        case .dash: "Dash"
        case .shelly: "Shelly"
        case .pip: "Pip"
        case .bo: "Bo"
        }
    }

    var role: String {
        switch self {
        case .steppie: "Your running buddy"
        case .dash: "The pacer. Always one step ahead."
        case .shelly: "Keeper of Shields"
        case .pip: "Brings the news"
        case .bo: "Guards the Vault"
        }
    }

    /// The cast only has four faces; map Steppie's richer moods onto them.
    func face(_ mood: SteppieMood) -> String {
        guard self != .steppie else { return mood.rawValue }
        switch mood {
        case .cheer, .roar: return "cheer"
        case .worried: return "worried"
        case .wink: return "wink"
        default: return "happy"
        }
    }
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
            case "M":
                var i = 0
                while i + 1 < nums.count {
                    let p = CGPoint(x: nums[i], y: nums[i + 1])
                    if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
                    i += 2
                }
            case "L":
                var i = 0
                while i + 1 < nums.count { path.addLine(to: CGPoint(x: nums[i], y: nums[i + 1])); i += 2 }
            case "C":
                var i = 0
                while i + 5 < nums.count {
                    path.addCurve(to: CGPoint(x: nums[i + 4], y: nums[i + 5]),
                                  control1: CGPoint(x: nums[i], y: nums[i + 1]),
                                  control2: CGPoint(x: nums[i + 2], y: nums[i + 3]))
                    i += 6
                }
            case "Q":
                var i = 0
                while i + 3 < nums.count {
                    path.addQuadCurve(to: CGPoint(x: nums[i + 2], y: nums[i + 3]), control: CGPoint(x: nums[i], y: nums[i + 1]))
                    i += 4
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

/// Draws mascot parts in the 400 × 460 canvas, scaled to fit. `recolor` swaps
/// fills by part id (Steppie's shoe colourways).
struct MascotLayer: View {
    let parts: [MascotArt.Part]
    var recolor: [String: UInt32] = [:]

    var body: some View {
        Canvas { ctx, size in
            ctx.scaleBy(x: size.width / MascotArt.canvas.width, y: size.height / MascotArt.canvas.height)
            for p in parts {
                let path = MascotPaths.path(p.d)
                var layer = ctx
                layer.opacity = p.opacity
                if let fill = recolor[p.id] ?? p.fill {
                    layer.fill(path, with: .color(Color(hex: fill)))
                }
                if let stroke = p.stroke {
                    layer.stroke(path, with: .color(Color(hex: stroke)),
                                 style: StrokeStyle(lineWidth: p.width, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private func unit(_ p: CGPoint) -> UnitPoint {
    UnitPoint(x: p.x / MascotArt.canvas.width, y: p.y / MascotArt.canvas.height)
}

// MARK: - Character

/// Any member of the cast, rigged: arms swing from the shoulders, legs lift
/// from the hips, the head tilts from the neck, the tail swishes and the eyes
/// blink. Two motion budgets:
/// - idle: a slow breath, tail sway, blinks, an occasional glance. Near-invisible,
///   because these characters live on screens people see many times a day.
/// - performing (`running`, `hop`, celebratory poses): full squash and stretch,
///   anticipation, overshoot, secondary motion on the head and tail.
/// Reduce Motion: no loops, no hops; expressions cross-fade.
struct CharacterView: View {
    var who: CastMember = .steppie
    var mood: SteppieMood = .happy
    var pose: SteppiePose = .idle
    var mane: Int = 2
    var shoes: ShoeStyle = .classic
    /// Increment to make the character hop (celebrations, taps).
    var hop: Int = 0
    /// Run cycle in place: knees, arm pump, bob, lean.
    var running = false
    var animated = true

    @State private var blink = false
    @State private var breathe = false
    @State private var swish = false
    @State private var waveFlip = false
    @State private var glance: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var live: Bool { animated && !reduceMotion }
    private var rig: MascotArt.Rig { who.rig }

    var body: some View {
        Group {
            if running && live {
                TimelineView(.animation) { tl in
                    figure(runPhase: tl.date.timeIntervalSinceReferenceDate)
                }
            } else {
                figure(runPhase: nil)
            }
        }
        .aspectRatio(MascotArt.canvas.width / MascotArt.canvas.height, contentMode: .fit)
        .keyframeAnimator(initialValue: Hop(), trigger: hop) { content, v in
            content
                .scaleEffect(x: v.sx, y: v.sy, anchor: .bottom)
                .rotationEffect(.degrees(v.spin), anchor: .bottom)
                .offset(y: v.y)
        } keyframes: { _ in
            KeyframeTrack(\.y) {
                CubicKeyframe(0, duration: 0.1)
                CubicKeyframe(-54, duration: 0.24)
                CubicKeyframe(0, duration: 0.2)
                SpringKeyframe(0, duration: 0.34, spring: .bouncy)
            }
            KeyframeTrack(\.sy) {
                CubicKeyframe(0.82, duration: 0.1)   // anticipation
                CubicKeyframe(1.12, duration: 0.2)   // stretch on take-off
                CubicKeyframe(1.0, duration: 0.22)
                CubicKeyframe(0.88, duration: 0.07)  // squash on landing
                SpringKeyframe(1.0, duration: 0.34, spring: .bouncy)
            }
            KeyframeTrack(\.sx) {
                CubicKeyframe(1.14, duration: 0.1)
                CubicKeyframe(0.92, duration: 0.2)
                CubicKeyframe(1.0, duration: 0.22)
                CubicKeyframe(1.1, duration: 0.07)
                SpringKeyframe(1.0, duration: 0.34, spring: .bouncy)
            }
            KeyframeTrack(\.spin) {
                CubicKeyframe(-3, duration: 0.1)
                CubicKeyframe(4, duration: 0.24)
                SpringKeyframe(0, duration: 0.5, spring: .bouncy)
            }
        }
        .overlay(alignment: .topTrailing) {
            if mood == .sleep && live { Snooze().offset(x: -4, y: 6) }
        }
        .task(id: live) { await idleLoop() }
        .accessibilityElement()
        .accessibilityLabel("\(who.name), \(mood.accessibilityText)")
    }

    /// One frame of the character. `runPhase` drives the run cycle (seconds).
    @ViewBuilder
    private func figure(runPhase: Double?) -> some View {
        let arms = MascotArt.arms(pose.rawValue)
        let cycle = runPhase.map { sin($0 * 2 * .pi * 2.3) } ?? 0   // ~2.3 strides a second
        let lift = runPhase.map { _ in CGFloat(max(0, cycle)) } ?? 0
        let liftR = runPhase.map { _ in CGFloat(max(0, -cycle)) } ?? 0
        let bob: CGFloat = runPhase == nil ? 0 : -CGFloat(abs(cycle)) * 10
        let pump = runPhase == nil ? 0 : cycle * 32
        let face = who.face(mood)
        GeometryReader { geo in
            let u = geo.size.height / MascotArt.canvas.height
            ZStack {
                MascotLayer(parts: rig.shadow)
                    .scaleEffect(x: runPhase == nil ? 1 : 1 - abs(cycle) * 0.08, y: 1, anchor: .bottom)
                Group {
                    MascotLayer(parts: rig.tail)
                        .rotationEffect(.degrees(runPhase != nil ? cycle * 10 : (live && swish ? 7 : -3)), anchor: unit(rig.tailBase))
                    MascotLayer(parts: rig.legL, recolor: who == .steppie ? shoes.recolor(side: "L") : [:])
                        .offset(y: -lift * 26 * u)
                        .rotationEffect(.degrees(-Double(lift) * 6), anchor: unit(rig.hipL))
                    MascotLayer(parts: rig.legR, recolor: who == .steppie ? shoes.recolor(side: "R") : [:])
                        .offset(y: -liftR * 26 * u)
                        .rotationEffect(.degrees(Double(liftR) * 6), anchor: unit(rig.hipR))
                    MascotLayer(parts: rig.body)
                        .scaleEffect(x: 1, y: live && breathe && runPhase == nil ? 1.015 : 1, anchor: .bottom)
                    head(face: face, runTilt: runPhase == nil ? 0 : cycle * 2.5, u: u)
                    MascotLayer(parts: rig.armL)
                        .rotationEffect(.degrees((runPhase != nil ? 0 : arms.0) + pump + (pose == .run && runPhase == nil ? 30 : 0)),
                                        anchor: unit(rig.shoulderL))
                    MascotLayer(parts: rig.armR)
                        .rotationEffect(.degrees((runPhase != nil ? 0 : arms.1) + pump
                                                 + (pose == .wave && live && waveFlip ? 18 : 0)
                                                 + (who == .pip && live && waveFlip && pose != .idle ? -24 : 0)),
                                        anchor: unit(rig.shoulderR))
                }
                .offset(y: bob * u)
                .rotationEffect(.degrees(runPhase == nil ? 0 : 4), anchor: .bottom)
            }
        }
        .animation(pose == .idle ? Motion.standard : Motion.snap, value: pose)
    }

    private func head(face: String, runTilt: Double, u: CGFloat) -> some View {
        ZStack {
            if !rig.manes.isEmpty {
                MascotLayer(parts: rig.manes[max(0, min(mane, rig.manes.count - 1))])
            }
            MascotLayer(parts: rig.head)
            ZStack {
                MascotLayer(parts: rig.eyes[face] ?? [])
                    .offset(x: glance * u)
                    .scaleEffect(x: 1, y: blink && face != "sleep" && face != "wink" ? 0.08 : 1,
                                 anchor: UnitPoint(x: 0.5, y: rig.eyeY / MascotArt.canvas.height))
                MascotLayer(parts: rig.brows[face] ?? [])
                MascotLayer(parts: rig.mouth[face] ?? [])
            }
            .id(face)
            .transition(.opacity.animation(.easeOut(duration: 0.16)))
        }
        .offset(y: live && breathe ? -1.5 * u : 0)
        .rotationEffect(.degrees(runTilt + (mood == .worried ? -4 : (mood == .proud ? 3 : 0))), anchor: unit(rig.neck))
        .animation(Motion.standard, value: mood)
    }

    private func idleLoop() async {
        guard live else { breathe = false; swish = false; return }
        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) { breathe = true }
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { swish = true }
        withAnimation(.easeInOut(duration: 0.32).repeatForever(autoreverses: true)) { waveFlip = true }
        var n = 0
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(Int.random(in: 2400...4800)))
            guard !Task.isCancelled else { return }
            n += 1
            if n % 3 == 0 {
                // a glance to the side and back: tiny secondary life
                withAnimation(.easeOut(duration: 0.18)) { glance = [-4, 4].randomElement()! }
                try? await Task.sleep(for: .milliseconds(900))
                withAnimation(.easeOut(duration: 0.22)) { glance = 0 }
            } else {
                withAnimation(.easeOut(duration: 0.06)) { blink = true }
                try? await Task.sleep(for: .milliseconds(110))
                withAnimation(.easeOut(duration: 0.12)) { blink = false }
            }
        }
    }
}

/// Steppie, the lion runner. The lead of the cast.
struct SteppieView: View {
    var mood: SteppieMood = .happy
    var pose: SteppiePose = .idle
    var mane: Int = 2
    var shoes: ShoeStyle = .classic
    var hop: Int = 0
    var running = false
    var animated = true

    var body: some View {
        CharacterView(who: .steppie, mood: mood, pose: pose, mane: mane, shoes: shoes, hop: hop, running: running, animated: animated)
    }
}

private struct Hop {
    var y: CGFloat = 0
    var sx: CGFloat = 1
    var sy: CGFloat = 1
    var spin: Double = 0
}

extension SteppieMood {
    var accessibilityText: String {
        switch self {
        case .happy, .calm: "smiling"
        case .cheer: "cheering"
        case .roar: "roaring"
        case .worried: "looking a little worried"
        case .sleep: "asleep"
        case .wink: "winking"
        case .proud: "looking proud"
        case .focus: "focused"
        }
    }
}

/// Three small z's drifting up while asleep.
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

// MARK: - Shoes (cosmetic collection)

/// Steppie's trainers. Earned from Shoe Boxes when you finish races; purely
/// cosmetic and never sold, so the random part of Steppie never touches money.
enum ShoeRarity: Int, Codable, CaseIterable, Comparable {
    case common, rare, epic, legendary

    static func < (a: ShoeRarity, b: ShoeRarity) -> Bool { a.rawValue < b.rawValue }

    var title: String {
        switch self {
        case .common: "Common"
        case .rare: "Rare"
        case .epic: "Epic"
        case .legendary: "Legendary"
        }
    }

    var color: Color {
        switch self {
        case .common: Color(hex: 0x9AA3B2)
        case .rare: Color(hex: 0x3D8BFF)
        case .epic: Color(hex: 0x9B5CFF)
        case .legendary: Color(hex: 0xFFB020)
        }
    }
}

struct ShoeStyle: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let rarity: ShoeRarity
    let upper: UInt32
    let shade: UInt32
    let midsole: UInt32
    let stripe: UInt32
    let sole: UInt32

    func recolor(side: String) -> [String: UInt32] {
        [
            "upper\(side)": upper, "upperShade\(side)": shade, "toeCap\(side)": shade, "collar\(side)": shade,
            "midsole\(side)": midsole, "stripe1\(side)": stripe, "stripe2\(side)": stripe, "outsole\(side)": sole,
        ]
    }

    static let classic = ShoeStyle(id: "classic", name: "Cobalt Classic", rarity: .common,
                                   upper: 0xFFFFFF, shade: 0xD9E0EC, midsole: 0xC8F03C, stripe: 0x1F4FD8, sole: 0x0E1116)

    static let all: [ShoeStyle] = [
        classic,
        ShoeStyle(id: "chalk", name: "Chalk Line", rarity: .common, upper: 0xF4F6F8, shade: 0xCDD2DB, midsole: 0xFFFFFF, stripe: 0x0E1116, sole: 0x4A5261),
        ShoeStyle(id: "night", name: "Night Lap", rarity: .common, upper: 0x1A1E26, shade: 0x0E1116, midsole: 0xFFFFFF, stripe: 0xC8F03C, sole: 0x0E1116),
        ShoeStyle(id: "track", name: "Track Red", rarity: .common, upper: 0xFFFFFF, shade: 0xE4E4E4, midsole: 0xFF5A4E, stripe: 0xFF5A4E, sole: 0x0E1116),
        ShoeStyle(id: "sunrise", name: "Sunrise 5K", rarity: .rare, upper: 0xFF9A3C, shade: 0xE07A1E, midsole: 0xFFE7A8, stripe: 0xFFFFFF, sole: 0x5A1E14),
        ShoeStyle(id: "glacier", name: "Glacier", rarity: .rare, upper: 0xBFE6FF, shade: 0x8CCBF2, midsole: 0xFFFFFF, stripe: 0x1F4FD8, sole: 0x16307F),
        ShoeStyle(id: "mint", name: "Mint Tempo", rarity: .rare, upper: 0xA8F0D1, shade: 0x6FD6AA, midsole: 0xFFFFFF, stripe: 0x0E7A55, sole: 0x0E1116),
        ShoeStyle(id: "volt", name: "Full Volt", rarity: .epic, upper: 0xC8F03C, shade: 0xA6CC22, midsole: 0x0E1116, stripe: 0x0E1116, sole: 0x0E1116),
        ShoeStyle(id: "ultra", name: "Ultraviolet", rarity: .epic, upper: 0x7C5CFF, shade: 0x5B3FE0, midsole: 0xFF6FD8, stripe: 0xFFFFFF, sole: 0x1A1033),
        ShoeStyle(id: "gold", name: "Golden Mile", rarity: .legendary, upper: 0xFFC83D, shade: 0xE0A21E, midsole: 0xFFF3C4, stripe: 0x0E1116, sole: 0x7A4A00),
    ]

    static func find(_ id: String?) -> ShoeStyle { all.first { $0.id == id } ?? classic }
}

// MARK: - Speech bubble

struct SpeechBubble: View {
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
                    .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
            }
            .id(text)
            .transition(.asymmetric(insertion: .scale(scale: 0.86, anchor: .leading).combined(with: .opacity),
                                    removal: .opacity))
    }
}

/// Rounded bubble with a small tail pointing left, toward the speaker.
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

// MARK: - Coach lines

/// What Steppie says. Specific, warm, never shaming. Variety is the variable reward.
enum Coach {
    struct Context {
        var steps: Int
        var goal: Int
        var stake: Money?
        var streak: Int
        var pacerSteps: Int
        var hour: Int
    }

    static func mood(_ c: Context) -> SteppieMood {
        if c.steps >= c.goal { return .cheer }
        if (c.hour >= 23 || c.hour < 6) && c.steps < 200 { return .sleep }
        if c.hour >= 12 && c.pacerSteps - c.steps > c.goal / 6 { return .worried }
        if c.stake != nil { return .focus }
        return .happy
    }

    static func line(_ c: Context, seed: Int) -> String {
        let left = max(c.goal - c.steps, 0)
        let minutes = Estimate.minutes(steps: left)
        let options: [String]
        if c.steps >= c.goal {
            options = [
                "Goal hit. That's how lions run.",
                "Roar! \(c.steps.formatted()) steps today.",
                c.streak > 1 ? "\(c.streak) days in a row. My mane has never looked better." : "That's the lap. Same time tomorrow?",
                c.stake.map { "Your \($0.formatted) is safe today. Proud of you." } ?? "Done. Imagine if that had been worth money.",
            ]
        } else if (c.hour >= 23 || c.hour < 6) && c.steps < 200 {
            options = ["Zzz… big run tomorrow.", "Resting the paws. You should too."]
        } else if c.hour < 11 && c.steps < c.goal / 4 {
            options = [
                "New day, fresh laps. \(c.goal.formatted()) today?",
                "Laces tied. Coffee first, then the track.",
                "Morning! Dash is already warming up. Let's not let him win.",
            ]
        } else if c.pacerSteps - c.steps > c.goal / 6 {
            let gap = c.pacerSteps - c.steps
            options = [
                "Dash is \(gap.formatted()) ahead. A \(minutes)-minute walk and we pass him.",
                c.stake.map { "\($0.formatted) says we walk tonight. I'll pace you." } ?? "Let's go for a lap. I'll pace you.",
                "Take the long way home. Every step counts.",
            ]
        } else {
            options = [
                "Nice stride. Keep it rolling.",
                c.steps * 2 >= c.goal ? "Past halfway. The second half is the easy half." : "Nice rhythm. Phone calls count as walks, by the way.",
                "Stairs count double in my book. Not in Apple's, though.",
            ]
        }
        return options[abs(seed) % options.count]
    }

    static let tapLines = [
        "Hey, that tickles.",
        "Roooar!",
        "New shoes? No? Just me?",
        "Every step is a paw print.",
        "Mane goal: run.",
        "Lions rest 20 hours a day. You can't. Sorry.",
        "Back yourself. Keep your money.",
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
