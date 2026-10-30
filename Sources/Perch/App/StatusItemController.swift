import AppKit
import Observation

/// Menu bar icon: four equaliser bars that move while music plays.
/// Left click opens the menu, right click hides or shows Perch. While Perch is hidden the bird is gone.
@MainActor
final class StatusItemController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let player: PlayerModel
    private let prefs: Preferences
    private var timer: Timer?

    var onLeftClick: () -> Void = {}
    var onRightClick: () -> Void = {}

    var buttonFrame: NSRect? {
        guard let button = item.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    init(player: PlayerModel, prefs: Preferences) {
        self.player = player
        self.prefs = prefs
        super.init()
        observePrefs()
        guard let button = item.button else { return }
        button.image = Self.icon(levels: Self.resting)
        button.setAccessibilityLabel("Perch")
        button.target = self
        button.action = #selector(clicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func observePrefs() {
        withObservationTracking {
            _ = prefs.isShown
            _ = prefs.reduceMotion
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.timer?.invalidate()
                self?.timer = nil
                self?.update()
                self?.observePrefs()
            }
        }
    }

    /// Call after every player refresh.
    func update() {
        if player.isPlaying && !prefs.reduceMotion {
            guard timer == nil else { return }
            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 12, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
        } else {
            timer?.invalidate()
            timer = nil
            item.button?.image = Self.icon(levels: player.isIdle ? [0.15, 0.15, 0.15, 0.15] : Self.resting, bird: prefs.isShown)
        }
    }

    private func tick() {
        let t = Date().timeIntervalSinceReferenceDate
        let levels: [Double] = (0..<4).map { i in
            let index = Double(i)
            let wave: Double = sin(t * (7 + Double(i % 3)) + index * 1.9)
            return 0.25 + 0.75 * (0.5 + 0.5 * wave)
        }
        item.button?.image = Self.icon(levels: levels, bird: prefs.isShown)
    }

    @objc private func clicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            onRightClick()
        } else {
            onLeftClick()
        }
    }

    private static let resting: [Double] = [0.35, 0.65, 0.45, 0.8]

    /// The logo's bars, with the bird riding the tallest bar as it moves.
    static func icon(levels: [Double], bird: Bool = true) -> NSImage {
        let image = NSImage(size: NSSize(width: 22, height: 18), flipped: false) { _ in
            NSColor.black.setFill()
            var lastTop: CGFloat = 0
            for (i, level) in levels.enumerated() {
                let height = 2 + 7.5 * level
                let bar = NSRect(x: 1.5 + Double(i) * 3.75, y: 1.5, width: 2.75, height: height)
                NSBezierPath(roundedRect: bar, xRadius: 1, yRadius: 1).fill()
                lastTop = bar.maxY
            }
            guard bird else { return true }
            // Bird: round body on the last bar, beak pointing right, eye punched out.
            let body = NSRect(x: 11.6, y: lastTop + 0.3, width: 6.4, height: 5.4)
            NSBezierPath(ovalIn: body).fill()
            let beak = NSBezierPath()
            beak.move(to: NSPoint(x: 17.4, y: body.midY + 1.2))
            beak.line(to: NSPoint(x: 20.6, y: body.midY))
            beak.line(to: NSPoint(x: 17.4, y: body.midY - 1.2))
            beak.close()
            beak.fill()
            NSGraphicsContext.current?.compositingOperation = .clear
            NSBezierPath(ovalIn: NSRect(x: 15.2, y: body.midY + 0.2, width: 1.3, height: 1.3)).fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}
