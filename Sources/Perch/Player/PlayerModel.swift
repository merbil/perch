import AppKit
import Observation

/// What's playing, refreshed from the source once a second and whenever it posts a change.
@MainActor
@Observable
final class PlayerModel {
    private(set) var state: PlaybackState = .notRunning
    private(set) var track: Track?
    private(set) var position: Double = 0
    private(set) var artwork: NSImage?

    @ObservationIgnored let source: MusicSource
    /// Called after every refresh (the menu bar icon listens to this).
    @ObservationIgnored var onRefresh: (() -> Void)?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var artworkURL: URL?
    @ObservationIgnored private var observer: NSObjectProtocol?

    init(source: MusicSource) {
        self.source = source
    }

    var isPlaying: Bool { state == .playing }
    /// Nothing to show: the app is closed or stopped. Views dim and show the last track if there was one.
    var isIdle: Bool { state == .notRunning || state == .stopped }
    var progress: Double {
        guard let duration = track?.duration, duration > 0 else { return 0 }
        return min(max(position / duration, 0), 1)
    }
    var title: String { track?.title ?? "Nothing playing" }
    var artist: String { track?.artist ?? (state == .notRunning ? "\(source.name) is closed" : source.name) }

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        if let name = source.changeNotification {
            observer = DistributedNotificationCenter.default().addObserver(
                forName: Notification.Name(name), object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
    }

    func refresh() {
        let reading = source.read()
        state = reading.state
        position = reading.position
        // Keep the last track around when the app stops, so the idle view isn't empty.
        if let newTrack = reading.track { track = newTrack }
        loadArtwork(track?.artworkURL)
        onRefresh?()
    }

    func playPause() {
        source.playPause()
        // Flip right away so the button feels instant; the next read corrects it.
        if state == .playing { state = .paused } else if state == .paused { state = .playing }
        onRefresh?()
        refreshSoon()
    }

    func next() {
        source.next()
        refreshSoon()
    }

    func previous() {
        source.previous()
        refreshSoon()
    }

    private func refreshSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.refresh() }
    }

    private func loadArtwork(_ url: URL?) {
        guard url != artworkURL else { return }
        artworkURL = url
        guard let url else { artwork = nil; return }
        Task { [weak self] in
            let data = try? await URLSession.shared.data(from: url).0
            guard let self, self.artworkURL == url else { return }
            self.artwork = data.flatMap(NSImage.init(data:))
        }
    }
}

extension Double {
    /// 134 → "2:14"
    var clock: String {
        let total = Int(self.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
