//
//  Theme.swift
//  BrimFlow
//
//  Central design system: colors, gradients, fonts, spacing, effects.
//  All hex values come from the Brim Flow brand specification.
//

import SwiftUI

// MARK: - Hex helper

extension Color {
    /// Creates a color from a hex string ("#RRGGBB" or "RRGGBBAA").
    init(hex: String) {
        let raw = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: raw).scanHexInt64(&value)
        let a, r, g, b: UInt64
        switch raw.count {
        case 8: // RRGGBBAA
            (r, g, b, a) = (value >> 24 & 0xFF, value >> 16 & 0xFF, value >> 8 & 0xFF, value & 0xFF)
        case 6: // RRGGBB
            (r, g, b, a) = (value >> 16 & 0xFF, value >> 8 & 0xFF, value & 0xFF, 255)
        default:
            (r, g, b, a) = (0, 0, 0, 255)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - Brand palette

enum BFColor {
    // Water / primary accent
    static let water = Color(hex: "#06B6D4")
    static let waterActive = Color(hex: "#0891B2")
    static let waterSoft = Color(hex: "#22D3EE")

    // Coral / second accent
    static let coral = Color(hex: "#FB7185")
    static let coralActive = Color(hex: "#F43F5E")
    static let coralSoft = Color(hex: "#FDA4AF")

    // Status
    static let statusMet = Color(hex: "#22C55E")
    static let statusProgress = Color(hex: "#06B6D4")
    static let statusBehind = Color(hex: "#FBBF24")
    static let statusLow = Color(hex: "#FB7185")

    // Secondary button surface + text
    static let secondaryFill = Color(hex: "#D8EEF4")
    static let secondaryText = Color(hex: "#0E5160")

    // Static text tokens (light reference values)
    static let textPrimaryLight = Color(hex: "#0E3A45")
    static let textSecondaryLight = Color(hex: "#3E6B76")
    static let textDisabledLight = Color(hex: "#88AAB3")

    // Borders / dividers
    static let border = Color(hex: "#CBE6EE")
    static let dividerSoft = Color(hex: "#A9D6E2")

    // Effects
    static let aquaGlow = Color(hex: "#06B6D4").opacity(0.30)
    static let coralGlow = Color(hex: "#FB7185").opacity(0.25)
    static let softShadow = Color(hex: "#0E5A60").opacity(0.10)
    static let bubble = Color.white.opacity(0.55)
}

// MARK: - Adaptive (theme-aware) colors

/// Adaptive tokens resolve against the environment color scheme so that a
/// theme switch in Settings recolors the entire app immediately.
struct BFPalette {
    let scheme: ColorScheme

    init(_ scheme: ColorScheme) { self.scheme = scheme }

    var isDark: Bool { scheme == .dark }

    var backgroundPrimary: Color { isDark ? Color(hex: "#06222B") : Color(hex: "#F2FBFD") }
    var backgroundSecondary: Color { isDark ? Color(hex: "#0A2E39") : Color(hex: "#E7F6FA") }
    var backgroundDepth: Color { isDark ? Color(hex: "#0E3A45") : Color(hex: "#D8EEF4") }

    var card: Color { isDark ? Color(hex: "#0E3540") : Color.white }
    var cardHover: Color { isDark ? Color(hex: "#123E4B") : Color(hex: "#F2FBFD") }
    var border: Color { isDark ? Color(hex: "#1C4E5C") : Color(hex: "#CBE6EE") }
    var divider: Color { isDark ? Color(hex: "#1C4E5C") : Color(hex: "#A9D6E2") }

    var textPrimary: Color { isDark ? Color(hex: "#EAF8FC") : Color(hex: "#0E3A45") }
    var textSecondary: Color { isDark ? Color(hex: "#9FC4CE") : Color(hex: "#3E6B76") }
    var textDisabled: Color { isDark ? Color(hex: "#5E7E88") : Color(hex: "#88AAB3") }

    /// Vertical water gradient used by the glass and primary fills.
    var waterGradient: LinearGradient {
        LinearGradient(colors: [BFColor.waterSoft, BFColor.water],
                       startPoint: .top, endPoint: .bottom)
    }

    var backgroundGradient: LinearGradient {
        LinearGradient(colors: [backgroundPrimary, backgroundSecondary, backgroundDepth],
                       startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Environment access

private struct BFPaletteKey: EnvironmentKey {
    static let defaultValue = BFPalette(.light)
}

extension EnvironmentValues {
    var bfPalette: BFPalette {
        get { self[BFPaletteKey.self] }
        set { self[BFPaletteKey.self] = newValue }
    }
}

/// Injects a `BFPalette` derived from the current color scheme so child views
/// can read adaptive tokens via `@Environment(\.bfPalette)`.
struct PaletteProvider: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content.environment(\.bfPalette, BFPalette(scheme))
    }
}

extension View {
    func providePalette() -> some View { modifier(PaletteProvider()) }
}

// MARK: - Typography

enum BFFont {
    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded) }
    static func title(_ size: CGFloat = 22) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    static func headline(_ size: CGFloat = 17) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
    static func body(_ size: CGFloat = 15) -> Font { .system(size: size, weight: .medium, design: .rounded) }
    static func caption(_ size: CGFloat = 12) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
    static func mono(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded).monospacedDigit() }
}

// MARK: - Spacing & radius

enum BFSpacing {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 22
    static let xl: CGFloat = 30
}

enum BFRadius {
    static let sm: CGFloat = 12
    static let md: CGFloat = 18
    static let lg: CGFloat = 26
    static let pill: CGFloat = 999
}
