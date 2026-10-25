import SwiftUI
import UIKit

/// One motion grammar for the whole app. Critically damped springs by default;
/// bounce only where a physical thing snaps (pins, the finish tape).
enum Motion {
    /// Default UI movement (Apple: damping 1.0, response ~0.35).
    static let standard = Animation.spring(response: 0.38, dampingFraction: 1.0)
    /// Quick press feedback.
    static let press = Animation.spring(response: 0.22, dampingFraction: 0.9)
    /// Pins and tape: a physical snap with a little overshoot.
    static let snap = Animation.spring(response: 0.32, dampingFraction: 0.62)
    /// The track drawing in on appear.
    static let draw = Animation.spring(response: 1.1, dampingFraction: 1.0)
    /// Staggered entrance step.
    static func stagger(_ i: Int) -> Animation { standard.delay(Double(i) * 0.05) }
}

/// Haptics fired on the same frame as the visual change they belong to.
@MainActor
enum Haptics {
    static func pin() { UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.9) }
    static func tick() { UISelectionFeedbackGenerator().selectionChanged() }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

/// Scale-on-press for anything tappable: responds on touch-down, releases fast.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableStyle {
    static var pressable: PressableStyle { PressableStyle() }
}

/// Primary action: a solid cobalt slab with bib-label type.
struct PrimaryButtonStyle: ButtonStyle {
    var fill: Color = Palette.cobalt
    var foreground: Color = .white
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(fill.opacity(isEnabled ? 1 : 0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static var onField: PrimaryButtonStyle { PrimaryButtonStyle(fill: .white, foreground: Palette.cobalt) }
    static var volt: PrimaryButtonStyle { PrimaryButtonStyle(fill: Palette.volt, foreground: Palette.onVolt) }
}

/// Fades and lifts content in once, staggered by index. Respects Reduce Motion.
struct Arrive: ViewModifier {
    let index: Int
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 12)
            .onAppear {
                withAnimation(reduceMotion ? .easeOut(duration: 0.2) : Motion.stagger(index)) { shown = true }
            }
    }
}

extension View {
    func arrive(_ index: Int = 0) -> some View { modifier(Arrive(index: index)) }
}
