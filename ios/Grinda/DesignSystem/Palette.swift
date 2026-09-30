import SwiftUI
import UIKit

/// Grinda's colour system. Shared by the app and the widget extension.
///
/// The world is a stadium track seen from above: a cobalt field, white lane
/// lines, race bibs printed on cool-white Tyvek, and one signal colour
/// (Finish Volt) that is reserved for completion and money coming back.
enum Palette {
    // MARK: Brand constants

    static let cobaltHex: UInt32 = 0x1F4FD8
    static let cobaltNightHex: UInt32 = 0x3D6BFF
    static let tyvekHex: UInt32 = 0xF4F6F8
    static let inkHex: UInt32 = 0x0E1116
    static let voltHex: UInt32 = 0xC8F03C

    /// The track. Primary brand field and interactive tint.
    static let cobalt = Color(light: cobaltHex, dark: cobaltNightHex)
    /// The track field itself. Stays deep in both appearances so white lane text keeps contrast.
    static let field = Color(light: 0x1F4FD8, dark: 0x16307F)
    /// Slightly darker lane band drawn on the field.
    static let lane = Color(light: 0x1942B8, dark: 0x0F2463)
    /// Race-bib paper.
    static let tyvek = Color(light: tyvekHex, dark: 0x1A1E26)
    /// App ground behind bibs.
    static let ground = Color(light: 0xE9ECF1, dark: inkHex)
    /// Primary ink.
    static let ink = Color(light: inkHex, dark: 0xF1F3F6)
    /// Secondary ink on paper.
    static let inkSecondary = Color(light: 0x4A5261, dark: 0xA3AAB8)
    /// Tertiary ink / hairlines on paper.
    static let hairline = Color(light: 0xCDD2DB, dark: 0x2C323D)
    /// Finish Volt: completion and money returned only.
    static let volt = Color(hex: voltHex)
    /// Text drawn on volt.
    static let onVolt = Color(hex: inkHex)
    /// Stake at risk.
    static let risk = Color(light: 0xD92D20, dark: 0xFF5A4E)
    /// Secondary text on the cobalt field: tinted from the field, never gray.
    static let onFieldSecondary = Color(hex: 0xC9D6FF)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

/// Brand typefaces. Grinda Bib is Archivo instanced at width 62 / weight 900
/// (numerals) and width 75 / weight 750 (labels), SIL OFL 1.1.
enum BrandFont {
    static let bibBlack = "GrindaBib-Black"
    static let bibBold = "GrindaBib-Bold"
    static let wide = "GrindaWide-Black"

    /// Race-bib numerals. Scales with Dynamic Type relative to `style`.
    static func numerals(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        .custom(bibBlack, size: size, relativeTo: style)
    }

    /// Condensed uppercase labels printed on bibs.
    static func label(_ size: CGFloat, relativeTo style: Font.TextStyle = .caption) -> Font {
        .custom(bibBold, size: size, relativeTo: style)
    }

    static func wordmark(_ size: CGFloat) -> Font {
        .custom(wide, size: size, relativeTo: .title)
    }
}
