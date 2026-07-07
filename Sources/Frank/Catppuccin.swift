import AppKit
import SwiftUI

/// Catppuccin accents — Latte in light mode, Mocha in dark. Pastel by design;
/// carries all colour in the panel so everything else can stay quiet.
enum Catppuccin {
    static let green = dynamic(light: (0x40, 0xA0, 0x2B), dark: (0xA6, 0xE3, 0xA1))
    static let red = dynamic(light: (0xD2, 0x0F, 0x39), dark: (0xF3, 0x8B, 0xA8))
    static let peach = dynamic(light: (0xFE, 0x64, 0x0B), dark: (0xFA, 0xB3, 0x87))
    static let blue = dynamic(light: (0x1E, 0x66, 0xF5), dark: (0x89, 0xB4, 0xFA))

    private static func dynamic(light: (Int, Int, Int), dark: (Int, Int, Int)) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let rgb = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(
                srgbRed: CGFloat(rgb.0) / 255,
                green: CGFloat(rgb.1) / 255,
                blue: CGFloat(rgb.2) / 255,
                alpha: 1
            )
        })
    }
}
