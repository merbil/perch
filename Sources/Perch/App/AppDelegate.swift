import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let demo: Bool
    private var player: PlayerModel!
    private var prefs: Preferences!
    private var panel: PanelController!
    private var statusItem: StatusItemController!
    private var menu: MenuPanelController!
    private var tutorial: TutorialWindowController?

    init(demo: Bool) {
        self.demo = demo
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Demo mode keeps its own settings so it never moves the real player around.
        prefs = Preferences(defaults: demo ? UserDefaults(suiteName: "com.merterbil.perch.demo")! : .standard)
        player = PlayerModel(source: demo ? DemoSource() : SpotifySource())
        panel = PanelController(player: player, prefs: prefs)
        statusItem = StatusItemController(player: player)

        let actions = MenuActions(
            toggleShown: { [weak self] in self?.toggleShown() },
            showTutorial: { [weak self] in
                self?.menu.close()
                self?.showTutorial()
            }
        )
        menu = MenuPanelController(content: MenuView(actions: actions).environment(prefs).environment(player))

        statusItem.onLeftClick = { [weak self] in
            guard let self else { return }
            self.menu.toggle(below: self.statusItem.buttonFrame)
        }
        statusItem.onRightClick = { [weak self] in
            self?.menu.close()
            self?.panel.showDeck()
        }
        panel.statusButtonFrame = { [weak self] in self?.statusItem.buttonFrame }
        player.onRefresh = { [weak self] in
            self?.statusItem.update()
            self?.panel.playerChanged()
        }

        player.start()
        // Demo runs never go online.
        if !demo { Updater.shared.start() }
        if prefs.isShown { panel.show() }
        if !prefs.hasSeenTutorial {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.showTutorial() }
        }
    }

    /// The menu's switch. The deck stays out until its own button rolls it in.
    private func toggleShown() {
        if panel.isVisible {
            if panel.state.form == .deck { panel.rollIn() } else { panel.hide() }
        } else {
            panel.show()
        }
    }

    private func showTutorial() {
        let view = TutorialView(onDone: { [weak self] in
            self?.prefs.hasSeenTutorial = true
            self?.tutorial?.close()
            self?.tutorial = nil
        })
        .environment(prefs)
        .environment(player)
        tutorial?.close()
        tutorial = TutorialWindowController(content: view)
        tutorial?.show()
    }
}
