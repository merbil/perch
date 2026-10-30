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
    }

    private static let shots: [Shot] = [
        Shot(name: "a-pill-right", form: .pill(.right)),
        Shot(name: "a-pill-left", form: .pill(.left)),
        Shot(name: "a-pill-bottom", form: .pill(.bottom)),
        Shot(name: "a-tucked-right", form: .tucked(.right)),
        Shot(name: "a-tucked-right-hover", form: .tucked(.right), hover: true),
        Shot(name: "tab-left", form: .tab(.left)),
        Shot(name: "tab-left-hover", form: .tab(.left), hover: true),
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
            let state = PanelState(form: shot.form)
            state.forceHover = shot.hover
            let size = Layout.windowSize(for: shot.form)
            let view = PlayerRoot()
                .environment(state)
                .environment(prefs)
                .environment(shot.closed ? closed : demo)
                .frame(width: size.width, height: size.height)
            if let image = render(view) {
                write(image, to: folder.appendingPathComponent("\(shot.name).png"))
                rendered.append((shot, image))
            }
        }

        // One contact sheet on the desktop colour, to look at everything at once.
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
        .background(Color(hex: 0xE7E1F0))
        if let image = render(sheet) {
            write(image, to: folder.appendingPathComponent("sheet.png"))
        }
        print("Wrote \(rendered.count) snapshots to \(folder.path)")
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
    func read() -> SourceReading { SourceReading(state: .notRunning, track: nil, position: 0) }
    func playPause() {}
    func next() {}
    func previous() {}
}
