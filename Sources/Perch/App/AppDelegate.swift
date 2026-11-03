import AppKit
import Carbon.HIToolbox
import Observation
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let demo: Bool
    private var player: PlayerModel!
    private var prefs: Preferences!
    private var panel: PanelController!
    private var statusItem: StatusItemController!
    private var stage: StageController!
    private var menu: MenuPanelController!
    private var tutorial: TutorialWindowController?
    private var about: TutorialWindowController?
    private var permissionNotice: TutorialWindowController?
    private var hint: HintController?
    private var stageKey: HotKey?
    /// The "can't reach Spotify" popup shows once per launch at most.
    private var toldAboutPermission = false

    init(demo: Bool) {
        self.demo = demo
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Demo mode keeps its own settings so it never moves the real player around.
        prefs = Preferences(defaults: demo ? UserDefaults(suiteName: "com.merterbil.perch.demo")! : .standard)
        let spotify = demo ? nil : SpotifySource()
        player = PlayerModel(source: spotify ?? DemoSource())
        spotify?.onPermissionDenied = { [weak self] in self?.permissionDenied() }
        panel = PanelController(player: player, prefs: prefs)
        statusItem = StatusItemController(player: player, prefs: prefs)
        stage = StageController(player: player, prefs: prefs)

        let actions = MenuActions(
            toggleShown: { [weak self] in self?.toggleShown() },
            showTutorial: { [weak self] in
                self?.menu.close()
                self?.showTutorial()
            },
            showAbout: { [weak self] in
                self?.menu.close()
                self?.showAbout()
            },
            toggleStage: { [weak self] in
                self?.menu.close()
                self?.stage.toggle()
            }
        )
        menu = MenuPanelController(content: MenuView(actions: actions).environment(prefs).environment(player))

        statusItem.onLeftClick = { [weak self] in
            guard let self else { return }
            self.menu.toggle(below: self.statusItem.buttonFrame)
        }
        statusItem.onRightClick = { [weak self] in
            self?.menu.close()
            self?.panel.toggle()
        }
        panel.statusButtonFrame = { [weak self] in self?.statusItem.buttonFrame }
        panel.openStage = { [weak self] in self?.stage.open() }
        player.onRefresh = { [weak self] in
            self?.statusItem.update()
            self?.panel.playerChanged()
        }

        applyAppearance()
        player.start()
        // Demo runs never go online.
        if !demo { Updater.shared.start() }
        if prefs.isShown { panel.show() }
        stage.startIdleWatch()
        // Control-Command-P opens and closes Stage from anywhere.
        stageKey = HotKey(keyCode: kVK_ANSI_P, modifiers: controlKey | cmdKey) { [weak self] in self?.stage.toggle() }
        if !prefs.hasSeenTutorial {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.showTutorial() }
        }
    }

    /// Light, dark or the system's, for every Perch window. Follows the setting as it changes.
    private func applyAppearance() {
        withObservationTracking {
            NSApp.appearance = prefs.appearance.nsAppearance
        } onChange: { [weak self] in
            DispatchQueue.main.async { self?.applyAppearance() }
        }
    }

    /// The menu's switch, same as right-clicking the icon.
    private func toggleShown() {
        panel.toggle()
    }

    /// Under the menu bar icon after the first tutorial, so it's clear where Perch lives.
    private func showMenuBarHint() {
        hint = HintController(content: MenuBarHintView().environment(prefs).environment(player))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.hint?.show(below: self?.statusItem.buttonFrame)
        }
    }

    /// Spotify refused a script: explain once, with a button to the right Settings page.
    /// Not while the tutorial is up, which asks for the permission itself.
    private func permissionDenied() {
        guard !toldAboutPermission, tutorial == nil, prefs.hasSeenTutorial else { return }
        toldAboutPermission = true
        let view = PermissionView(
            openSettings: { [weak self] in
                SpotifyPermission().openSystemSettings()
                self?.permissionNotice?.close()
                self?.permissionNotice = nil
            },
            onClose: { [weak self] in
                self?.permissionNotice?.close()
                self?.permissionNotice = nil
            }
        )
        .environment(prefs)
        .environment(player)
        permissionNotice = TutorialWindowController(content: view)
        permissionNotice?.show()
    }

    private func showAbout() {
        let view = AboutView(onClose: { [weak self] in
            self?.about?.close()
            self?.about = nil
        })
        .environment(prefs)
        .environment(player)
        about?.close()
        about = TutorialWindowController(content: view)
        about?.show()
    }

    private func showTutorial() {
        let view = TutorialView(onDone: { [weak self] in
            guard let self else { return }
            let firstTime = !self.prefs.hasSeenTutorial
            self.prefs.hasSeenTutorial = true
            self.tutorial?.close()
            self.tutorial = nil
            if firstTime { self.showMenuBarHint() }
        })
        .environment(prefs)
        .environment(player)
        tutorial?.close()
        tutorial = TutorialWindowController(content: view)
        tutorial?.show()
    }
}
