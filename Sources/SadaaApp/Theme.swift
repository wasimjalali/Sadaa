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
}
