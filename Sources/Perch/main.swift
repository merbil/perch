import AppKit

//   Perch                     → the app, controlling Spotify
//   Perch --demo              → the app with a fake player (no Spotify, no permission prompt)
//   Perch --snapshot <folder> → renders every form to PNGs and exits
let arguments = CommandLine.arguments

if let index = arguments.firstIndex(of: "--snapshot") {
    let folder = index + 1 < arguments.count ? arguments[index + 1] : "snapshots"
    MainActor.assumeIsolated { Snapshot.run(to: URL(fileURLWithPath: folder)) }
    exit(0)
}

let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate(demo: arguments.contains("--demo")) }
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
