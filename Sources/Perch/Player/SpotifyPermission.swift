import AppKit
import CoreServices
import Observation

/// macOS's "Perch wants to control Spotify" permission, asked for on purpose (from the tutorial)
/// instead of whenever Spotify first happens to be open.
@MainActor
@Observable
final class SpotifyPermission {
    enum Status: Equatable {
        case unknown, asking, allowed, denied, notInstalled
    }

    private(set) var status = Status.unknown

    /// Looks without asking. Only meaningful while Spotify is open.
    func refresh() {
        guard isRunning else { return }
        Task.detached {
            let result = Self.determine(ask: false)
            await MainActor.run { if result != .unknown { self.status = result } }
        }
    }

    /// Opens Spotify in the background if needed, then shows macOS's prompt.
    func request() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: SpotifySource.bundleID) else {
            status = .notInstalled
            return
        }
        status = .asking
        if isRunning {
            ask()
        } else {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = false
            config.hides = true
            NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
                Task { @MainActor in self.waitForSpotify(tries: 30) }
            }
        }
    }

    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    private var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: SpotifySource.bundleID).isEmpty
    }

    private func waitForSpotify(tries: Int) {
        if isRunning {
            // Spotify answers Apple Events a moment after it appears.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.ask() }
        } else if tries > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.waitForSpotify(tries: tries - 1) }
        } else {
            status = .unknown
        }
    }

    private func ask() {
        Task.detached {
            // Blocks until the user answers the prompt, so it stays off the main thread.
            let result = Self.determine(ask: true)
            await MainActor.run { self.status = result }
        }
    }

    nonisolated static func determine(ask: Bool) -> Status {
        var target = AEAddressDesc()
        let bundleID = SpotifySource.bundleID
        let created = bundleID.withCString {
            AECreateDesc(DescType(typeApplicationBundleID), $0, bundleID.utf8.count, &target)
        }
        guard created == noErr else { return .unknown }
        defer { AEDisposeDesc(&target) }
        let result = AEDeterminePermissionToAutomateTarget(&target, AEEventClass(typeWildCard), AEEventID(typeWildCard), ask)
        switch Int(result) {
        case Int(noErr): return .allowed
        case errAEEventNotPermitted: return .denied
        default: return .unknown   // not asked yet, or Spotify isn't running
        }
    }
}
