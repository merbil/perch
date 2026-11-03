import AppKit
import SwiftUI

/// Borderless panel for Perch's own popups (the menu and the tutorial).
final class PopupPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
    }
    override var canBecomeKey: Bool { true }
}

private final class ClickThroughHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// The menu that drops from the menu bar icon. Closes on a click elsewhere or Esc.
@MainActor
final class MenuPanelController {
    private let panel = PopupPanel()
    private var monitors: [Any] = []
    var isOpen: Bool { panel.isVisible }

    init<Content: View>(content: Content) {
        let host = ClickThroughHostingView(rootView: content)
        panel.contentView = host
    }

    func toggle(below buttonFrame: NSRect?) {
        isOpen ? close() : open(below: buttonFrame)
    }

    func open(below buttonFrame: NSRect?) {
        guard let host = panel.contentView else { return }
        let screen = NSScreen.screens.first { screen in buttonFrame.map { screen.frame.intersects($0) } ?? false }
            ?? NSScreen.main ?? NSScreen.screens[0]
        // Never taller than the screen below the menu bar; the menu scrolls instead.
        var size = host.fittingSize
        size.height = min(size.height, screen.visibleFrame.height - 8)
        let anchorX = buttonFrame?.minX ?? screen.visibleFrame.maxX - size.width
        let x = min(max(anchorX - 12, screen.frame.minX + 8), screen.frame.maxX - size.width - 8)
        let y = screen.visibleFrame.maxY - size.height - 4
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1
        }

        // A click outside closes it; so does Esc.
        if let outside = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }) { monitors.append(outside) }
        if let escape = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            guard event.keyCode == 53 else { return event }
            MainActor.assumeIsolated { self?.close() }
            return nil
        }) { monitors.append(escape) }
    }

    func close() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        guard panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            panel.animator().alphaValue = 0
        }, completionHandler: { [panel] in
            panel.orderOut(nil)
        })
    }
}

/// The tutorial card, centred on screen and movable by its background.
@MainActor
final class TutorialWindowController {
    private let panel = PopupPanel()

    init<Content: View>(content: Content) {
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.contentView = ClickThroughHostingView(rootView: content)
    }

    func show() {
        guard let host = panel.contentView else { return }
        let size = host.fittingSize
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let frame = screen.visibleFrame
        panel.setFrame(NSRect(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2,
                              width: size.width, height: size.height), display: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        panel.orderOut(nil)
    }
}
