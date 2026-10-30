// GENERATED from docs/design/tokens.json by scripts/tokens_to_swift.py. Do not edit by hand.
// Design system: Autopal v1.
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public enum AutopalTokens {
    /// Phone app background behind all content.
    public static let bg = Color(light: 0xF5F7FA, lightAlpha: 1, dark: 0x0B0E12, darkAlpha: 1)
    /// Cards, gauge tiles, list rows, bottom sheets.
    public static let surface = Color(light: 0xFFFFFF, lightAlpha: 1, dark: 0x151A21, darkAlpha: 1)
    /// Selected navigation item, secondary buttons, pressed rows.
    public static let surfaceHigh = Color(light: 0xE8EDF3, lightAlpha: 1, dark: 0x1F2630, darkAlpha: 1)
    /// Hairline borders, dividers, outlined buttons.
    public static let outline = Color(light: 0xCDD5DF, lightAlpha: 1, dark: 0x2C3440, darkAlpha: 1)
    /// Primary text and numbers on bg, surface and surface-high (13.5:1 or better).
    public static let ink = Color(light: 0x0E141B, lightAlpha: 1, dark: 0xEEF2F6, darkAlpha: 1)
    /// Units, captions, section labels, inactive navigation (6:1 or better).
    public static let inkMuted = Color(light: 0x4D5967, lightAlpha: 1, dark: 0xA3AEBB, darkAlpha: 1)
    /// A reading older than 3x its poll interval. Always paired with the word 'stale'.
    public static let inkStale = Color(light: 0x5F6A76, lightAlpha: 1, dark: 0x8D97A3, darkAlpha: 1)
    /// Brand colour. Links, live indicator, selected state, normal gauge arc, healthy verdict.
    public static let primary = Color(light: 0x0A62C6, lightAlpha: 1, dark: 0x4DB2FF, darkAlpha: 1)
    /// Text and icons on primary fills (7:1 dark, 5.9:1 light).
    public static let onPrimary = Color(light: 0xFFFFFF, lightAlpha: 1, dark: 0x00213D, darkAlpha: 1)
    /// Healthy verdict card, extended FAB, highlighted tiles.
    public static let primaryContainer = Color(light: 0xD7E8FF, lightAlpha: 1, dark: 0x0F3556, darkAlpha: 1)
    /// Text on primary-container (9.9:1 dark, 10.8:1 light).
    public static let onPrimaryContainer = Color(light: 0x062F5C, lightAlpha: 1, dark: 0xCFE6FF, darkAlpha: 1)
    /// Gauge value arc in the normal state.
    public static let gaugeNormal = Color(light: 0x0A62C6, lightAlpha: 1, dark: 0x4DB2FF, darkAlpha: 1)
    /// Gauge value arc in the warning state. Graphic only (3.6:1 on light surface); warning text uses 'warning'.
    public static let gaugeWarning = Color(light: 0xBD7800, lightAlpha: 1, dark: 0xFFB020, darkAlpha: 1)
    /// Gauge value arc in the critical state. Graphic only; critical text uses 'critical'.
    public static let gaugeCritical = Color(light: 0xE04A3D, lightAlpha: 1, dark: 0xFF6B5A, darkAlpha: 1)
    /// Unfilled gauge track. Decorative; the value arc and number carry the meaning.
    public static let gaugeTrack = Color(light: 0xDCE2EA, lightAlpha: 1, dark: 0x2C3440, darkAlpha: 1)
    /// RPM zone from 92% of the vehicle's redline to the end of the scale.
    public static let redlineBand = Color(light: 0xF6D3CF, lightAlpha: 1, dark: 0x5A2E2A, darkAlpha: 1)
    /// Warning text and icons; warning banner fill in dark theme.
    public static let warning = Color(light: 0x9A5800, lightAlpha: 1, dark: 0xFFB020, darkAlpha: 1)
    /// Text on a warning fill (9.2:1 dark, 5.6:1 light).
    public static let onWarning = Color(light: 0xFFFFFF, lightAlpha: 1, dark: 0x2A1A00, darkAlpha: 1)
    /// Soft warning card behind 'Service soon' items; text on it is ink or warning.
    public static let warningContainer = Color(light: 0xFFE7BF, lightAlpha: 1, dark: 0x3A2A06, darkAlpha: 1)
    /// Critical text and icons; critical banner fill.
    public static let critical = Color(light: 0xB02A21, lightAlpha: 1, dark: 0xFF6B5A, darkAlpha: 1)
    /// Text on a critical fill (6.6:1 dark, 6.6:1 light).
    public static let onCritical = Color(light: 0xFFFFFF, lightAlpha: 1, dark: 0x2B0703, darkAlpha: 1)
    /// Soft critical card behind 'Stop and check' items.
    public static let criticalContainer = Color(light: 0xFFDAD5, lightAlpha: 1, dark: 0x4A1712, darkAlpha: 1)
    /// Android Auto surface background (showcase build). Dark = car night mode.
    public static let carGround = Color(light: 0xF2F4F7, lightAlpha: 1, dark: 0x06080B, darkAlpha: 1)
    /// Tiles and buttons on the Android Auto surface.
    public static let carSurface = Color(light: 0xFFFFFF, lightAlpha: 1, dark: 0x10141A, darkAlpha: 1)

    public enum Spacing {
        /// Icon-to-label gap.
        public static let s1: CGFloat = 4
        /// Chip gaps, tight stacks.
        public static let s2: CGFloat = 8
        /// Gap between gauge tiles.
        public static let s3: CGFloat = 12
        /// Phone screen gutter, card padding.
        public static let s4: CGFloat = 16
        /// Section spacing; tablet gutter.
        public static let s6: CGFloat = 24
        /// Car screen padding.
        public static let s8: CGFloat = 32
    }

    public enum Radius {
        /// Buttons, inputs, small tiles.
        public static let sm: CGFloat = 12
        /// Cards and gauge tiles.
        public static let md: CGFloat = 20
        /// Hero verdict card, bottom sheets, car tiles.
        public static let lg: CGFloat = 28
        /// Chips, navigation pill, FAB.
        public static let full: CGFloat = 999
    }
}

extension Color {
    /// A colour that follows light/dark appearance (phone, widgets, CarPlay).
    init(light: UInt32, lightAlpha: Double, dark: UInt32, darkAlpha: Double) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            let hex = isDark ? dark : light
            let alpha = isDark ? darkAlpha : lightAlpha
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
        })
        #else
        self.init(red: Double((dark >> 16) & 0xFF) / 255, green: Double((dark >> 8) & 0xFF) / 255,
                  blue: Double(dark & 0xFF) / 255, opacity: darkAlpha)
        #endif
    }
}
