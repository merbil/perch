import AppKit

/// Talks to Spotify through AppleScript. Never launches Spotify on its own:
/// every script is guarded by a running check, except Play, which opens it on purpose.
///
/// Scripts run on a background queue. A Spotify script takes long enough to stall the main thread,
/// and doing that once a second made the scrolling titles stutter.
@MainActor
final class SpotifySource: MusicSource {
    nonisolated static let bundleID = "com.spotify.client"

    let name = "Spotify"
    let changeNotification: String? = "com.spotify.client.PlaybackStateChanged"
    /// macOS refused to let Perch script Spotify (Privacy & Security › Automation).
    var onPermissionDenied: (() -> Void)?

    /// One queue for every script: NSAppleScript isn't meant for several threads at once.
    private nonisolated static let queue = DispatchQueue(label: "com.merterbil.perch.spotify", qos: .userInitiated)
    /// Compiled once, used only on `queue`.
    private nonisolated(unsafe) static var compiled: [String: NSAppleScript] = [:]

    private var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID).isEmpty
    }

    // One line per field, so titles with commas survive.
    private nonisolated static let readScript = """
    tell application id "com.spotify.client"
        set s to player state as string
        if s is "stopped" then return s
        set t to current track
        set sh to "false"
        set re to "false"
        try
            set sh to (shuffling as string)
            set re to (repeating as string)
        end try
        return s & linefeed & (id of t) & linefeed & (name of t) & linefeed & (artist of t) & linefeed & (album of t) & linefeed & (artwork url of t) & linefeed & ((duration of t) as string) & linefeed & ((player position) as string) & linefeed & sh & linefeed & re & linefeed & (spotify url of t)
    end tell
    """

    func read(_ done: @escaping @MainActor (SourceReading) -> Void) {
        guard isRunning else {
            done(SourceReading(state: .notRunning, track: nil, position: 0))
            return
        }
        Self.queue.async {
            let (output, error) = Self.run(Self.readScript)
            let reading = output.map(Self.parse) ?? SourceReading(state: .stopped, track: nil, position: 0)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    if error == Self.notPermitted { self.onPermissionDenied?() }
                    done(reading)
                }
            }
        }
    }

    nonisolated static func parse(_ output: String) -> SourceReading {
        let lines = output.components(separatedBy: "\n")
        let state: PlaybackState = switch lines.first {
        case "playing": .playing
        case "paused": .paused
        default: .stopped
        }
        guard state != .stopped, lines.count >= 8 else { return SourceReading(state: state, track: nil, position: 0) }
        let track = Track(
            id: lines[1],
            title: lines[2],
            artist: lines[3],
            album: lines[4],
            artworkURL: URL(string: lines[5]),
            duration: (number(lines[6]) ?? 0) / 1000,   // Spotify reports milliseconds
            link: lines.count > 10 ? URL(string: lines[10]) : nil
        )
        return SourceReading(state: state, track: track, position: number(lines[7]) ?? 0,
                             shuffling: lines.count > 8 && lines[8] == "true",
                             repeating: lines.count > 9 && lines[9] == "true")
    }

    /// AppleScript formats reals with the user's locale ("12,5" in Turkish or German).
    private nonisolated static func number(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: "."))
    }

    func playPause() {
        if isRunning {
            send(#"tell application id "com.spotify.client" to playpause"#)
        } else {
            launchAndPlay()
        }
    }

    func next() {
        guard isRunning else { return }
        send(#"tell application id "com.spotify.client" to next track"#)
    }

    func previous() {
        guard isRunning else { return }
        send(#"tell application id "com.spotify.client" to previous track"#)
    }

    func seek(to seconds: Double) {
        guard isRunning, seconds.isFinite else { return }
        // A plain number in the source: AppleScript reads "12.5" whatever the locale.
        send("tell application id \"com.spotify.client\" to set player position to \(String(format: "%.1f", max(seconds, 0)))")
    }

    func setShuffling(_ on: Bool) {
        guard isRunning else { return }
        send("tell application id \"com.spotify.client\" to set shuffling to \(on)")
    }

    func setRepeating(_ on: Bool) {
        guard isRunning else { return }
        send("tell application id \"com.spotify.client\" to set repeating to \(on)")
    }

    private func launchAndPlay() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.bundleID) else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
            // Spotify needs a moment before it answers scripts.
            Self.queue.asyncAfter(deadline: .now() + 2.5) {
                _ = Self.execute(#"tell application id "com.spotify.client" to play"#)
            }
        }
    }

    private func send(_ source: String) {
        Self.queue.async { _ = Self.execute(source) }
    }

    /// errAEEventNotPermitted: the user said no to "Perch wants to control Spotify".
    nonisolated static let notPermitted = -1743

    private nonisolated static func execute(_ source: String) -> String? {
        run(source).output
    }

    /// Runs on `queue` only. The error number comes back too, to tell a refused permission apart.
    private nonisolated static func run(_ source: String) -> (output: String?, error: Int?) {
        let script: NSAppleScript
        if let cached = compiled[source] {
            script = cached
        } else {
            guard let fresh = NSAppleScript(source: source) else { return (nil, nil) }
            var compileError: NSDictionary?
            fresh.compileAndReturnError(&compileError)
            compiled[source] = fresh
            script = fresh
        }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            NSLog("Perch: Spotify script failed: \(error)")
            return (nil, error[NSAppleScript.errorNumber] as? Int)
        }
        return (result.stringValue, nil)
    }
}
