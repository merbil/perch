import AppKit
import Observation

/// Which look the player uses. Auto lets the drop position decide.
enum ViewChoice: String, CaseIterable, Identifiable {
    case auto, pill, tab, tile, card, art, deck
    var id: String { rawValue }
    var title: String {
        switch self {
        case .auto: "Auto"
        case .pill: "Pill"
        case .tab: "Tab"
        case .tile: "Tile"
        case .card: "Card"
        case .art: "Art"
        case .deck: "Deck"
        }
    }
}

/// What happens when the player is let go away from the walls.
enum PositionChoice: String, CaseIterable, Identifiable {
    case stick, stay
    var id: String { rawValue }
    var title: String {
        switch self {
        case .stick: "Stick to the closest wall"
        case .stay: "Stay where I drop it"
        }
    }
}

/// How the tucked art sits in the edge.
enum TuckedStyle: String, CaseIterable, Identifiable {
    case peek, art
    var id: String { rawValue }
    var title: String {
        switch self {
        case .peek: "Peek out on hover"
        case .art: "Always show the album art"
        }
    }
}

/// Light, dark, or whatever the Mac uses.
enum AppearanceChoice: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: "Auto"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

/// Settings and the last position, kept in UserDefaults.
@MainActor
@Observable
final class Preferences {
    @ObservationIgnored private let defaults: UserDefaults

    var accent: Accent { didSet { defaults.set(accent.rawValue, forKey: "accent") } }
    var view: ViewChoice { didSet { defaults.set(view.rawValue, forKey: "view") } }
    var position: PositionChoice { didSet { defaults.set(position.rawValue, forKey: "position") } }
    var isShown: Bool { didSet { defaults.set(isShown, forKey: "isShown") } }
    var hasSeenTutorial: Bool { didSet { defaults.set(hasSeenTutorial, forKey: "hasSeenTutorial") } }
    var tuckedStyle: TuckedStyle { didSet { defaults.set(tuckedStyle.rawValue, forKey: "tuckedStyle") } }
    /// Stops the menu bar bars, scrolling titles and sliding windows. Starts from the system setting.
    var reduceMotion: Bool { didSet { defaults.set(reduceMotion, forKey: "reduceMotion") } }
    var appearance: AppearanceChoice { didSet { defaults.set(appearance.rawValue, forKey: "appearance") } }

    var form: Form {
        didSet { defaults.set(try? JSONEncoder().encode(form), forKey: "form") }
    }
    /// Form to go back to when the deck rolls in.
    var formBeforeDeck: Form? {
        didSet { defaults.set(try? JSONEncoder().encode(formBeforeDeck), forKey: "formBeforeDeck") }
    }
    /// Centre of the player along its edge (y on a side edge, x on the bottom), in screen coordinates.
    var along: Double { didSet { defaults.set(along, forKey: "along") } }
    var cardCenterX: Double { didSet { defaults.set(cardCenterX, forKey: "cardCenterX") } }
    var cardCenterY: Double { didSet { defaults.set(cardCenterY, forKey: "cardCenterY") } }
    /// Deck centre x once the user dragged it; nil = under the menu bar icon.
    var deckCenterX: Double? { didSet { defaults.set(deckCenterX, forKey: "deckCenterX") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        accent = defaults.string(forKey: "accent").flatMap(Accent.init(rawValue:)) ?? .tangerine
        view = defaults.string(forKey: "view").flatMap(ViewChoice.init(rawValue:)) ?? .auto
        position = defaults.string(forKey: "position").flatMap(PositionChoice.init(rawValue:)) ?? .stay
        isShown = defaults.object(forKey: "isShown") as? Bool ?? true
        hasSeenTutorial = defaults.bool(forKey: "hasSeenTutorial")
        appearance = defaults.string(forKey: "appearance").flatMap(AppearanceChoice.init(rawValue:)) ?? .system
        tuckedStyle = defaults.string(forKey: "tuckedStyle").flatMap(TuckedStyle.init(rawValue:)) ?? .peek
        reduceMotion = defaults.object(forKey: "reduceMotion") as? Bool
            ?? NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        form = (defaults.data(forKey: "form")).flatMap { try? JSONDecoder().decode(Form.self, from: $0) } ?? .pill(.right)
        formBeforeDeck = (defaults.data(forKey: "formBeforeDeck")).flatMap { try? JSONDecoder().decode(Form.self, from: $0) }
        along = defaults.object(forKey: "along") as? Double ?? -1
        cardCenterX = defaults.object(forKey: "cardCenterX") as? Double ?? -1
        cardCenterY = defaults.object(forKey: "cardCenterY") as? Double ?? -1
        deckCenterX = defaults.object(forKey: "deckCenterX") as? Double
    }
}
