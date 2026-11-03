import AppKit
import SwiftUI

/// Tells the Stage window about every mouse move over it, also while another app is in front.
private final class StageHostingView<Content: View>: NSHostingView<Content> {
    var onMove: () -> Void = {}
    private var area: NSTrackingArea?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area { removeTrackingArea(area) }
        let new = NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                 owner: self, userInfo: nil)
        addTrackingArea(new)
        area = new
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        onMove()
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onMove()
    }
}

/// Stage: the big, resizable window, a normal window that isn't on top. While it's open Perch
/// is in the Dock and Cmd-Tab. "Start when idle" opens a full-screen version of it over everything
/// that closes again on any mouse or keyboard input.
@MainActor
final class StageController: NSObject, NSWindowDelegate {
    private let player: PlayerModel
    private let prefs: Preferences
    private let state = StageState()
    private let screensaverState = StageState()
    private var window: NSWindow?
    private var screensaver: NSWindow?
    private var hideTimer: Timer?
    private var idleTimer: Timer?
    private var wakeTimer: Timer?

    init(player: PlayerModel, prefs: Preferences) {
        self.player = player
        self.prefs = prefs
        screensaverState.isScreensaver = true
        screensaverState.controlsShown = false
        super.init()
    }

    // MARK: Window

    func toggle() {
        window?.isVisible == true ? window?.close() : open()
    }

    func open() {
        closeScreensaver()
        let window = self.window ?? makeWindow()
        self.window = window
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        prefs.isStageOpen = true
        showControls()
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 880, height: 520),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = "Perch"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 200, height: 200)
        window.collectionBehavior = [.fullScreenPrimary, .managed]
        window.delegate = self
        let host = StageHostingView(rootView: stageView(state))
        host.onMove = { [weak self] in self?.showControls() }
        window.contentView = host
        window.center()
        window.setFrameAutosaveName("PerchStage")
        return window
    }

    private func stageView(_ state: StageState) -> some View {
        StageView().environment(state).environment(player).environment(prefs)
    }

    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === window else { return }
        hideTimer?.invalidate()
        prefs.isStageOpen = false
        NSApp.setActivationPolicy(.accessory)
    }

    func windowDidEnterFullScreen(_ notification: Notification) { state.isFullScreen = true }
    func windowDidExitFullScreen(_ notification: Notification) { state.isFullScreen = false }

    /// Controls and traffic lights out; they go again after three still seconds, the cursor too
    /// when it's over the window.
    private func showControls() {
        if !state.controlsShown {
            withAnimation(.easeOut(duration: 0.2)) { state.controlsShown = true }
            setTrafficLights(visible: true)
        }
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.hideControls() }
        }
    }

    private func hideControls() {
        guard let window, window.isVisible else { return }
        withAnimation(.easeIn(duration: 0.5)) { state.controlsShown = false }
        setTrafficLights(visible: false)
        if window.frame.contains(NSEvent.mouseLocation), NSApp.isActive { NSCursor.setHiddenUntilMouseMoves(true) }
    }

    private func setTrafficLights(visible: Bool) {
        let buttons: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        NSAnimationContext.runAnimationGroup { context in
            context.duration = visible ? 0.2 : 0.5
            for type in buttons { window?.standardWindowButton(type)?.animator().alphaValue = visible ? 1 : 0 }
        }
    }

    // MARK: Start when idle

    /// Seconds since the last mouse, trackpad or keyboard input anywhere. Needs no permission.
    private static var idleSeconds: Double {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }

    func startIdleWatch() {
        idleTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkIdle() }
        }
    }

    private func checkIdle() {
        let minutes = prefs.stageIdleMinutes
        guard minutes > 0, screensaver == nil, player.isPlaying, window?.isVisible != true,
              Self.idleSeconds >= Double(minutes * 60) else { return }
        openScreensaver()
    }

    private func openScreensaver() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let window = NSWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.isReleasedWhenClosed = false
        window.backgroundColor = .black
        window.contentView = NSHostingView(rootView: stageView(screensaverState))
        window.setFrame(screen.frame, display: true)
        window.alphaValue = 0
        window.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 1.5; window.animator().alphaValue = 1 }
        screensaver = window
        // Any input closes it: the idle time drops back under a second.
        wakeTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                if Self.idleSeconds < 1 { self?.closeScreensaver() }
            }
        }
    }

    private func closeScreensaver() {
        wakeTimer?.invalidate()
        wakeTimer = nil
        guard let window = screensaver else { return }
        screensaver = nil
        NSAnimationContext.runAnimationGroup({ $0.duration = 0.25; window.animator().alphaValue = 0 },
                                            completionHandler: { window.orderOut(nil) })
    }
}
