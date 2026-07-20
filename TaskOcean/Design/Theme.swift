import SwiftUI

/// Semantic palette derived from `design_reference.html`.
/// Resolved per color scheme so the whole app draws from one source of truth.
struct Theme {
    let scheme: ColorScheme

    var isDark: Bool { scheme == .dark }

    // MARK: Surfaces
    /// Behind-window canvas (used by the design gallery; the real window is `window`).
    var canvas: Color { isDark ? Color(hex: "#161617") : Color(hex: "#E9E8E5") }
    /// The floating window background.
    var window: Color { isDark ? Color(hex: "#1D1D1F") : Color(hex: "#FFFFFF") }
    /// Raised task card.
    var card: Color { isDark ? Color(hex: "#28282B") : Color(hex: "#FFFFFF") }
    /// Completed / recessed card.
    var cardMuted: Color { isDark ? Color(hex: "#212123") : Color(hex: "#FBFBFA") }
    /// Small control panels (segmented control, chips, nav buttons).
    var panel: Color { isDark ? Color(hex: "#28282B") : Color(hex: "#F4F3F0") }
    var panelStrong: Color { isDark ? Color(hex: "#3A3A3D") : Color(hex: "#F1F0ED") }
    var infoSurface: Color { isDark ? Color(hex: "#212123") : Color(hex: "#FBFAF8") }

    // MARK: Hairlines / borders
    var hairline: Color { isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.05) }
    var cardBorder: Color { isDark ? Color.white.opacity(0.04) : Color(hex: "#F1F0ED") }
    var divider: Color { isDark ? Color.white.opacity(0.05) : Color(hex: "#F0EFEC") }

    // MARK: Text
    var textPrimary: Color { isDark ? Color(hex: "#F4F4F2") : Color(hex: "#1B1B1A") }
    var textSecondary: Color { isDark ? Color(hex: "#84847E") : Color(hex: "#67665F") }
    var textMuted: Color { isDark ? Color(hex: "#7D7D78") : Color(hex: "#A6A5A1") }
    var textFaint: Color { isDark ? Color(hex: "#565658") : Color(hex: "#C9C8C4") }
    var iconMuted: Color { isDark ? Color(hex: "#6F6F6A") : Color(hex: "#9A9A96") }

    // MARK: Semantic
    var syncOK: Color { Color(hex: "#7BA86B") }
    var syncPending: Color { Color(hex: "#C9A15B") }
    var syncError: Color { Color(hex: "#C1694F") }
    var checkboxRing: Color { isDark ? Color(hex: "#4D4D50") : Color(hex: "#D4D3CF") }
    var checkboxFill: Color { isDark ? Color(hex: "#F4F4F2") : Color(hex: "#141413") }
    var checkboxFillGlyph: Color { isDark ? Color(hex: "#1D1D1F") : Color(hex: "#FFFFFF") }

    // MARK: Traffic lights (inert, decorative — real ones come from the window)
    var trafficLight: Color { isDark ? Color(hex: "#37373A") : Color(hex: "#E4E3DF") }

    // MARK: Shape metrics
    let windowRadius: CGFloat = 22
    let cardRadius: CGFloat = 15
    let chipRadius: CGFloat = 7
    let controlRadius: CGFloat = 9
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme(scheme: .light)
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

extension View {
    /// Injects a `Theme` resolved from the current color scheme.
    func provideTheme(_ scheme: ColorScheme) -> some View {
        environment(\.theme, Theme(scheme: scheme))
    }
}
