import Foundation

struct Track: Equatable {
    var id: String
    var title: String
    var artist: String
    var album: String
    var artworkURL: URL?
    /// Seconds.
    var duration: Double
}

enum PlaybackState: Equatable {
    /// The player app isn't open.
    case notRunning
    case stopped
    case paused
    case playing
}

struct SourceReading: Equatable {
    var state: PlaybackState
    var track: Track?
    /// Seconds into the track.
    var position: Double
}

/// A music app Perch can read and control. Spotify first, Apple Music later.
@MainActor
protocol MusicSource: AnyObject {
    var name: String { get }
    /// Name of the distributed notification the app posts when playback changes, if any.
    var changeNotification: String? { get }
    func read() -> SourceReading
    func playPause()
    func next()
    func previous()
}
