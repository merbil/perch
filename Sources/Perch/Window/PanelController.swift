import AppKit
import SwiftUI

/// Borderless, always-on-top panel that never steals focus. Left-mouse events go through the
/// controller first, so a press either becomes a drag (moved by us) or a normal click.
final class PerchPanel: NSPanel {
    weak var controller: PanelController?
    private var heldMouseDown: NSEvent?

    /// AppKit keeps windows below the menu bar; the top pill has to slide up behind it to tuck.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }

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
        acceptsMouseMovedEvents = true
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

/// Perch is never the active app (so it never steals focus), and macOS only sends plain mouse
/// movement to the active app's windows. An always-on tracking area gets it anyway, for the
/// resize arrows over the tucked art.
private final class PerchHostingView<Content: View>: NSHostingView<Content> {
    var cursorFor: (NSPoint) -> NSCursor? = { _ in nil }
    private var area: NSTrackingArea?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area { removeTrackingArea(area) }
        let options: NSTrackingArea.Options = [.mouseMoved, .mouseEnteredAndExited, .cursorUpdate, .activeAlways, .inVisibleRect]
        let new = NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil)
        addTrackingArea(new)
        area = new
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        // After SwiftUI, so its own cursor doesn't win.
        if let cursor = cursorFor(event.locationInWindow) { cursor.set() }
    }

    override func cursorUpdate(with event: NSEvent) {
        if let cursor = cursorFor(event.locationInWindow) { cursor.set() } else { super.cursorUpdate(with: event) }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        NSCursor.arrow.set()
    }
}

@MainActor
final class PanelController {
    let panel = PerchPanel()
    let state: PanelState
    private let prefs: Preferences
    private let player: PlayerModel
    /// Where the menu bar icon is, for hanging the deck under it.
    var statusButtonFrame: () -> NSRect? = { nil }
    /// The card's Stage button. Set up by AppDelegate.
    var openStage: () -> Void = {}

    private(set) var isVisible = false

    /// Which edge of the pill, tab or tucked art is being pulled. `outer` is the side facing away from the screen edge.
    private enum ResizeAxis { case top, bottom, outer }
    private enum Press { case idle, pending, moving, resizing(ResizeAxis), finished }
    private var press: Press = .idle
    private var pressMouse = NSPoint.zero
    private var pressOrigin = NSPoint.zero
    private var resizeCandidate: ResizeAxis?
    private var swipe: CGFloat = 0
    private var swipeDone = false
    /// Tucked art is mostly inside the edge until the pointer comes near.
    private var tuckedOut = false
    private var peekWork: DispatchWorkItem?
    private var morphing = false
    private var lastView: ViewChoice
    private var lastPosition: PositionChoice

    init(player: PlayerModel, prefs: Preferences) {
        self.player = player
        self.prefs = prefs
        state = PanelState(form: prefs.form)
        state.tabHeight = Layout.tabHeight(for: player.title)
        lastView = prefs.view
        lastPosition = prefs.position

        let root = PlayerRoot()
            .environment(state)
            .environment(prefs)
            .environment(player)
        let host = PerchHostingView(rootView: root)
        panel.contentView = host
        panel.controller = self
        host.cursorFor = { [weak self] point in
            MainActor.assumeIsolated { self?.resizeCursor(at: point) }
        }

        state.minimise = { [weak self] in self?.switchCard(to: .cardMini) }
        state.openStage = { [weak self] in self?.openStage() }
        state.expand = { [weak self] in self?.switchCard(to: .card) }
        state.tuckedHover = { [weak self] in self?.tuckedHoverChanged($0) }
        observeViewSettings()
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

    /// Right click on the menu bar icon and the menu's switch: hides or shows Perch completely.
    func toggle() {
        isVisible ? hide() : show()
    }

    /// `remember: false` is for moves between forms, which shouldn't flip the Show setting.
    func show(on screen: NSScreen? = nil, remember: Bool = true) {
        guard !isVisible else { return }
        isVisible = true
        if remember { prefs.isShown = true }
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

    func hide(remember: Bool = true, completion: (() -> Void)? = nil) {
        guard isVisible else { completion?(); return }
        isVisible = false
        if remember { prefs.isShown = false }
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
            hide(remember: false) { [weak self] in self?.presentDeck() }
        } else {
            presentDeck()
        }
    }

    private func presentDeck() {
        setFormQuietly(.deck)
        show(on: menuBarScreen, remember: false)
        prefs.isShown = true
    }

    func rollIn() {
        // With the Deck view chosen there's nothing to go back to: it just hides.
        let previous = prefs.view == .deck ? nil : prefs.formBeforeDeck
        hide(remember: previous == nil) { [weak self] in
            guard let self, let previous else { return }
            self.setFormQuietly(previous)
            self.show(remember: false)
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

    /// Between two looks on the same edge (pill, tab, tucked art): the old one slides into the
    /// edge, the new one slides back out. Swapping in place made the content jump.
    private func morph(to form: Form) {
        let old = state.form
        guard let edge = old.edge, form.edge == edge, isVisible, !prefs.reduceMotion, !morphing else {
            setForm(form)
            return
        }
        morphing = true
        let screen = currentScreen
        animate(duration: 0.14, {
            self.panel.animator().setFrame(self.offscreen(self.panel.frame, for: old), display: true)
        }, completion: {
            self.setFormQuietly(form)
            let target = self.targetFrame(form, on: screen)
            self.panel.setFrame(self.offscreen(target, for: form), display: true)
            self.animate(duration: 0.24, {
                self.panel.animator().setFrame(target, display: true)
            }, completion: {
                self.morphing = false
            })
        })
    }

    private func setFormQuietly(_ form: Form) {
        state.form = form
        prefs.form = form
        tuckedOut = false
    }

    /// Card ⇄ album art. A fixed Card or Art view follows along.
    private func switchCard(to form: Form) {
        if prefs.view == .card || prefs.view == .art {
            lastView = form == .card ? .card : .art
            prefs.view = lastView
        }
        setForm(form)
    }

    /// Called after every player refresh: the tab follows the title's length.
    func playerChanged() {
        let height = Layout.tabHeight(for: player.title)
        guard height != state.tabHeight else { return }
        state.tabHeight = height
        guard case .tab = state.form, isVisible, case .idle = press else { return }
        animate(duration: 0.2) {
            self.panel.animator().setFrame(self.targetFrame(self.state.form, on: self.currentScreen), display: true)
        }
    }

    func targetFrame(_ form: Form, on screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        let size = Layout.windowSize(for: form, tabHeight: state.tabHeight)
        var origin = NSPoint.zero

        switch form {
        case .pill(let edge), .tucked(let edge), .tab(let edge):
            switch edge {
            case .left, .right:
                let along = prefs.along >= 0 ? prefs.along : visible.midY
                origin.x = edge == .left ? visible.minX : visible.maxX - size.width
                origin.y = clamp(along - size.height / 2, visible.minY, visible.maxY - size.height)
            case .bottom, .top:
                let along = prefs.along >= 0 ? prefs.along : visible.midX
                origin.x = clamp(along - size.width / 2, visible.minX, visible.maxX - size.width)
                origin.y = edge == .bottom ? visible.minY : visible.maxY - size.height
            }
            if case .tucked = form, !tuckedOut, prefs.tuckedStyle == .peek {
                let hidden = (edge.isSide ? size.width : size.height) - Layout.peek
                switch edge {
                case .left: origin.x -= hidden
                case .right: origin.x += hidden
                case .bottom: origin.y -= hidden
                case .top: origin.y += hidden
                }
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
        if flat.contains(.top) && (form == .deck || form.edge == .top) { out.origin.y += frame.height }
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

        resizeCandidate = resizeZone(at: event.locationInWindow)
    }

    /// The tucked art can be resized from its free sides: wider → pill, taller → tab.
    /// The pill, tab and tucked art can be resized from their free sides (see `resized`).
    private func resizeZone(at point: NSPoint) -> ResizeAxis? {
        guard let edge = state.form.edge else { return nil }
        let insets = Layout.insets(for: state.form)
        let size = panel.frame.size
        let content = NSRect(x: insets.leading, y: insets.bottom,
                             width: size.width - insets.leading - insets.trailing,
                             height: size.height - insets.top - insets.bottom)
        let zone: CGFloat = if case .tucked = state.form { 20 } else { 12 }
        guard content.insetBy(dx: -4, dy: -4).contains(point) else { return nil }
        switch edge {
        case .left where point.x > content.maxX - zone: return .outer
        case .right where point.x < content.minX + zone: return .outer
        case .bottom where point.y > content.maxY - zone: return .outer
        case .top where point.y < content.minY + zone: return .outer
        default: break
        }
        guard edge.isSide else { return nil }
        if point.y > content.maxY - zone { return .top }
        if point.y < content.minY + zone { return .bottom }
        return nil
    }

    /// Pulling a grip: outward makes it bigger (tucked → pill or tab, tab → pill, pill top/bottom → tab),
    /// pushing back in makes it smaller (pill or tab → tucked).
    private func resized(_ grip: ResizeAxis, dx: CGFloat, dy: CGFloat) -> Form? {
        guard let edge = state.form.edge else { return nil }
        let outward: CGFloat = switch edge {
        case .left: dx
        case .right: -dx
        case .bottom: dy
        case .top: -dy
        }
        let grow: CGFloat = grip == .top ? dy : -dy
        let threshold: CGFloat = 24
        switch (state.form, grip) {
        case (.tucked, .outer) where outward > threshold:
            return prefs.view == .tab && edge.isSide ? .tab(edge) : .pill(edge)
        case (.tucked, .top), (.tucked, .bottom):
            return grow > threshold && prefs.view != .pill ? .tab(edge) : (grow > threshold ? .pill(edge) : nil)
        case (.tab, .outer) where outward > threshold:
            return .pill(edge)
        case (.tab, .top), (.tab, .bottom):
            return grow < -threshold ? .tucked(edge) : nil
        case (.pill, .outer) where outward < -threshold:
            return .tucked(edge)
        case (.pill, .top), (.pill, .bottom):
            return grow > threshold ? .tab(edge) : nil
        default:
            return nil
        }
    }

    /// Resize arrows over the tucked art's grips, so it's clear they can be pulled.
    private func resizeCursor(at point: NSPoint) -> NSCursor? {
        let grip: ResizeAxis?
        if case .resizing(let pulled) = press { grip = pulled } else if case .idle = press { grip = resizeZone(at: point) } else { grip = nil }
        guard let grip else { return nil }
        let sideways = grip == .outer && state.form.edge?.isSide == true
        return sideways ? .resizeLeftRight : .resizeUpDown
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
            if state.form == .deck, dy > -50 {
                // The deck slides along the menu bar; pulled further down it comes off.
                let screen = panel.screen ?? menuBarScreen
                let x = clamp(pressOrigin.x + dx, screen.frame.minX, screen.frame.maxX - panel.frame.width)
                panel.setFrameOrigin(NSPoint(x: x, y: pressOrigin.y))
            } else {
                panel.setFrameOrigin(NSPoint(x: pressOrigin.x + dx, y: pressOrigin.y + dy))
            }
            updateGhost()
        case .resizing(let grip):
            if let form = resized(grip, dx: dx, dy: dy) {
                press = .finished
                morph(to: form)
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

    /// Where it's let go picks the form. In Auto: corner → tile, edge (top too) → pill,
    /// elsewhere → card (or the closest wall's pill with "Stick to the closest wall").
    /// A fixed view keeps its look and only moves.
    private func dropped() {
        hideGhost()
        guard let (form, screen) = landing() else { return }
        setForm(form, on: screen)
    }

    /// The form and screen a drop right now would give, also saving where along the edge (or
    /// where on screen) it goes. Nil when a fixed view finds no spot.
    private func landing() -> (Form, NSScreen)? {
        let mouse = NSEvent.mouseLocation
        let frame = panel.frame
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? currentScreen
        let visible = screen.visibleFrame
        let center = NSPoint(x: frame.midX, y: frame.midY)

        if state.form == .deck {
            // Let go near the top (or with the Deck view chosen): it hangs from the menu bar again.
            if mouse.y >= visible.maxY - 60 || prefs.view == .deck {
                prefs.deckCenterX = frame.midX
                return (.deck, screen)
            }
            prefs.formBeforeDeck = nil
        }

        guard prefs.view == .auto else {
            return form(for: prefs.view, near: center, on: screen).map { ($0, screen) }
        }

        let cornerZone: CGFloat = 110
        let edgeZone: CGFloat = 90
        let left = mouse.x - visible.minX, right = visible.maxX - mouse.x
        let bottom = mouse.y - visible.minY, top = visible.maxY - mouse.y

        if min(left, right) < cornerZone, min(bottom, top) < cornerZone {
            return form(for: .tile, near: mouse, on: screen).map { ($0, screen) }
        }

        if min(left, right, bottom, top) < edgeZone || prefs.position == .stick {
            let keepTab: Bool = if case .tab = state.form { true } else { false }
            return form(for: keepTab ? .tab : .pill, near: center, on: screen).map { ($0, screen) }
        }

        prefs.cardCenterX = center.x
        prefs.cardCenterY = center.y
        return (state.form == .cardMini ? .cardMini : .card, screen)
    }

    // MARK: Drop preview

    /// In Auto, a frosted shape where Perch will land, like macOS's own tiling preview.
    private lazy var ghost = DropGhost()

    private func updateGhost() {
        guard prefs.view == .auto, !(state.form == .deck && panel.frame.maxY >= currentScreen.visibleFrame.maxY - 1) else {
            hideGhost()
            return
        }
        // A dry run of the drop: remember the saved spots, ask, put them back.
        let saved = (prefs.along, prefs.cardCenterX, prefs.cardCenterY, prefs.deckCenterX, prefs.formBeforeDeck)
        let result = landing()
        let target = result.map { targetFrame($0.0, on: $0.1) }
        (prefs.along, prefs.cardCenterX, prefs.cardCenterY, prefs.deckCenterX, prefs.formBeforeDeck) = saved
        guard let result, let target else { hideGhost(); return }
        let insets = Layout.insets(for: result.0)
        let content = NSRect(x: target.minX + insets.leading, y: target.minY + insets.bottom,
                             width: target.width - insets.leading - insets.trailing,
                             height: target.height - insets.top - insets.bottom)
        ghost.show(content, flat: result.0.flatSides, below: panel, animated: !prefs.reduceMotion)
    }

    private func hideGhost() {
        ghost.hide()
    }

    /// The form a view takes near a point: the closest wall for pill and tab, the closest corner
    /// for the tile, and right there for card and art (or against the closest wall with "Stick").
    private func form(for view: ViewChoice, near point: NSPoint, on screen: NSScreen) -> Form? {
        let visible = screen.visibleFrame
        let left = point.x - visible.minX, right = visible.maxX - point.x
        let bottom = point.y - visible.minY, top = visible.maxY - point.y
        let side: ScreenEdge = left <= right ? .left : .right
        let wall: ScreenEdge = min(bottom, top) < min(left, right) ? (bottom <= top ? .bottom : .top) : side
        let isTucked: Bool = if case .tucked = state.form { true } else { false }

        switch view {
        case .auto, .deck:
            return nil
        case .pill:
            prefs.along = wall.isSide ? point.y : point.x
            return isTucked ? .tucked(wall) : .pill(wall)
        case .tab:
            prefs.along = point.y
            return isTucked ? .tucked(side) : .tab(side)
        case .tile:
            let corner: ScreenCorner = switch (left <= right, bottom <= top) {
            case (true, true): .bottomLeft
            case (true, false): .topLeft
            case (false, true): .bottomRight
            case (false, false): .topRight
            }
            return .tile(corner)
        case .card, .art:
            let form: Form = view == .card ? .card : .cardMini
            let size = Layout.windowSize(for: form)
            var center = point
            if prefs.position == .stick {
                switch min(left, right, bottom, top) {
                case left: center.x = visible.minX + size.width / 2
                case right: center.x = visible.maxX - size.width / 2
                case bottom: center.y = visible.minY + size.height / 2
                default: center.y = visible.maxY - size.height / 2
                }
            }
            prefs.cardCenterX = center.x
            prefs.cardCenterY = center.y
            return form
        }
    }

    // MARK: View settings

    private func observeViewSettings() {
        withObservationTracking {
            _ = prefs.view
            _ = prefs.position
            _ = prefs.tuckedStyle
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.viewSettingsChanged()
                self?.observeViewSettings()
            }
        }
    }

    /// The View or Position setting changed: switch the player over right away.
    private func viewSettingsChanged() {
        // The tucked style only moves the window in or out of the edge.
        if case .tucked = state.form, isVisible, case .idle = press {
            animate(duration: 0.2) {
                self.panel.animator().setFrame(self.targetFrame(self.state.form, on: self.currentScreen), display: true)
            }
        }
        guard prefs.view != lastView || prefs.position != lastPosition else { return }
        lastView = prefs.view
        lastPosition = prefs.position

        if prefs.view == .deck {
            showDeck()
            return
        }
        let screen = currentScreen
        let frame = isVisible ? panel.frame : targetFrame(state.form, on: screen)
        let center = NSPoint(x: frame.midX, y: frame.midY)

        let target: Form?
        if prefs.view == .auto {
            // Auto keeps the current look, except a floating card sticks to a wall with "Stick".
            let floating = state.form == .card || state.form == .cardMini
            target = prefs.position == .stick && floating ? form(for: .pill, near: center, on: screen) : nil
        } else {
            target = form(for: prefs.view, near: center, on: screen)
        }
        guard let target, target != state.form else { return }

        if state.form == .deck {
            prefs.formBeforeDeck = nil
            hide(remember: false) { [weak self] in
                self?.setFormQuietly(target)
                self?.show(remember: false)
            }
        } else if isVisible {
            setForm(target, on: screen)
        } else {
            setFormQuietly(target)
            show()
        }
    }

    // MARK: Tucked peek

    private func tuckedHoverChanged(_ hovering: Bool) {
        peekWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.setTuckedOut(hovering) }
        }
        peekWork = work
        // Out quickly, back in after a short pause so it doesn't flicker.
        DispatchQueue.main.asyncAfter(deadline: .now() + (hovering ? 0.08 : 0.7), execute: work)
    }

    private func setTuckedOut(_ out: Bool) {
        guard case .tucked = state.form, isVisible, tuckedOut != out, case .idle = press, !morphing else { return }
        tuckedOut = out
        animate(duration: 0.2) {
            self.panel.animator().setFrame(self.targetFrame(self.state.form, on: self.currentScreen), display: true)
        }
    }

    // MARK: Swipe to tuck

    /// Two-finger swipe into the edge tucks the pill or tab away (like dismissing a notification);
    /// swiping out again brings the pill back.
    func scrolled(_ event: NSEvent) {
        guard let edge = state.form.edge, [.auto, .pill, .tab].contains(prefs.view) else { return }
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
        case .top: -fingersDown
        }
        swipe += towardEdge

        switch state.form {
        case .pill, .tab:
            if swipe > 40 { swipeDone = true; morph(to: .tucked(edge)) }
        case .tucked:
            if swipe < -40 { swipeDone = true; morph(to: .pill(edge)) }
        default:
            break
        }
    }

    // MARK: Helpers

    private func animate(duration: TimeInterval, _ changes: @escaping () -> Void, completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = prefs.reduceMotion ? 0 : duration
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
