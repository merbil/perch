import AppKit
import SwiftUI

/// Renders each form with the demo player, for checking the look without running the app.
@MainActor
enum Snapshot {
    private struct Shot {
        var name: String
        var form: Form
        var hover = false
        var closed = false
        /// Which demo song: 0 short-ish, 1 long, 2 short.
        var song = 0
    }

    private static let shots: [Shot] = [
        Shot(name: "a-pill-right", form: .pill(.right)),
        Shot(name: "a-pill-left", form: .pill(.left)),
        Shot(name: "a-pill-bottom", form: .pill(.bottom)),
        Shot(name: "a-pill-top", form: .pill(.top)),
        Shot(name: "a-tucked-top-hover", form: .tucked(.top), hover: true),
        Shot(name: "a-tucked-right", form: .tucked(.right)),
        Shot(name: "a-tucked-right-hover", form: .tucked(.right), hover: true),
        Shot(name: "tab-left", form: .tab(.left)),
        Shot(name: "tab-left-hover", form: .tab(.left), hover: true),
        Shot(name: "tab-left-long-title", form: .tab(.left), song: 1),
        Shot(name: "tab-left-short-title", form: .tab(.left), song: 2),
        Shot(name: "c-card-long-title", form: .card, song: 1),
        Shot(name: "b-tile-bottom-left", form: .tile(.bottomLeft)),
        Shot(name: "b-tile-top-right-hover", form: .tile(.topRight), hover: true),
        Shot(name: "c-card", form: .card),
        Shot(name: "c-card-mini", form: .cardMini),
        Shot(name: "c-card-spotify-closed", form: .card, closed: true),
        Shot(name: "d-deck", form: .deck),
    ]

    static func run(to folder: URL) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let prefs = Preferences(defaults: UserDefaults(suiteName: "com.merterbil.perch.snapshot")!)
        let demo = PlayerModel(source: DemoSource())
        demo.refresh()
        let closed = PlayerModel(source: ClosedSource())
        closed.refresh()

        var rendered: [(Shot, NSImage)] = []
        for shot in shots {
            let player = shot.closed ? closed : shot.song == 0 ? demo : demoPlayer(song: shot.song)
            let state = PanelState(form: shot.form)
            state.forceHover = shot.hover
            state.tabHeight = Layout.tabHeight(for: player.title)
            let size = Layout.windowSize(for: shot.form, tabHeight: state.tabHeight)
            let view = PlayerRoot()
                .environment(state)
                .environment(prefs)
                .environment(player)
                .frame(width: size.width, height: size.height)
            if let image = render(view) {
                write(image, to: folder.appendingPathComponent("\(shot.name).png"))
                rendered.append((shot, image))
            }
        }

        // Dark mode versions of the main looks.
        for shot in [Shot(name: "dark-a-pill-right", form: .pill(.right)), Shot(name: "dark-c-card", form: .card),
                     Shot(name: "dark-b-tile-hover", form: .tile(.bottomLeft), hover: true), Shot(name: "dark-d-deck", form: .deck)] {
            let state = PanelState(form: shot.form)
            state.forceHover = shot.hover
            let size = Layout.windowSize(for: shot.form, tabHeight: state.tabHeight)
            let view = PlayerRoot().environment(state).environment(prefs).environment(demo)
                .frame(width: size.width, height: size.height)
            if let image = renderDark(view) {
                write(image, to: folder.appendingPathComponent("\(shot.name).png"))
                rendered.append((shot, image))
            }
        }
        if let image = renderDark(MenuView(actions: MenuActions()).environment(prefs).environment(demo)) {
            write(image, to: folder.appendingPathComponent("dark-menu.png"))
            rendered.append((Shot(name: "dark-menu", form: .card), image))
        }

        // Stage at a few window shapes; "full" is the dark look, "idle" the screensaver.
        for (name, width, height, full, controls) in [("stage-wide", 880.0, 520.0, false, true), ("stage-tall", 420.0, 680.0, false, true),
                                                       ("stage-small", 240.0, 240.0, false, true), ("stage-wide-still", 880.0, 520.0, false, false),
                                                       ("stage-full", 1440.0, 900.0, true, true)] {
            let stage = StageState()
            stage.isFullScreen = full
            stage.controlsShown = controls
            let view = StageView().environment(stage).environment(prefs).environment(demo).frame(width: width, height: height)
            if let image = render(view) { write(image, to: folder.appendingPathComponent("\(name).png")) }
        }
        if let image = renderDark(MenuView(actions: MenuActions()).environment(prefs).environment(demo)) {
            write(image, to: folder.appendingPathComponent("dark-menu-stage.png"))
        }
        if let image = render(PermissionView(openSettings: {}, onClose: {}).environment(prefs).environment(demo)) {
            write(image, to: folder.appendingPathComponent("permission.png"))
        }
        if let image = render(MenuBarHintView().environment(prefs).environment(demo)) {
            write(image, to: folder.appendingPathComponent("menu-bar-hint.png"))
        }

        if let image = render(AboutView(onClose: {}).environment(prefs).environment(demo)) {
            write(image, to: folder.appendingPathComponent("about.png"))
        }
        // ScrollView doesn't render in ImageRenderer, so the notes get their own image.
        if let image = render(ReleaseNotesText(notes: ReleaseNotes.load()).environment(prefs).padding(12)
            .frame(width: 380).background(Palette.field)) {
            write(image, to: folder.appendingPathComponent("about-release-notes.png"))
        }
        if let image = renderDark(AboutView(onClose: {}).environment(prefs).environment(demo)) {
            write(image, to: folder.appendingPathComponent("dark-about.png"))
        }

        // The menu and each tutorial step.
        let actions = MenuActions()
        if let image = render(MenuView(actions: actions).environment(prefs).environment(demo)) {
            write(image, to: folder.appendingPathComponent("menu.png"))
            rendered.append((Shot(name: "menu", form: .card), image))
        }
        for step in 0..<5 {
            let tutorial = TutorialView(onDone: {}, step: step).environment(prefs).environment(demo)
            if let image = render(tutorial) {
                write(image, to: folder.appendingPathComponent("tutorial-\(step + 1).png"))
                rendered.append((Shot(name: "tutorial-\(step + 1)", form: .card), image))
            }
        }

        // One contact sheet on the desktop color, to look at everything at once.
        let sheet = VStack(alignment: .leading, spacing: 28) {
            ForEach(Array(rendered.enumerated()), id: \.offset) { _, entry in
                VStack(alignment: .leading, spacing: 8) {
                    Text(entry.0.name.uppercased()).font(.perch(12, .heavy)).foregroundStyle(Palette.muted)
                    Image(nsImage: entry.1)
                }
            }
        }
        .padding(40)
        .frame(width: 560, alignment: .leading)
        .background(Palette.desktop)
        if let image = render(sheet) {
            write(image, to: folder.appendingPathComponent("sheet.png"))
        }
        print("Wrote \(rendered.count) snapshots to \(folder.path)")
    }

    static func renderIcon(to url: URL) {
        let renderer = ImageRenderer(content: AppIconView(size: 1024))
        renderer.scale = 1
        if let image = renderer.nsImage { write(image, to: url) }

        // The menu bar icon at 8×, playing and resting, for checking the bird.
        let frames: [[Double]] = [[0.35, 0.65, 0.45, 0.8], [0.9, 0.3, 0.7, 0.2], [0.15, 0.15, 0.15, 0.15]]
        let big = NSImage(size: NSSize(width: 22 * 8 * 3 + 40, height: 18 * 8 + 20), flipped: false) { _ in
            NSColor.white.setFill()
            NSRect(x: 0, y: 0, width: 22 * 8 * 3 + 40, height: 18 * 8 + 20).fill()
            for (i, levels) in frames.enumerated() {
                StatusItemController.icon(levels: levels)
                    .draw(in: NSRect(x: 10 + Double(i) * (22 * 8 + 10), y: 10, width: 22 * 8, height: 18 * 8))
            }
            return true
        }
        write(big, to: url.deletingLastPathComponent().appendingPathComponent("menu-bar-icon.png"))
    }

    private static func demoPlayer(song: Int) -> PlayerModel {
        let source = DemoSource()
        for _ in 0..<song { source.next() }
        let player = PlayerModel(source: source)
        player.refresh()
        return player
    }

    private static func renderDark<V: View>(_ view: V) -> NSImage? {
        var image: NSImage?
        NSAppearance(named: .darkAqua)!.performAsCurrentDrawingAppearance {
            image = render(view.environment(\.colorScheme, .dark))
        }
        return image
    }

    private static func render<V: View>(_ view: V) -> NSImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.nsImage
    }

    private static func write(_ image: NSImage, to url: URL) {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url)
    }
}

/// Spotify closed, for the idle look.
@MainActor
private final class ClosedSource: MusicSource {
    let name = "Spotify"
    let changeNotification: String? = nil
    func read(_ done: @escaping @MainActor (SourceReading) -> Void) { done(SourceReading(state: .notRunning, track: nil, position: 0)) }
    func playPause() {}
    func next() {}
    func previous() {}
}
