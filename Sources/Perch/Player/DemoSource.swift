import Foundation

/// Fake player for `--demo` and `--snapshot`: no Spotify, no permission prompt.
@MainActor
final class DemoSource: MusicSource {
    let name = "Spotify"
    let changeNotification: String? = nil

    private var playing = true
    private var index = 0
    private var startedAt = Date().addingTimeInterval(-134)
    private var pausedPosition: Double = 134

    private let tracks = [
        Track(id: "demo1", title: "Night Bus Home", artist: "Low Season", album: "Late Lines", artworkURL: nil, duration: 232),
        Track(id: "demo2", title: "Paper Lanterns Over the Ring Road", artist: "Kite Office", album: "Overpass", artworkURL: nil, duration: 251),
        Track(id: "demo3", title: "Cold Tea", artist: "Marina Static", album: "Tin", artworkURL: nil, duration: 187),
    ]

    private var position: Double {
        let track = tracks[index]
        let raw = playing ? Date().timeIntervalSince(startedAt) : pausedPosition
        return raw.truncatingRemainder(dividingBy: track.duration)
    }

    func read() -> SourceReading {
        SourceReading(state: playing ? .playing : .paused, track: tracks[index], position: position)
    }

    func playPause() {
        if playing {
            pausedPosition = position
        } else {
            startedAt = Date().addingTimeInterval(-pausedPosition)
        }
        playing.toggle()
    }

    func next() { jump(by: 1) }
    func previous() { jump(by: -1) }

    private func jump(by step: Int) {
        index = (index + step + tracks.count) % tracks.count
        startedAt = Date()
        pausedPosition = 0
    }
}
