import Foundation
import Observation

/// Settings and the last position, kept in UserDefaults.
@MainActor
@Observable
final class Preferences {
    @ObservationIgnored private let defaults: UserDefaults

    var accent: Accent { didSet { defaults.set(accent.rawValue, forKey: "accent") } }
    var snapToEdges: Bool { didSet { defaults.set(snapToEdges, forKey: "snapToEdges") } }
    var snapToCorners: Bool { didSet { defaults.set(snapToCorners, forKey: "snapToCorners") } }
    var isShown: Bool { didSet { defaults.set(isShown, forKey: "isShown") } }

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
        snapToEdges = defaults.object(forKey: "snapToEdges") as? Bool ?? true
        snapToCorners = defaults.object(forKey: "snapToCorners") as? Bool ?? true
        isShown = defaults.object(forKey: "isShown") as? Bool ?? true
        form = (defaults.data(forKey: "form")).flatMap { try? JSONDecoder().decode(Form.self, from: $0) } ?? .pill(.right)
        formBeforeDeck = (defaults.data(forKey: "formBeforeDeck")).flatMap { try? JSONDecoder().decode(Form.self, from: $0) }
        along = defaults.object(forKey: "along") as? Double ?? -1
        cardCenterX = defaults.object(forKey: "cardCenterX") as? Double ?? -1
        cardCenterY = defaults.object(forKey: "cardCenterY") as? Double ?? -1
        deckCenterX = defaults.object(forKey: "deckCenterX") as? Double
    }
}
