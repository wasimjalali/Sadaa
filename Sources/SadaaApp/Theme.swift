import SwiftUI

/// Karko AI brand palette, single source of truth for SadaaApp colors.
enum Theme {
    static func rgb(_ r: Int, _ g: Int, _ b: Int) -> Color {
        Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
    static let navy        = rgb(0x1E, 0x3A, 0x5F)
    static let navy800     = rgb(0x12, 0x24, 0x3B)
    static let gold        = rgb(0xD4, 0xA8, 0x53)
    static let gold300     = rgb(0xE0, 0xC6, 0x87)
    static let cream       = rgb(0xFA, 0xF7, 0xF2)
    static let creamSurface = rgb(0xFE, 0xFD, 0xFB)
    static let sage        = rgb(0x5B, 0x8A, 0x72)
    static let charcoal    = rgb(0x2D, 0x37, 0x48)
    static let white       = Color.white
    static let ink         = rgb(0x18, 0x24, 0x33)
    static let muted       = rgb(0x6B, 0x73, 0x80)
    static let line        = rgb(0xE6, 0xDD, 0xCD)
    static let surface     = creamSurface
    static let focus       = gold
    static let warning     = rgb(0xB8, 0x71, 0x2C)
    static let red         = rgb(0xB4, 0x23, 0x2F)
}
