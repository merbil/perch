import AppKit

//   Perch                     → the app, controlling Spotify
//   Perch --demo              → the app with a fake player (no Spotify, no permission prompt)
//   Perch --snapshot <folder> → renders every form to PNGs and exits (debug builds)
//   Perch --icon <file.png>   → renders the 1024 px app icon and exits (debug builds)
let arguments = CommandLine.arguments

#if DEBUG
if let index = arguments.firstIndex(of: "--snapshot") {
    let folder = index + 1 < arguments.count ? arguments[index + 1] : "snapshots"
    MainActor.assumeIsolated { Snapshot.run(to: URL(fileURLWithPath: folder)) }
    exit(0)
}

if let index = arguments.firstIndex(of: "--icon"), index + 1 < arguments.count {
    MainActor.assumeIsolated { Snapshot.renderIcon(to: URL(fileURLWithPath: arguments[index + 1])) }
    exit(0)
}
#endif

let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate(demo: arguments.contains("--demo")) }
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
