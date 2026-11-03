import AppKit
import Observation

/// Menu bar icon: four equaliser bars that move while music plays.
/// Left click opens the menu, right click hides or shows Perch. While Perch is hidden the bird is gone.
///
/// The item has a fixed width and the bars move as Core Animation layers inside it. Swapping the
/// button's image 12 times a second (as 0.2.x did) made the menu bar lay itself out again and again,
/// which swallowed clicks on the items next to Perch, like the clock.
@MainActor
final class StatusItemController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: 26)
    private let player: PlayerModel
    private let prefs: Preferences
    private let icon = EqualiserIconView(frame: NSRect(x: 0, y: 0, width: 22, height: 18))

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
        button.setAccessibilityLabel("Perch")
        button.target = self
        button.action = #selector(clicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        icon.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 22),
            icon.heightAnchor.constraint(equalToConstant: 18),
        ])
        update()
    }

    private func observePrefs() {
        withObservationTracking {
            _ = prefs.isShown
            _ = prefs.reduceMotion
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.update()
                self?.observePrefs()
            }
        }
    }

    /// Call after every player refresh. Only touches the layers when something changed.
    func update() {
        let mode: EqualiserIconView.Mode = if player.isPlaying && !prefs.reduceMotion {
            .playing
        } else if player.isIdle {
            .idle
        } else {
            .resting
        }
        icon.set(mode: mode, bird: prefs.isShown)
    }

    @objc private func clicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            onRightClick()
        } else {
            onLeftClick()
        }
    }

    static let resting: [Double] = [0.35, 0.65, 0.45, 0.8]

    /// The logo's bars as a still image (used by `--icon` to check the drawing).
    static func icon(levels: [Double], bird: Bool = true) -> NSImage {
        let image = NSImage(size: NSSize(width: 22, height: 18), flipped: false) { _ in
            NSColor.black.setFill()
            NSBezierPath(cgPath: EqualiserIconView.barsPath(levels: levels)).fill()
            if bird, let last = levels.last {
                let top = EqualiserIconView.barTop(last)
                let body = NSBezierPath(cgPath: EqualiserIconView.birdBodyPath(barTop: top))
                body.windingRule = .evenOdd
                body.fill()
                NSBezierPath(cgPath: EqualiserIconView.beakPath(barTop: top)).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}

/// Four bars and the bird, drawn with layers in the menu bar's text color.
final class EqualiserIconView: NSView {
    enum Mode: Equatable { case playing, resting, idle }

    private var bars: [CAShapeLayer] = []
    /// Body (with the eye as a hole) and beak, moved together.
    private let bird = CALayer()
    private let birdBody = CAShapeLayer()
    private let beak = CAShapeLayer()
    private var mode: Mode?
    private var showsBird = true

    /// Each bar bounces between two heights at its own speed.
    private static let ranges: [(low: Double, high: Double, duration: Double)] = [
        (0.25, 0.9, 0.42), (0.35, 1.0, 0.55), (0.2, 0.85, 0.37), (0.3, 1.0, 0.48),
    ]

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        for i in 0..<4 {
            let bar = CAShapeLayer()
            // A full-height bar anchored at its foot; height comes from scaling it.
            bar.path = CGPath(roundedRect: CGRect(x: 0, y: 0, width: 2.75, height: Self.barHeight(1)),
                              cornerWidth: 1, cornerHeight: 1, transform: nil)
            bar.anchorPoint = CGPoint(x: 0, y: 0)
            bar.bounds = CGRect(x: 0, y: 0, width: 2.75, height: Self.barHeight(1))
            bar.position = CGPoint(x: 1.5 + Double(i) * 3.75, y: 1.5)
            layer?.addSublayer(bar)
            bars.append(bar)
        }
        birdBody.path = Self.birdBodyPath(barTop: 0)
        birdBody.fillRule = .evenOdd
        beak.path = Self.beakPath(barTop: 0)
        bird.addSublayer(birdBody)
        bird.addSublayer(beak)
        layer?.addSublayer(bird)
        applyColor()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }   // clicks go to the button

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyColor()
    }

    private func applyColor() {
        var color = NSColor.labelColor.cgColor
        effectiveAppearance.performAsCurrentDrawingAppearance { color = NSColor.labelColor.cgColor }
        bars.forEach { $0.fillColor = color }
        birdBody.fillColor = color
        beak.fillColor = color
    }

    func set(mode: Mode, bird showsBird: Bool) {
        if showsBird != self.showsBird {
            self.showsBird = showsBird
            bird.isHidden = !showsBird
        }
        guard mode != self.mode else { return }
        self.mode = mode

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (i, bar) in bars.enumerated() {
            bar.removeAllAnimations()
            let level = mode == .idle ? 0.15 : StatusItemController.resting[i]
            bar.transform = CATransform3DMakeScale(1, Self.barHeight(level) / Self.barHeight(1), 1)
        }
        bird.removeAllAnimations()
        bird.position = CGPoint(x: 0, y: Self.barTop(mode == .idle ? 0.15 : StatusItemController.resting[3]))
        CATransaction.commit()

        guard mode == .playing else { return }
        for (i, bar) in bars.enumerated() {
            let range = Self.ranges[i]
            let bounce = CABasicAnimation(keyPath: "transform.scale.y")
            bounce.fromValue = Self.barHeight(range.low) / Self.barHeight(1)
            bounce.toValue = Self.barHeight(range.high) / Self.barHeight(1)
            bounce.duration = range.duration
            bounce.autoreverses = true
            bounce.repeatCount = .infinity
            bounce.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            bar.add(bounce, forKey: "bounce")
            if i == 3 {
                // The bird rides the last bar, in step with it.
                let ride = CABasicAnimation(keyPath: "position.y")
                ride.fromValue = Self.barTop(range.low)
                ride.toValue = Self.barTop(range.high)
                ride.duration = range.duration
                ride.autoreverses = true
                ride.repeatCount = .infinity
                ride.timingFunction = bounce.timingFunction
                bird.add(ride, forKey: "ride")
            }
        }
    }

    // MARK: Shapes (shared with the still image)

    static func barHeight(_ level: Double) -> Double { 2 + 7.5 * level }
    static func barTop(_ level: Double) -> Double { 1.5 + barHeight(level) }

    static func barsPath(levels: [Double]) -> CGPath {
        let path = CGMutablePath()
        for (i, level) in levels.enumerated() {
            path.addRoundedRect(in: CGRect(x: 1.5 + Double(i) * 3.75, y: 1.5, width: 2.75, height: barHeight(level)),
                                cornerWidth: 1, cornerHeight: 1)
        }
        return path
    }

    private static func body(barTop: Double) -> CGRect {
        CGRect(x: 11.6, y: barTop + 0.3, width: 6.4, height: 5.4)
    }

    /// Round body sitting on `barTop`, with the eye as a hole (fill even-odd).
    static func birdBodyPath(barTop: Double) -> CGPath {
        let body = body(barTop: barTop)
        let path = CGMutablePath()
        path.addEllipse(in: body)
        path.addEllipse(in: CGRect(x: 15.2, y: body.midY + 0.2, width: 1.3, height: 1.3))
        return path
    }

    /// Beak pointing right.
    static func beakPath(barTop: Double) -> CGPath {
        let body = body(barTop: barTop)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 17.4, y: body.midY + 1.2))
        path.addLine(to: CGPoint(x: 20.6, y: body.midY))
        path.addLine(to: CGPoint(x: 17.4, y: body.midY - 1.2))
        path.closeSubpath()
        return path
    }
}
