import Foundation

struct Track: Equatable {
    var id: String
    var title: String
    var artist: String
    var album: String
    var artworkURL: URL?
    /// Seconds.
    var duration: Double
    /// Opens the song in the player app ("spotify:track:…").
    var link: URL? = nil
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
    var shuffling = false
    var repeating = false
}

/// A music app Perch can read and control. Spotify first, Apple Music later.
@MainActor
protocol MusicSource: AnyObject {
    var name: String { get }
    /// Name of the distributed notification the app posts when playback changes, if any.
    var changeNotification: String? { get }
    /// Calls back on the main actor; may be right away, or after the app has answered.
    func read(_ done: @escaping @MainActor (SourceReading) -> Void)
    func playPause()
    func next()
    func previous()
    /// Seconds into the current track.
    func seek(to seconds: Double)
    func setShuffling(_ on: Bool)
    func setRepeating(_ on: Bool)
}

extension MusicSource {
    func seek(to seconds: Double) {}
    func setShuffling(_ on: Bool) {}
    func setRepeating(_ on: Bool) {}
}
