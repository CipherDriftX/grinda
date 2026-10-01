import SwiftUI

/// The signature interaction. Holding the button pins your bib: four pins go
/// in at 25/50/75/100%, each with a rigid tap. Letting go early springs the
/// fill back fast. Slow where the person decides, fast where the app responds.
struct HoldToPinButton: View {
    let title: String
    var duration: Double = 1.6
    /// Reports how many pins are in (0...4) so the bib above can show them.
    @Binding var pins: Int
    /// Demo/screen-recording mode: performs the hold by itself.
    var autoplay = false
    let onComplete: () -> Void

    @State private var progress: Double = 0
    @State private var holding = false
    @State private var loop: Task<Void, Never>?
    @State private var done = false

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Palette.cobalt)
            GeometryReader { geo in
                Rectangle()
                    .fill(Palette.ink.opacity(0.28))
                    .frame(width: geo.size.width * progress)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            HStack(spacing: 10) {
                Image(systemName: done ? "checkmark" : "hand.point.up.left.fill")
                    .contentTransition(.symbolEffect(.replace))
                Text(done ? "Pinned" : (holding ? "Keep holding…" : title))
                    .contentTransition(.opacity)
            }
            .font(.system(.headline, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 60)
        .scaleEffect(holding ? 0.97 : 1)
        .animation(Motion.press, value: holding)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !holding && !done { begin() } }
                .onEnded { _ in if !done { cancel() } }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityHint("Double-tap and hold to confirm.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { finish() }
        .task {
            guard autoplay else { return }
            try? await Task.sleep(for: .seconds(1.4))
            begin()
        }
    }

    private func begin() {
        holding = true
        Haptics.soft()
        let start = Date.now
        let from = progress
        loop = Task { @MainActor in
            while !Task.isCancelled {
                let p = min(from + Date.now.timeIntervalSince(start) / duration, 1)
                progress = p
                let n = min(Int(p * 4 + 0.0001), 4)
                if n > pins {
                    pins = n
                    Haptics.pin()
                }
                if p >= 1 { finish(); return }
                try? await Task.sleep(for: .milliseconds(12))
            }
        }
    }

    private func cancel() {
        loop?.cancel()
        holding = false
        withAnimation(.spring(response: 0.25, dampingFraction: 1)) { progress = 0 }
        if pins > 0 { withAnimation(Motion.standard) { pins = 0 } }
    }

    private func finish() {
        guard !done else { return }
        loop?.cancel()
        holding = false
        done = true
        progress = 1
        pins = 4
        Haptics.success()
        onComplete()
    }
}
