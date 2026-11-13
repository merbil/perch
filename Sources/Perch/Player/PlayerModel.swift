import AppKit
import SwiftUI
import Observation

/// What's playing, refreshed from the source once a second and whenever it posts a change.
@MainActor
@Observable
final class PlayerModel {
    private(set) var state: PlaybackState = .notRunning
    private(set) var track: Track?
    private(set) var position: Double = 0
    private(set) var shuffling = false
    private(set) var repeating = false
    private(set) var artwork: NSImage? {
        didSet {
            coverAccent = artwork?.vibrantAccent()
            coverBackground = artwork?.deepBackground()
        }
    }
    /// Accent picked from the album art, for the "From Cover Art" setting.
    private(set) var coverAccent: Color?
    /// A deep color from the album art, for Stage's cover look.
    private(set) var coverBackground: Color?

    @ObservationIgnored let source: MusicSource
    /// Called after every refresh (the menu bar icon listens to this).
    @ObservationIgnored var onRefresh: (() -> Void)?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var artworkURL: URL?
    @ObservationIgnored private var observer: NSObjectProtocol?

    init(source: MusicSource) {
        self.source = source
    }

    /// Snapshots only: show a made-up cover.
    func showArtwork(_ image: NSImage?) { artwork = image }

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

    @ObservationIgnored private var isReading = false

    func refresh() {
        // One read at a time; Spotify answers on a background queue.
        guard !isReading else { return }
        isReading = true
        source.read { [weak self] reading in
            self?.isReading = false
            self?.apply(reading)
        }
    }

    private func apply(_ reading: SourceReading) {
        state = reading.state
        position = reading.position
        shuffling = reading.shuffling
        repeating = reading.repeating
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

    /// `fraction` of the way into the song, 0…1.
    func seek(to fraction: Double) {
        guard let duration = track?.duration, duration > 0, !isIdle else { return }
        position = min(max(fraction, 0), 1) * duration
        source.seek(to: position)
        refreshSoon()
    }

    func toggleShuffling() {
        shuffling.toggle()
        source.setShuffling(shuffling)
        refreshSoon()
    }

    func toggleRepeating() {
        repeating.toggle()
        source.setRepeating(repeating)
        refreshSoon()
    }

    /// The song in the player app itself.
    func openInPlayer() {
        if let link = track?.link { NSWorkspace.shared.open(link) }
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
