import AppKit
import SwiftUI

/// Colors follow the Mac's light or dark mode. In dark mode the paper turns plum-black and the
/// ink turns cream; accents, the album art and the deck's dark body stay as they are.
enum Palette {
    static let paper = dynamic(light: 0xFFF4E6, dark: 0x221C2B)
    static let ink = dynamic(light: 0x17131F, dark: 0xFFF4E6)
    static let muted = dynamic(light: 0x5B5466, dark: 0xB9B0C6)
    /// The hard offset shadow under surfaces and buttons.
    static let shadow = dynamic(light: 0x17131F, dark: 0x000000)
    /// Inputs and tracks (chips, radio buttons, the card's progress bar).
    static let field = dynamic(light: 0xFFFFFF, dark: 0x2E2738)
    /// The lavender desktop behind illustrations.
    static let desktop = dynamic(light: 0xE7E1F0, dark: 0x15111C)
    /// Selected chip background.
    static let selected = dynamic(light: 0x17131F, dark: 0x0B0A10)
    /// Light paper deck in light mode, the original dark deck in dark mode.
    static let deckBody = dynamic(light: 0xFFF4E6, dark: 0x17131F)
    static let deckShadow = dynamic(light: 0x17131F, dark: 0x9A8FB0)
    /// Never change with the mode: icons on accent fills, the app icon, album art placeholders.
    static let inkFixed = Color(hex: 0x17131F)
    static let paperFixed = Color(hex: 0xFFF4E6)
    static let onAccent = Color(hex: 0x17131F)
    static let lcd = Color(hex: 0x0B0A10)
    static let deckTrack = Color(hex: 0x2C2536)
    static let deckKey = Color(hex: 0xCFC6DD)
    static let tangerine = Color(hex: 0xFF7A3D)
    static let lilac = Color(hex: 0xB9A4FF)
    static let lime = Color(hex: 0xC6F36B)
    static let pink = Color(hex: 0xFF5FA2)
    static let sun = Color(hex: 0xFFD23F)
    static let coral = Color(hex: 0xFF6B6B)
}

enum Accent: String, CaseIterable, Identifiable {
    case tangerine, coral, pink, magenta, lilac, periwinkle, sky, mint, lime, sun, peach
    /// Picked from the album art, so it changes with every song.
    case cover

    var id: String { rawValue }
    static var colors: [Accent] { allCases.filter { $0 != .cover } }

    var title: String { self == .cover ? "From Cover Art" : rawValue.capitalized }

    /// Fixed color; for `.cover` this is the fallback when there's no art.
    var color: Color {
        switch self {
        case .tangerine, .cover: Palette.tangerine
        case .coral: Color(hex: 0xFF6B6B)
        case .pink: Palette.pink
        case .magenta: Color(hex: 0xE86BFF)
        case .lilac: Palette.lilac
        case .periwinkle: Color(hex: 0x8FA2FF)
        case .sky: Color(hex: 0x5EC8FF)
        case .mint: Color(hex: 0x6EE7C8)
        case .lime: Palette.lime
        case .sun: Color(hex: 0xFFD23F)
        case .peach: Color(hex: 0xFFB38A)
        }
    }
}

extension Preferences {
    /// The accent to paint with right now.
    func accentColor(for player: PlayerModel) -> Color {
        accent == .cover ? (player.coverAccent ?? Accent.cover.color) : accent.color
    }
}

extension Palette {
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(rgb: isDark ? dark : light)
        })
    }
}

extension NSColor {
    convenience init(rgb: UInt32) {
        self.init(srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255, green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
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
    static func perch(_ size: CGFloat, weight: NSFont.Weight = .black) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        guard let rounded = base.fontDescriptor.withDesign(.rounded) else { return base }
        return NSFont(descriptor: rounded, size: size) ?? base
    }
}
