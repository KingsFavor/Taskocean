import SwiftUI

extension Color {
    /// Create a Color from a hex string like "#5B7CA8" or "5B7CA8" (RGB) or with alpha "AARRGGBB".
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let a, r, g, b: UInt64
        switch s.count {
        case 8: // AARRGGBB
            a = (value >> 24) & 0xff
            r = (value >> 16) & 0xff
            g = (value >> 8) & 0xff
            b = value & 0xff
        default: // RRGGBB
            a = 0xff
            r = (value >> 16) & 0xff
            g = (value >> 8) & 0xff
            b = value & 0xff
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}
