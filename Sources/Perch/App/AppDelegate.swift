import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let demo: Bool
    private var player: PlayerModel!
    private var prefs: Preferences!
    private var panel: PanelController!
    private var statusItem: StatusItemController!

    init(demo: Bool) {
        self.demo = demo
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Demo mode keeps its own settings so it never moves the real player around.
        prefs = Preferences(defaults: demo ? UserDefaults(suiteName: "com.merterbil.perch.demo")! : .standard)
        player = PlayerModel(source: demo ? DemoSource() : SpotifySource())
        panel = PanelController(player: player, prefs: prefs)
        statusItem = StatusItemController(player: player)

        statusItem.onLeftClick = { [weak self] in self?.panel.toggle() }
        statusItem.onRightClick = { [weak self] in self?.panel.showDeck() }
        statusItem.isPerchVisible = { [weak self] in self?.panel.isVisible ?? false }
        panel.statusButtonFrame = { [weak self] in self?.statusItem.buttonFrame }
        player.onRefresh = { [weak self] in self?.statusItem.update() }

        player.start()
        if prefs.isShown { panel.show() }
    }
}
