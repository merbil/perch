import AppKit

/// Talks to Spotify through AppleScript. Never launches Spotify on its own:
/// every script is guarded by a running check, except Play, which opens it on purpose.
@MainActor
final class SpotifySource: MusicSource {
    nonisolated static let bundleID = "com.spotify.client"

    let name = "Spotify"
    let changeNotification: String? = "com.spotify.client.PlaybackStateChanged"

    private var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID).isEmpty
    }

    // One line per field, so titles with commas survive.
    private static let readScript = """
    tell application id "com.spotify.client"
        set s to player state as string
        if s is "stopped" then return s
        set t to current track
        return s & linefeed & (id of t) & linefeed & (name of t) & linefeed & (artist of t) & linefeed & (album of t) & linefeed & (artwork url of t) & linefeed & ((duration of t) as string) & linefeed & ((player position) as string)
    end tell
    """

    func read() -> SourceReading {
        guard isRunning else { return SourceReading(state: .notRunning, track: nil, position: 0) }
        guard let output = run(Self.readScript) else { return SourceReading(state: .stopped, track: nil, position: 0) }
        return Self.parse(output)
    }

    static func parse(_ output: String) -> SourceReading {
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
            duration: (number(lines[6]) ?? 0) / 1000   // Spotify reports milliseconds
        )
        return SourceReading(state: state, track: track, position: number(lines[7]) ?? 0)
    }

    /// AppleScript formats reals with the user's locale ("12,5" in Turkish or German).
    private static func number(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: "."))
    }

    func playPause() {
        if isRunning {
            run(#"tell application id "com.spotify.client" to playpause"#)
        } else {
            launchAndPlay()
        }
    }

    func next() {
        guard isRunning else { return }
        run(#"tell application id "com.spotify.client" to next track"#)
    }

    func previous() {
        guard isRunning else { return }
        run(#"tell application id "com.spotify.client" to previous track"#)
    }

    private func launchAndPlay() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.bundleID) else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
            // Spotify needs a moment before it answers scripts.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                self?.run(#"tell application id "com.spotify.client" to play"#)
            }
        }
    }

    @discardableResult
    private func run(_ source: String) -> String? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            NSLog("Perch: Spotify script failed: \(error)")
            return nil
        }
        return result?.stringValue
    }
}
