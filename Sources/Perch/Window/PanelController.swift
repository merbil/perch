import AppKit
import SwiftUI

/// Borderless, always-on-top panel that never steals focus. Left-mouse events go through the
/// controller first, so a press either becomes a drag (moved by us) or a normal click.
final class PerchPanel: NSPanel {
    weak var controller: PanelController?
    private var heldMouseDown: NSEvent?

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        isMovable = false
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        guard let controller else { return super.sendEvent(event) }
        switch event.type {
        case .leftMouseDown:
            // Hold the press until we know whether it's a click or a drag.
            heldMouseDown = event
            MainActor.assumeIsolated { controller.beginPress(event) }
            return
        case .leftMouseDragged:
            MainActor.assumeIsolated { controller.dragged(event) }
            return
        case .leftMouseUp:
            let wasDrag = MainActor.assumeIsolated { controller.endPress(event) }
            let down = heldMouseDown
            heldMouseDown = nil
            if wasDrag { return }
            if let down { super.sendEvent(down) }
            super.sendEvent(event)
            return
        case .scrollWheel:
            MainActor.assumeIsolated { controller.scrolled(event) }
        default:
            break
        }
        super.sendEvent(event)
    }
}

private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
final class PanelController {
    let panel = PerchPanel()
    let state: PanelState
    private let prefs: Preferences
    private let player: PlayerModel
    /// Where the menu bar icon is, for hanging the deck under it.
    var statusButtonFrame: () -> NSRect? = { nil }

    private(set) var isVisible = false

    private enum ResizeAxis { case wider, taller }
    private enum Press { case idle, pending, moving, resizing(ResizeAxis), finished }
    private var press: Press = .idle
    private var pressMouse = NSPoint.zero
    private var pressOrigin = NSPoint.zero
    private var resizeCandidate: ResizeAxis?
    private var swipe: CGFloat = 0
    private var swipeDone = false

    init(player: PlayerModel, prefs: Preferences) {
        self.player = player
        self.prefs = prefs
        state = PanelState(form: prefs.form)

        let root = PlayerRoot()
            .environment(state)
            .environment(prefs)
            .environment(player)
        panel.contentView = FirstMouseHostingView(rootView: root)
        panel.controller = self

        state.minimise = { [weak self] in self?.setForm(.cardMini) }
        state.expand = { [weak self] in self?.setForm(.card) }
        state.rollIn = { [weak self] in self?.rollIn() }
        state.showDeck = { [weak self] in self?.showDeck() }
        state.hide = { [weak self] in self?.hide() }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isVisible else { return }
                self.panel.setFrame(self.targetFrame(self.state.form, on: self.currentScreen), display: true)
            }
        }
    }

    private var currentScreen: NSScreen {
        panel.screen ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private var menuBarScreen: NSScreen {
        NSScreen.screens.first { screen in
            statusButtonFrame().map { screen.frame.intersects($0) } ?? false
        } ?? NSScreen.screens[0]
    }

    // MARK: Showing and hiding

    /// Left click on the menu bar icon. The deck only goes away with its own roll-in button.
    func toggle() {
        if isVisible {
            if state.form != .deck { hide() }
        } else {
            show()
        }
    }

    func show(on screen: NSScreen? = nil) {
        guard !isVisible else { return }
        isVisible = true
        prefs.isShown = true
        let screen = screen ?? (state.form == .deck ? menuBarScreen : currentScreen)
        let target = targetFrame(state.form, on: screen)
        let floats = !state.form.slidesFromEdge
        panel.setFrame(floats ? target : offscreen(target, for: state.form), display: false)
        panel.alphaValue = floats ? 0 : 1
        panel.orderFrontRegardless()
        animate(duration: 0.3) {
            self.panel.animator().setFrame(target, display: true)
            self.panel.animator().alphaValue = 1
        }
    }

    func hide(completion: (() -> Void)? = nil) {
        guard isVisible else { completion?(); return }
        isVisible = false
        prefs.isShown = false
        let current = panel.frame
        let floats = !state.form.slidesFromEdge
        animate(duration: 0.25, {
            if floats {
                self.panel.animator().alphaValue = 0
            } else {
                self.panel.animator().setFrame(self.offscreen(current, for: self.state.form), display: true)
            }
        }, completion: {
            self.panel.orderOut(nil)
            self.panel.alphaValue = 1
            completion?()
        })
    }

    /// Right click on the menu bar icon, or a drag up into the menu bar.
    func showDeck() {
        if state.form == .deck {
            if !isVisible { show(on: menuBarScreen) }
            return
        }
        prefs.formBeforeDeck = isVisible ? state.form : nil
        prefs.deckCenterX = nil   // opens under the icon; can be dragged along the menu bar afterwards
        if isVisible {
            hide { [weak self] in self?.presentDeck() }
        } else {
            presentDeck()
        }
    }

    private func presentDeck() {
        setFormQuietly(.deck)
        show(on: menuBarScreen)
    }

    func rollIn() {
        let previous = prefs.formBeforeDeck
        hide { [weak self] in
            guard let self, let previous else { return }
            self.setFormQuietly(previous)
            self.show()
        }
    }

    // MARK: Forms

    func setForm(_ form: Form, on screen: NSScreen? = nil) {
        setFormQuietly(form)
        let target = targetFrame(form, on: screen ?? currentScreen)
        animate(duration: 0.22) {
            self.panel.animator().setFrame(target, display: true)
        }
    }

    private func setFormQuietly(_ form: Form) {
        state.form = form
        prefs.form = form
    }

    func targetFrame(_ form: Form, on screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        let size = Layout.windowSize(for: form)
        var origin = NSPoint.zero

        switch form {
        case .pill(let edge), .tucked(let edge), .tab(let edge):
            switch edge {
            case .left, .right:
                let along = prefs.along >= 0 ? prefs.along : visible.midY
                origin.x = edge == .left ? visible.minX : visible.maxX - size.width
                origin.y = clamp(along - size.height / 2, visible.minY, visible.maxY - size.height)
            case .bottom:
                let along = prefs.along >= 0 ? prefs.along : visible.midX
                origin.x = clamp(along - size.width / 2, visible.minX, visible.maxX - size.width)
                origin.y = visible.minY
            }
        case .tile(let corner):
            let sides = corner.sides
            origin.x = sides.contains(.left) ? visible.minX : visible.maxX - size.width
            origin.y = sides.contains(.bottom) ? visible.minY : visible.maxY - size.height
        case .card, .cardMini:
            let centerX = prefs.cardCenterX >= 0 ? prefs.cardCenterX : visible.midX
            let centerY = prefs.cardCenterY >= 0 ? prefs.cardCenterY : visible.midY
            origin.x = clamp(centerX - size.width / 2, visible.minX, visible.maxX - size.width)
            origin.y = clamp(centerY - size.height / 2, visible.minY, visible.maxY - size.height)
        case .deck:
            let centerX = prefs.deckCenterX ?? statusButtonFrame()?.midX ?? visible.maxX - 220
            origin.x = clamp(centerX - size.width / 2, screen.frame.minX, screen.frame.maxX - size.width)
            origin.y = visible.maxY - size.height
        }
        return NSRect(origin: origin, size: size)
    }

    /// The same frame pushed out past the edge it's stuck to, for slide in/out.
    private func offscreen(_ frame: NSRect, for form: Form) -> NSRect {
        let flat = form.flatSides
        var out = frame
        if flat.contains(.top) && form == .deck { out.origin.y += frame.height }
        else if flat.contains(.left) { out.origin.x -= frame.width }
        else if flat.contains(.right) { out.origin.x += frame.width }
        else if flat.contains(.bottom) { out.origin.y -= frame.height }
        return out
    }

    // MARK: Dragging

    func beginPress(_ event: NSEvent) {
        press = .pending
        pressMouse = NSEvent.mouseLocation
        pressOrigin = panel.frame.origin
        resizeCandidate = nil

        // The tucked art can be resized from its free sides: wider → pill, taller → tab.
        if case .tucked(let edge) = state.form {
            let point = event.locationInWindow
            let content = NSRect(origin: .zero, size: panel.frame.size)
            let zone: CGFloat = 16
            switch edge {
            case .left where point.x > content.maxX - zone: resizeCandidate = .wider
            case .right where point.x < content.minX + zone: resizeCandidate = .wider
            case .bottom where point.y > content.maxY - zone: resizeCandidate = .wider
            default: break
            }
            if edge != .bottom, point.y > content.maxY - zone || point.y < content.minY + zone {
                resizeCandidate = .taller
            }
        }
    }

    func dragged(_ event: NSEvent) {
        let mouse = NSEvent.mouseLocation
        let dx = mouse.x - pressMouse.x
        let dy = mouse.y - pressMouse.y

        switch press {
        case .pending:
            guard hypot(dx, dy) >= 4 else { return }
            press = resizeCandidate.map { .resizing($0) } ?? .moving
            dragged(event)
        case .moving:
            if state.form == .deck {
                // The deck only slides along the menu bar.
                let screen = panel.screen ?? menuBarScreen
                let x = clamp(pressOrigin.x + dx, screen.frame.minX, screen.frame.maxX - panel.frame.width)
                panel.setFrameOrigin(NSPoint(x: x, y: pressOrigin.y))
            } else {
                panel.setFrameOrigin(NSPoint(x: pressOrigin.x + dx, y: pressOrigin.y + dy))
            }
        case .resizing(let axis):
            guard case .tucked(let edge) = state.form else { return }
            let amount: CGFloat
            switch axis {
            case .taller: amount = abs(dy)
            case .wider: amount = edge == .left ? dx : edge == .right ? -dx : dy
            }
            if amount > 24 {
                press = .finished
                setForm(axis == .taller && edge != .bottom ? .tab(edge) : .pill(edge))
            }
        case .idle, .finished:
            break
        }
    }

    /// Returns true when the press was a drag (so it isn't also a click).
    func endPress(_ event: NSEvent) -> Bool {
        defer { press = .idle }
        switch press {
        case .idle, .pending: return false
        case .moving: dropped(); return true
        case .resizing, .finished: return true
        }
    }

    /// Where it's let go picks the form: menu bar → deck, corner → tile, edge → pill, else card.
    private func dropped() {
        let mouse = NSEvent.mouseLocation
        let frame = panel.frame
        if state.form == .deck {
            prefs.deckCenterX = frame.midX
            return
        }
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? currentScreen
        let visible = screen.visibleFrame

        if mouse.y >= visible.maxY - 2 {
            prefs.formBeforeDeck = state.form
            prefs.deckCenterX = frame.midX
            setForm(.deck, on: screen)
            return
        }

        let cornerZone: CGFloat = 110
        let edgeZone: CGFloat = 90
        let left = mouse.x - visible.minX, right = visible.maxX - mouse.x
        let bottom = mouse.y - visible.minY, top = visible.maxY - mouse.y

        if prefs.snapToCorners, min(left, right) < cornerZone, min(bottom, top) < cornerZone {
            let corner: ScreenCorner = switch (left < right, bottom < top) {
            case (true, true): .bottomLeft
            case (true, false): .topLeft
            case (false, true): .bottomRight
            case (false, false): .topRight
            }
            setForm(.tile(corner), on: screen)
            return
        }

        if prefs.snapToEdges, min(left, right, bottom) < edgeZone {
            let edge: ScreenEdge = left < edgeZone && left <= right ? .left : right < edgeZone ? .right : .bottom
            prefs.along = edge == .bottom ? frame.midX : frame.midY
            let form: Form = switch state.form {
            case .tucked: .tucked(edge)
            case .tab where edge != .bottom: .tab(edge)
            default: .pill(edge)
            }
            setForm(form, on: screen)
            return
        }

        prefs.cardCenterX = frame.midX
        prefs.cardCenterY = frame.midY
        setForm(state.form == .cardMini ? .cardMini : .card, on: screen)
    }

    // MARK: Swipe to tuck

    /// Two-finger swipe into the edge tucks the pill or tab away (like dismissing a notification);
    /// swiping out again brings the pill back.
    func scrolled(_ event: NSEvent) {
        guard let edge = state.form.edge else { return }
        if event.phase == .began { swipe = 0; swipeDone = false }
        guard event.phase == .began || event.phase == .changed, !swipeDone else { return }

        // Convert to finger direction regardless of the natural scrolling setting.
        let sign: CGFloat = event.isDirectionInvertedFromDevice ? 1 : -1
        let fingersRight = event.scrollingDeltaX * sign
        let fingersDown = event.scrollingDeltaY * sign
        let towardEdge: CGFloat = switch edge {
        case .left: -fingersRight
        case .right: fingersRight
        case .bottom: fingersDown
        }
        swipe += towardEdge

        switch state.form {
        case .pill, .tab:
            if swipe > 40 { swipeDone = true; setForm(.tucked(edge)) }
        case .tucked:
            if swipe < -40 { swipeDone = true; setForm(.pill(edge)) }
        default:
            break
        }
    }

    // MARK: Helpers

    private func animate(duration: TimeInterval, _ changes: @escaping () -> Void, completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            changes()
        }, completionHandler: completion)
    }
}

private extension Form {
    /// Stuck forms slide in from their edge; floating ones fade.
    var slidesFromEdge: Bool { !flatSides.isEmpty }
}

private func clamp(_ value: CGFloat, _ low: CGFloat, _ high: CGFloat) -> CGFloat {
    min(max(value, low), max(low, high))
}
