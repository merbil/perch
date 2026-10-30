import AppKit
import SwiftUI

enum Palette {
    static let paper = Color(hex: 0xFFF4E6)
    static let ink = Color(hex: 0x17131F)
    static let muted = Color(hex: 0x5B5466)
    static let lcd = Color(hex: 0x0B0A10)
    static let deckTrack = Color(hex: 0x2C2536)
    static let deckKey = Color(hex: 0xCFC6DD)
    static let tangerine = Color(hex: 0xFF7A3D)
    static let lilac = Color(hex: 0xB9A4FF)
    static let lime = Color(hex: 0xC6F36B)
    static let pink = Color(hex: 0xFF5FA2)
}

enum Accent: String, CaseIterable, Identifiable {
    case tangerine, lime, lilac, pink
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .tangerine: Palette.tangerine
        case .lime: Palette.lime
        case .lilac: Palette.lilac
        case .pink: Palette.pink
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

extension Font {
    /// Rounded type, black weight by default, like Skim's Arcade skin.
    static func perch(_ size: CGFloat, _ weight: Font.Weight = .black) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static func lcd(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
    }
}

extension NSFont {
    static func perch(_ size: CGFloat) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: .black)
        guard let rounded = base.fontDescriptor.withDesign(.rounded) else { return base }
        return NSFont(descriptor: rounded, size: size) ?? base
    }
}
