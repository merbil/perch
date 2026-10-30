import AppKit

/// Menu bar icon: four equaliser bars that move while music plays.
/// Left click shows/hides Perch, right click opens the deck, Option-click opens a small menu.
@MainActor
final class StatusItemController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let player: PlayerModel
    private var timer: Timer?

    var onLeftClick: () -> Void = {}
    var onRightClick: () -> Void = {}
    var isPerchVisible: () -> Bool = { false }

    var buttonFrame: NSRect? {
        guard let button = item.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    init(player: PlayerModel) {
        self.player = player
        super.init()
        guard let button = item.button else { return }
        button.image = Self.icon(levels: Self.resting)
        button.setAccessibilityLabel("Perch")
        button.target = self
        button.action = #selector(clicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    /// Call after every player refresh.
    func update() {
        if player.isPlaying {
            guard timer == nil else { return }
            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 12, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
        } else {
            timer?.invalidate()
            timer = nil
            item.button?.image = Self.icon(levels: player.isIdle ? [0.15, 0.15, 0.15, 0.15] : Self.resting)
        }
    }

    private func tick() {
        let t = Date().timeIntervalSinceReferenceDate
        let levels: [Double] = (0..<4).map { i in
            let index = Double(i)
            let wave: Double = sin(t * (7 + Double(i % 3)) + index * 1.9)
            return 0.25 + 0.75 * (0.5 + 0.5 * wave)
        }
        item.button?.image = Self.icon(levels: levels)
    }

    @objc private func clicked() {
        guard let event = NSApp.currentEvent else { return onLeftClick() }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            onRightClick()
        } else if event.modifierFlags.contains(.option) {
            showMenu()
        } else {
            onLeftClick()
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        let toggle = NSMenuItem(title: isPerchVisible() ? "Hide Perch" : "Show Perch", action: #selector(menuToggle), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)
        let deck = NSMenuItem(title: "Show Deck", action: #selector(menuDeck), keyEquivalent: "")
        deck.target = self
        menu.addItem(deck)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Perch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
    }

    @objc private func menuToggle() { onLeftClick() }
    @objc private func menuDeck() { onRightClick() }

    private static let resting: [Double] = [0.35, 0.65, 0.45, 0.8]

    static func icon(levels: [Double]) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 16), flipped: false) { _ in
            NSColor.black.setFill()
            for (i, level) in levels.enumerated() {
                let height = 2 + 11 * level
                let bar = NSRect(x: 2.5 + Double(i) * 3.75, y: 2.5, width: 2.75, height: height)
                NSBezierPath(roundedRect: bar, xRadius: 1, yRadius: 1).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
